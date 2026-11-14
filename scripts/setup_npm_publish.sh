#!/usr/bin/env bash
# Prepares an npm package for trusted publishing from the npm-publish set's release.yml: publishes a
# placeholder version 0.0.0 so the package exists (npm only configures trusted publishing on an
# existing package), then registers the GitHub Actions trusted publisher with `npm trust`. Prints
# the steps that can only be done on npmjs.com. Safe to rerun: steps already done are skipped.
#
# Usage: setup_npm_publish.sh [-n] [-p] [-w workflow] [-e environment] [package-dir]
#   -n  Dry run: print what would be done.
#   -p  Publish the placeholder as private (--access restricted). Needs a scoped name (@scope/name)
#       and a paid npm plan. Without it, the placeholder is public and deprecated.
#   -w  Workflow file name (default: release.yml).
#   -e  GitHub environment name (default: release).
# package-dir defaults to the current directory. The GitHub repo comes from its origin remote.
# Needs npm 11.15.0 or later, two-factor authentication on your npm account, and an interactive
# terminal, because npm asks for two-factor approval at each step.
set -euo pipefail

dry_run=false
private=false
workflow="release.yml"
environment="release"
while getopts "npw:e:h" opt; do
  case "$opt" in
    n) dry_run=true ;;
    p) private=true ;;
    w) workflow="$OPTARG" ;;
    e) environment="$OPTARG" ;;
    *) sed -n '2,16p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
dir="$(cd "${1:-.}" && pwd)"
# npm publish, deprecate and trust each ask for two-factor authentication, and npm only waits for
# the browser approval when it runs in a terminal; otherwise it fails with EOTP.
if ! "$dry_run" && [[ ! -t 0 ]]; then
  echo "Run this in an interactive terminal: npm's two-factor prompts need one." >&2
  exit 1
fi

step() { printf '\n==> %s\n' "$*"; }
run() {
  echo "+ $*"
  "$dry_run" || "$@"
}
manual() { printf '\n[MANUAL] %s\n' "$*"; }

if [[ ! -f "$dir/package.json" ]]; then
  echo "No package.json in $dir." >&2
  exit 1
fi
name="$(node -p "require('$dir/package.json').name")"
remote="$(git -C "$dir" remote get-url origin)"
slug="$(sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##' <<<"$remote")"
echo "Package: $name"
echo "GitHub:  $slug (workflow $workflow, environment $environment)"

if "$private" && [[ "$name" != @*/* ]]; then
  echo "Private packages must be scoped (@scope/name)." >&2
  exit 1
fi
npm_version="$(npm --version)"
if [[ "$(printf '%s\n' 11.15.0 "$npm_version" | sort -V | head -n 1)" != 11.15.0 ]]; then
  echo "npm $npm_version is too old for npm trust; run: npm install -g npm@latest" >&2
  exit 1
fi

step "Check package.json"
repo_url="$(node -p "(require('$dir/package.json').repository || {}).url || ''")"
if [[ "$repo_url" != *"github.com/$slug"* && "$repo_url" != *"github.com:$slug"* ]]; then
  manual "Set repository.url in package.json to git+https://github.com/$slug.git. npm rejects
         provenance unless it matches the repository exactly."
fi
access="$(node -p "(require('$dir/package.json').publishConfig || {}).access || ''")"
if [[ "$name" == @*/* && "$access" != "public" ]] && ! "$private"; then
  manual "Add \"publishConfig\": { \"access\": \"public\" } to package.json; scoped packages are
         private by default."
fi

step "Log in to npm"
if npm whoami >/dev/null 2>&1; then
  echo "Logged in as $(npm whoami)."
else
  manual "Create an account at https://www.npmjs.com/signup if you don't have one, verify your
         email, and turn on two-factor authentication under Account."
  run npm login
fi

step "Publish the placeholder"
if npm view "$name" name >/dev/null 2>&1; then
  echo "$name already exists on npm; skipping."
else
  placeholder="$(mktemp -d)"
  trap 'rm -rf "$placeholder"' EXIT
  NAME="$name" SLUG="$slug" node -e '
    const fs = require("fs");
    fs.writeFileSync(process.argv[1] + "/package.json", JSON.stringify({
      name: process.env.NAME,
      version: "0.0.0",
      description: "Placeholder that reserves the name; the first release is 1.0.0.",
      repository: { type: "git", url: `git+https://github.com/${process.env.SLUG}.git` },
      license: "UNLICENSED",
    }, null, 2) + "\n");
    fs.writeFileSync(process.argv[1] + "/README.md",
      `# ${process.env.NAME}\n\nPlaceholder. See https://github.com/${process.env.SLUG}.\n`);
  ' "$placeholder"
  placeholder_access="public"
  "$private" && placeholder_access="restricted"
  # A rerun while npm is still processing an earlier publish fails with "cannot publish over the
  # previously published versions"; the wait below covers both cases.
  if ! (cd "$placeholder" && run npm publish --access "$placeholder_access"); then
    echo "npm publish failed; waiting in case an earlier publish is still processing."
  fi
fi

# npm takes a few minutes to make a new package available, and deprecate and trust fail until then.
if ! "$dry_run"; then
  for ((i = 0; ; i++)); do
    npm view "$name@0.0.0" version >/dev/null 2>&1 && break
    if ((i >= 60)); then
      echo "$name@0.0.0 is not available after 10 minutes; rerun this script later." >&2
      exit 1
    fi
    ((i % 6 == 0)) && echo "Waiting for npm to make $name@0.0.0 available..."
    sleep 10
  done
fi

if ! "$private"; then
  step "Deprecate the placeholder"
  if [[ -n "$(npm view "$name@0.0.0" deprecated 2>/dev/null)" ]]; then
    echo "$name@0.0.0 is already deprecated; skipping."
  else
    run npm deprecate "$name@0.0.0" "Placeholder; use a released version."
  fi
fi

step "Register the trusted publisher"
if ! "$dry_run" && npm trust list "$name" --json 2>/dev/null | grep -q "$workflow"; then
  echo "A trusted publisher for $workflow already exists; skipping."
else
  # The first request asks for two-factor authentication.
  run npm trust github "$name" --file "$workflow" --repository "$slug" \
    --environment "$environment" --allow-publish --yes
fi

step "Remaining manual steps"
cat <<EOF
1. Release within 2 days: npm expires a new trusted publisher that hasn't published. Merge a feat:
   or fix: commit to staging, then run the "Promote staging to main" workflow.
2. After the first release publishes, open https://www.npmjs.com/package/$name/access, select
   "Require two-factor authentication and disallow tokens" under Publishing access, and select
   "Update Package Settings". Then revoke automation tokens you no longer need at
   https://www.npmjs.com/settings/$(npm whoami 2>/dev/null || echo '<user>')/tokens.
EOF
if "$private"; then
  cat <<EOF
3. The placeholder is private. Before the first release, make the package public, or the release
   publishes privately and without provenance:
     npm access set status=public $name
EOF
fi
