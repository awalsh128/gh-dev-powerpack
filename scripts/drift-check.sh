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
  } | jq -s '.'
)

jq -n --argjson findings "${findings:-[]}" '{findings: $findings}'
