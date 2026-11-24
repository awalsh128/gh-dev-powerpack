#!/usr/bin/env bash
# Fixes one drift rule in the repo in the current directory; the cross-repo-drift skill's DRIFT_FIX_CMD.
#
# Usage: DRIFT_RULE=unpinned-uses drift-fix.sh   (run it inside the repo to fix)
# Rules (see drift-check.sh):
#   unpinned-uses  rewrites `uses: owner/repo@ref` to `uses: owner/repo@<commit sha> # ref`.
# Needs jq and an authenticated gh. Exits 1, leaving unresolved lines unchanged, if any ref can't be
# resolved; any other rule exits 1 without touching anything.
set -euo pipefail

rule="${DRIFT_RULE:-}"
[[ "$rule" == "unpinned-uses" ]] || { echo "drift-fix: no fixer for rule '${rule}'" >&2; exit 1; }

check="$(dirname "$0")/drift-check.sh"
declare -A sha_of
failed=0

# Escapes a string for use inside a sed regex.
re_escape() { printf '%s' "$1" | sed 's/[][\.*^$|/]/\\&/g'; }

while IFS=$'\t' read -r path line uses; do
  ref="${uses##*@}"
  name="${uses%@*}"                                    # owner/repo[/subpath]
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
done < <("$check" | jq -r '.findings[] | select(.rule == "unpinned-uses") | [.path, .line, .ref] | @tsv')

exit "$failed"
