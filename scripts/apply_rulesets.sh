#!/usr/bin/env bash
# Creates or updates branch rulesets on a repo from JSON files (default: .github/rulesets/*.json).
#
# Usage: apply_rulesets.sh [-r owner/repo] [-a release_bot_app_id] [ruleset.json ...]
#   -r  Target repo (default: the current directory's GitHub repo).
#   -a  GitHub App ID allowed to bypass the "main" ruleset, so the promote workflow can push to it.
set -euo pipefail

repo=""
app_id=""
while getopts "r:a:h" opt; do
  case "$opt" in
    r) repo="$OPTARG" ;;
    a) app_id="$OPTARG" ;;
    *) sed -n '2,6p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
repo="${repo:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
files=("$@")
[[ ${#files[@]} -gt 0 ]] || files=(.github/rulesets/*.json)

for file in "${files[@]}"; do
  name="$(jq -r .name "$file")"
  body="$(cat "$file")"
  if [[ "$name" == "main" && -n "$app_id" ]]; then
    body="$(jq --argjson id "$app_id" \
      '.bypass_actors = [{actor_id: $id, actor_type: "Integration", bypass_mode: "always"}]' <<<"$body")"
  fi
  id="$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id")"
  if [[ -n "$id" ]]; then
    gh api -X PUT "repos/$repo/rulesets/$id" --input - <<<"$body" >/dev/null
    echo "Updated ruleset '$name' on $repo"
  else
    gh api -X POST "repos/$repo/rulesets" --input - <<<"$body" >/dev/null
    echo "Created ruleset '$name' on $repo"
  fi
done
