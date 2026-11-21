#!/usr/bin/env bash
# Copies template sets into a target repo and fills in placeholders. Existing files are left alone
# unless -f is given, so it is safe to run on a repo that already has some of these files.
#
# Usage: bootstrap.sh [-f] [-n] <target-dir> <set> [set ...]
#   -f  Overwrite files that already exist in the target.
#   -n  Dry run: print what would be copied.
# Sets live in templates/<category>/<set>; pass just the set name. Run with one argument to list the
# available sets. Sets that need other sets (see templates/sets.json) print a warning if those are
# not in the same command.
# Symlinks in a set are recreated as symlinks.
#
# Placeholders: __OWNER__, __REPO__ (from the target's origin remote) and __MAINTAINER__
# (defaults to the owner). Override with OWNER=, REPO= and MAINTAINER= in the environment.
# __OWNER_ID__ and __REPO_ID__ (numeric GitHub IDs, for Octo STS trust policies) come from `gh api`, so
# a repo that later takes the same name doesn't match; override with OWNER_ID= and REPO_ID=.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
available_sets() {
  find "$here/templates" -mindepth 2 -maxdepth 2 -type d -printf '%f\n' | sort | tr '\n' ' '
}
force=false
dry_run=false
while getopts "fnh" opt; do
  case "$opt" in
    f) force=true ;;
    n) dry_run=true ;;
    *) sed -n '2,18p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
if [[ $# -lt 2 ]]; then
  sed -n '2,18p' "$0"
  echo "Available sets: $(available_sets)"
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

# Numeric IDs are only needed by files that use them (Octo STS trust policies). Leave the placeholders
# in place and warn when gh can't look them up.
if [[ -z "${OWNER_ID:-}" || -z "${REPO_ID:-}" ]]; then
  ids="$(gh api "repos/$OWNER/$REPO" --jq '"\(.owner.id) \(.id)"' 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    OWNER_ID="${OWNER_ID:-${ids% *}}"
    REPO_ID="${REPO_ID:-${ids#* }}"
  fi
fi
if [[ -z "${OWNER_ID:-}" || -z "${REPO_ID:-}" ]]; then
  OWNER_ID="__OWNER_ID__"
  REPO_ID="__REPO_ID__"
  echo "Warning: could not look up the owner and repo IDs (is $OWNER/$REPO on GitHub and gh logged in?)." >&2
  echo "         Trust policies keep __OWNER_ID__ and __REPO_ID__; set OWNER_ID= and REPO_ID= and re-run with -f." >&2
fi

if command -v jq >/dev/null 2>&1; then
  for set in "$@"; do
    while read -r need; do
      [[ " $* " == *" $need "* ]] || echo "Warning: '$set' needs '$need', which is not in this command." >&2
    done < <(jq -r --arg s "$set" '.[][$s].needs // [] | .[]' "$here/templates/sets.json")
  done
fi

for set in "$@"; do
  src="$(compgen -G "$here/templates/*/$set" | head -n1 || true)"
  if [[ -z "$src" || ! -d "$src" ]]; then
    echo "Unknown set '$set'. Available: $(available_sets)" >&2
    exit 1
  fi
  while IFS= read -r -d '' file; do
    rel="${file#"$src"/}"
    dest="$target/$rel"
    if [[ (-e "$dest" || -L "$dest") && "$force" == false ]]; then
      echo "  skip   $rel (exists)"
      continue
    fi
    # Never replace a real directory with a symlink, even with -f.
    if [[ -L "$file" && -d "$dest" && ! -L "$dest" ]]; then
      echo "  skip   $rel (is a directory)"
      continue
    fi
    echo "  write  $rel ($set)"
    "$dry_run" && continue
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$file" ]]; then
      ln -sfn "$(readlink "$file")" "$dest"
      continue
    fi
    sed -e "s#__OWNER__#$OWNER#g" -e "s#__REPO__#$REPO#g" -e "s#__MAINTAINER__#$MAINTAINER#g" \
      -e "s#__OWNER_ID__#$OWNER_ID#g" -e "s#__REPO_ID__#$REPO_ID#g" \
      "$file" > "$dest"
    if [[ -x "$file" ]]; then chmod +x "$dest"; fi
  done < <(find "$src" \( -type f -o -type l \) -print0 | sort -z)
done

"$dry_run" || echo "Done. Review the changes with: git -C '$target' status"
