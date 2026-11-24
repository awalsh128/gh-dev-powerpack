#!/usr/bin/env bash
# Checks the repo in the current directory against this repo's standards and prints the findings as JSON,
# for the cross-repo-drift skill (set DRIFT_CHECK_CMD to this script's path).
#
# Usage: drift-check.sh        (run it inside the repo to check)
# Prints {"findings": [{"rule", "category", "path", "message", "fixable"}]}, plus "line" and "ref" where known. Always exits 0 when it ran.
# Needs jq.
#
# Rules:
#   unpinned-uses    (category pin)  a `uses:` in a workflow or composite action that is not a full commit SHA.
#   unpinned-runner  (category pin)  a job's `runs-on: ubuntu-latest`; the standard is ubuntu-24.04. Only a plain
#                                    string is flagged, not a matrix value, an expression or a list.
#   missing-permissions (category permissions, not fixable)  a job with no `permissions:` block in a workflow that
#                                    has no top-level one either, so it gets the token's broad default. Not
#                                    fixable because the right permissions depend on what the job does.
set -euo pipefail

# Prints "file:line:ref-owner/name@ref" for each remote `uses:` whose ref is not a 40-character SHA.
unpinned_uses() {
  local files=()
  while IFS= read -r f; do files+=("$f"); done < <(
    find .github/workflows .github/actions -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)
  [[ ${#files[@]} -eq 0 ]] && return 0
  # Local (./) and docker:// uses have no ref to pin.
  grep -HnE '^\s*(-\s+)?uses:\s*' "${files[@]}" |
    sed -E 's/^([^:]+):([0-9]+):\s*(-\s+)?uses:\s*["'"'"']?([^"'"'"' #]+).*$/\1:\2:\4/' |
    grep -vE ':(\./|docker://)' |
    grep -vE '@[0-9a-f]{40}$' || true
}

# Prints "file:line" for each `runs-on: ubuntu-latest` written as a plain string (quotes and a comment allowed).
unpinned_runner() {
  [[ -d .github/workflows ]] || return 0
  find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) | sort |
    xargs -r grep -HnE '^\s*runs-on:\s*["'"'"']?ubuntu-latest["'"'"']?\s*(#.*)?$' |
    sed -E 's/^([^:]+):([0-9]+):.*$/\1:\2/' || true
}

# Prints "file:line:job" for each job with no `permissions:` in a workflow that has no top-level `permissions:`.
missing_permissions() {
  [[ -d .github/workflows ]] || return 0
  local f
  while IFS= read -r f; do
    grep -qE '^permissions:' "$f" && continue
    awk '
      /^jobs:/ { injobs = 1; next }
      injobs && /^[^ #]/ { injobs = 0 }
      injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*(#.*)?$/ {
        if (job != "" && !has) print FILENAME ":" jl ":" job
        job = $1; sub(/:$/, "", job); jl = NR; has = 0; next }
      injobs && /^    permissions:/ { has = 1 }
      END { if (job != "" && !has) print FILENAME ":" jl ":" job }' "$f"
  done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
}

findings=$(
  {
    unpinned_uses | while IFS=: read -r file line ref; do
      jq -n --arg path "$file" --arg line "$line" --arg ref "$ref" '{
        rule: "unpinned-uses", category: "pin", path: $path, line: ($line | tonumber), ref: $ref, fixable: true,
        message: "pin \($ref) to a full commit SHA"}'
    done
    unpinned_runner | while IFS=: read -r file line; do
      jq -n --arg path "$file" --arg line "$line" '{
        rule: "unpinned-runner", category: "pin", path: $path, line: ($line | tonumber), ref: "ubuntu-latest",
        fixable: true, message: "pin runs-on ubuntu-latest to ubuntu-24.04"}'
    done
    missing_permissions | while IFS=: read -r file line job; do
      jq -n --arg path "$file" --arg line "$line" --arg job "$job" '{
        rule: "missing-permissions", category: "permissions", path: $path, line: ($line | tonumber), ref: $job,
        fixable: false, message: "set permissions for job \($job); the workflow has no top-level permissions"}'
    done
  } | jq -s '.'
)

jq -n --argjson findings "${findings:-[]}" '{findings: $findings}'
