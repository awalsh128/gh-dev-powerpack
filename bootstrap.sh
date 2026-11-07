#!/usr/bin/env bash
# Copies template sets into a target repo and fills in placeholders. Existing files are left alone
# unless -f is given, so it is safe to run on a repo that already has some of these files.
#
# Usage: bootstrap.sh [-f] [-n] <target-dir> <set> [set ...]
#   -f  Overwrite files that already exist in the target.
#   -n  Dry run: print what would be copied.
# Sets: see templates/ (common, conventional-commits, release-flow, node, cpp, dotnet).
#
# Placeholders: __OWNER__, __REPO__ (from the target's origin remote) and __MAINTAINER__
# (defaults to the owner). Override with OWNER=, REPO= and MAINTAINER= in the environment.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
force=false
dry_run=false
while getopts "fnh" opt; do
  case "$opt" in
    f) force=true ;;
    n) dry_run=true ;;
    *) sed -n '2,12p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
if [[ $# -lt 2 ]]; then
  sed -n '2,12p' "$0"
  echo "Available sets: $(ls "$here/templates" | tr '\n' ' ')"
  exit 1
fi

target="$(cd "$1" && pwd)"
shift

remote="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
slug="$(sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##' <<<"$remote")"
OWNER="${OWNER:-${slug%%/*}}"
REPO="${REPO:-${slug##*/}}"
REPO="${REPO:-$(basename "$target")}"
MAINTAINER="${MAINTAINER:-$OWNER}"
if [[ -z "$OWNER" ]]; then
  echo "Could not find the GitHub owner from the origin remote; set OWNER=..." >&2
  exit 1
fi
echo "Target: $target ($OWNER/$REPO, maintainer $MAINTAINER)"

for set in "$@"; do
  src="$here/templates/$set"
  if [[ ! -d "$src" ]]; then
    echo "Unknown set '$set'. Available: $(ls "$here/templates" | tr '\n' ' ')" >&2
    exit 1
  fi
  while IFS= read -r -d '' file; do
    rel="${file#"$src"/}"
    dest="$target/$rel"
    if [[ -e "$dest" && "$force" == false ]]; then
      echo "  skip   $rel (exists)"
      continue
    fi
    echo "  write  $rel ($set)"
    "$dry_run" && continue
    mkdir -p "$(dirname "$dest")"
    sed -e "s#__OWNER__#$OWNER#g" -e "s#__REPO__#$REPO#g" -e "s#__MAINTAINER__#$MAINTAINER#g" \
      "$file" > "$dest"
    if [[ -x "$file" ]]; then chmod +x "$dest"; fi
  done < <(find "$src" -type f -print0 | sort -z)
done

"$dry_run" || echo "Done. Review the changes with: git -C '$target' status"
