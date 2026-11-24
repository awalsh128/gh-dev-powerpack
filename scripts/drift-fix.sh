#!/usr/bin/env bash
# Fixes one drift rule in the repo in the current directory; the cross-repo-drift skill's DRIFT_FIX_CMD.
#
# Usage: DRIFT_RULE=unpinned-uses drift-fix.sh   (run it inside the repo to fix)
# Rules (see drift-check.sh):
#   unpinned-uses    rewrites `uses: owner/repo@ref` to `uses: owner/repo@<commit sha> # ref`.
#   unpinned-runner  rewrites `runs-on: ubuntu-latest` to `runs-on: ubuntu-24.04`.
# Needs jq and an authenticated gh. unpinned-uses exits 1, leaving unresolved lines unchanged, if any ref
# can't be resolved; any unknown rule exits 1 without touching anything.
set -euo pipefail

check="$(dirname "$0")/drift-check.sh"

# Escapes a string for use inside a sed regex.
re_escape() { printf '%s' "$1" | sed 's/[][\.*^$|/]/\\&/g'; }

# Prints the check's findings for one rule as tab-separated path, line and ref.
findings_for() { "$check" | jq -r --arg rule "$1" '.findings[] | select(.rule == $rule) | [.path, .line, .ref] | @tsv'; }

fix_unpinned_uses() {
  local failed=0 path line uses ref name repo key sha
  declare -A sha_of
  while IFS=$'\t' read -r path line uses; do
    ref="${uses##*@}"
    name="${uses%@*}"                                  # owner/repo[/subpath]
    repo="$(cut -d/ -f1,2 <<<"$name")"
    key="$repo@$ref"
    if [[ -z "${sha_of[$key]:-}" ]]; then
      # The commits endpoint resolves tags (including annotated ones) and branches to a commit.
      sha="$(gh api "repos/$repo/commits/$ref" -q .sha 2>/dev/null || true)"
      if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "drift-fix: could not resolve $repo@$ref ($path:$line)" >&2
        failed=1
        continue
      fi
      sha_of[$key]="$sha"
    fi
    sed -E -i "${line}s|(uses:[[:space:]]*[\"']?)$(re_escape "$name@$ref")([\"']?)[[:space:]]*(#.*)?\$|\1${name}@${sha_of[$key]}\2 # ${ref}|" "$path"
    echo "pinned $name@$ref -> ${sha_of[$key]:0:7} ($path:$line)"
  done < <(findings_for unpinned-uses)
  return "$failed"
}

fix_unpinned_runner() {
  local path line ref
  while IFS=$'\t' read -r path line ref; do
    # Keeps the indentation, any quotes and a trailing comment; only the image name changes.
    sed -E -i "${line}s|(runs-on:[[:space:]]*[\"']?)ubuntu-latest|\1ubuntu-24.04|" "$path"
    echo "pinned runs-on ubuntu-latest -> ubuntu-24.04 ($path:$line)"
  done < <(findings_for unpinned-runner)
}

case "${DRIFT_RULE:-}" in
  unpinned-uses) fix_unpinned_uses ;;
  unpinned-runner) fix_unpinned_runner ;;
  *) echo "drift-fix: no fixer for rule '${DRIFT_RULE:-}'" >&2; exit 1 ;;
esac
