#!/usr/bin/env bash
# Sets up GitHub Pages for the API docs that the npm-publish set's release.yml deploys (npm-pages
# set): turns on Pages with GitHub Actions as the source, limits the github-pages environment to
# main (release.yml deploys from main, and the release flow makes staging the default branch, which
# is all GitHub allows by default), and sets the repository's website to the Pages URL. Safe to
# rerun: steps already done are skipped.
#
# Usage: setup_github_pages.sh [-n] [-b branch] [repo-dir]
#   -n  Dry run: print what would be done.
#   -b  Branch that deploys (default: main).
# repo-dir defaults to the current directory. The GitHub repo comes from its origin remote. Needs gh
# logged in as a repository admin.
set -euo pipefail

dry_run=false
branch="main"
while getopts "nb:h" opt; do
  case "$opt" in
    n) dry_run=true ;;
    b) branch="$OPTARG" ;;
    *) sed -n '2,13p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
dir="$(cd "${1:-.}" && pwd)"

step() { printf '\n==> %s\n' "$*"; }
run() {
  echo "+ $*"
  "$dry_run" || "$@"
}

remote="$(git -C "$dir" remote get-url origin)"
slug="$(sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##' <<<"$remote")"
echo "GitHub: $slug (deploys from $branch)"

step "Turn on Pages with GitHub Actions as the source"
build_type="$(gh api "repos/$slug/pages" --jq .build_type 2>/dev/null || true)"
if [[ "$build_type" == "workflow" ]]; then
  echo "Pages already deploys from GitHub Actions; skipping."
elif [[ -n "$build_type" ]]; then
  run gh api -X PUT "repos/$slug/pages" -f build_type=workflow --silent
else
  run gh api -X POST "repos/$slug/pages" -f build_type=workflow --silent
fi

step "Limit the github-pages environment to $branch"
# Turning on Pages creates the environment with only the default branch allowed; PUT creates or
# updates it.
run gh api -X PUT "repos/$slug/environments/github-pages" --silent --input - <<<'{
  "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true }
}'
policies="$(gh api "repos/$slug/environments/github-pages/deployment-branch-policies" \
  --jq '.branch_policies[] | "\(.id) \(.type // "branch") \(.name)"' 2>/dev/null || true)"
found=false
while read -r id type name; do
  [[ -z "$id" ]] && continue
  if [[ "$type" == "branch" && "$name" == "$branch" ]]; then
    found=true
    echo "Branch rule '$branch' already exists."
  else
    run gh api -X DELETE "repos/$slug/environments/github-pages/deployment-branch-policies/$id"
  fi
done <<<"$policies"
if ! "$found"; then
  run gh api -X POST "repos/$slug/environments/github-pages/deployment-branch-policies" \
    -f name="$branch" -f type=branch --silent
fi

step "Set the repository website"
url="$(gh api "repos/$slug/pages" --jq .html_url 2>/dev/null || true)"
url="${url:-https://${slug%%/*}.github.io/${slug##*/}/}"
if [[ "$(gh repo view "$slug" --json homepageUrl --jq .homepageUrl)" == "$url" ]]; then
  echo "Website is already $url; skipping."
else
  run gh repo edit "$slug" --homepage "$url"
fi

step "Next"
cat <<EOF
The docs deploy on the next official release (promote staging to main). They will be at:
  $url
EOF
