#!/usr/bin/env bash
# Sets up a repository for the release-flow, npm-publish and vscode-extension sets with Octo STS:
# creates the 'release' environment (main and staging only), turns on immutable releases and, for a public
# repository, private vulnerability reporting, checks that
# the Octo STS trust policies are on the default branch, and applies the rulesets with the Octo STS
# app allowed to bypass main. Prints the step only the website can do (installing the app). Safe to rerun.
#
# Usage: setup_github_release.sh [-n] [-r owner/repo] [-e environment]
#   -n  Dry run: print what would be done.
#   -r  Target repo (default: the current directory's GitHub repo).
#   -e  Environment name (default: release).
# Run it from the repository's root, with `gh` logged in as an admin of the repository.
set -euo pipefail

dry_run=false
repo=""
environment="release"
while getopts "nr:e:h" opt; do
  case "$opt" in
    n) dry_run=true ;;
    r) repo="$OPTARG" ;;
    e) environment="$OPTARG" ;;
    *) sed -n '2,11p' "$0"; exit 1 ;;
  esac
done
here="$(cd "$(dirname "$0")" && pwd)"
repo="${repo:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "Repository: $repo"
default_branch="$(gh api "repos/$repo" --jq .default_branch)"
app_id="$(gh api /apps/octo-sts --jq .id)"

step "Environment '$environment' (main and staging only)"
run gh api -X PUT "repos/$repo/environments/$environment" \
  -F deployment_branch_policy[protected_branches]=false \
  -F deployment_branch_policy[custom_branch_policies]=true --silent
existing="$(gh api "repos/$repo/environments/$environment/deployment-branch-policies" \
  --jq '.branch_policies[].name' 2>/dev/null || true)"
for branch in main staging; do
  if grep -qx "$branch" <<<"$existing"; then
    echo "$branch is already allowed."
  else
    run gh api -X POST "repos/$repo/environments/$environment/deployment-branch-policies" \
      -f name="$branch" -f type=branch --silent
  fi
done

step "Immutable releases (published tags and assets can no longer change)"
if [[ "$(gh api "repos/$repo/immutable-releases" --jq .enabled 2>/dev/null || echo false)" == "true" ]]; then
  echo "Already enabled."
else
  run gh api -X PUT "repos/$repo/immutable-releases" --silent
fi

step "Private vulnerability reporting (public repositories; SECURITY.md links to it)"
if [[ "$(gh api "repos/$repo" --jq .private)" == "true" ]]; then
  echo "Private repository; skipped."
elif [[ "$(gh api "repos/$repo/private-vulnerability-reporting" --jq .enabled 2>/dev/null || echo false)" == "true" ]]; then
  echo "Already enabled."
else
  run gh api -X PUT "repos/$repo/private-vulnerability-reporting" --silent
fi

step "Octo STS trust policies on $default_branch"
policies=0
for dir in .github/chainguard; do
  for file in "$dir"/*.sts.yaml; do
    [[ -e "$file" ]] || continue
    policies=$((policies + 1))
    if gh api "repos/$repo/contents/$file?ref=$default_branch" --silent 2>/dev/null; then
      echo "ok       $file"
    else
      echo "missing  $file (commit it to $default_branch; Octo STS reads it from there)"
    fi
  done
done
if [[ "$policies" -eq 0 ]]; then
  echo "No .github/chainguard/*.sts.yaml here. Bootstrap the release sets first."
fi

step "Rulesets (Octo STS app $app_id may bypass main)"
if [[ -d .github/rulesets ]]; then
  if "$dry_run"; then
    echo "+ $here/apply_rulesets.sh -r $repo -a $app_id"
  else
    "$here/apply_rulesets.sh" -r "$repo" -a "$app_id"
  fi
else
  echo "No .github/rulesets here; skipped."
fi

manual "Install the Octo STS app on $repo (Only select repositories):
         https://github.com/apps/octo-sts"
