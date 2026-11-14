#!/usr/bin/env bash
# Prepares a VS Code extension for trusted publishing from the vscode-extension set's
# publish-extension.yml, and prints the steps that can only be done on the registries' websites.
#
# - Visual Studio Marketplace: nothing to publish first; Trusted Publishing policies belong to the
#   publisher. The script prints how to create the publisher and the policy.
# - Open VSX: trusted publishing needs a namespace you own and an extension with a published
#   version. The script creates the namespace and publishes a placeholder version 0.0.0, then prints
#   how to claim the namespace and register the trusted publisher. Open VSX has no private
#   extensions, so the placeholder is public and says it is a placeholder; the first release (1.0.0)
#   replaces it as the latest version.
#
# Usage: setup_vscode_extension_publish.sh [-n] [-w workflow] [-e environment] [extension-dir]
#   -n  Dry run: print what would be done.
#   -w  Workflow file name (default: publish-extension.yml).
#   -e  GitHub environment name (default: release).
# extension-dir defaults to the current directory. The GitHub repo comes from its origin remote.
# Set OVSX_PAT to an Open VSX access token to skip the prompt. Safe to rerun: steps already done
# are skipped.
set -euo pipefail

dry_run=false
workflow="publish-extension.yml"
environment="release"
while getopts "nw:e:h" opt; do
  case "$opt" in
    n) dry_run=true ;;
    w) workflow="$OPTARG" ;;
    e) environment="$OPTARG" ;;
    *) sed -n '2,20p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
dir="$(cd "${1:-.}" && pwd)"

VSCE="@vscode/vsce@4.1.0"
OVSX="ovsx@1.3.0"
OPEN_VSX="https://open-vsx.org"

step() { printf '\n==> %s\n' "$*"; }
run() {
  echo "+ $*"
  "$dry_run" || "$@"
}
manual() { printf '\n[MANUAL] %s\n' "$*"; }
pause() {
  "$dry_run" && return
  read -r -p "Press Enter when done... " _
}
# Prints the HTTP status of a GET request.
status() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

if [[ ! -f "$dir/package.json" ]]; then
  echo "No package.json in $dir." >&2
  exit 1
fi
field() { node -p "require('$dir/package.json').$1 || ''"; }
publisher="$(field publisher)"
name="$(field name)"
display_name="$(field displayName)"
engine="$(node -p "(require('$dir/package.json').engines || {}).vscode || '^1.63.0'")"
remote="$(git -C "$dir" remote get-url origin)"
slug="$(sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##' <<<"$remote")"
owner="${slug%%/*}"
repo="${slug##*/}"
if [[ -z "$publisher" || -z "$name" ]]; then
  echo "package.json needs publisher and name." >&2
  exit 1
fi
echo "Extension: $publisher.$name"
echo "GitHub:    $slug (workflow $workflow, environment $environment)"

step "Visual Studio Marketplace"
cat <<EOF
[MANUAL] Create the publisher and its Trusted Publishing policy:
1. Sign in at https://marketplace.visualstudio.com/manage with a Microsoft account.
2. If there is no publisher "$publisher" yet, select "Create publisher" with:
     ID:   $publisher   (matches package.json; can't be changed later)
     Name: your display name
   and select "Create".
3. Open the publisher, select "Trusted Publishing", expand "Create", and enter:
     Policy name:      $name
     Repository owner: $owner
     Repository:       $repo
     Workflow:         $workflow
     Environment:      $environment
   then select "Create". For a private repository, run the workflow within 48 hours.
EOF
pause

step "Open VSX account"
if [[ -z "${OVSX_PAT:-}" ]]; then
  cat <<EOF
[MANUAL] Open VSX needs an access token once, to create the namespace and the placeholder:
1. Create an Eclipse account at https://accounts.eclipse.org/user/register and set its
   "GitHub Username" to the GitHub account you will use on Open VSX.
2. On $OPEN_VSX, select the account icon and log in with GitHub.
3. Open $OPEN_VSX/user-settings/profile, select "Log in with Eclipse", then
   "Show Publisher Agreement", and "Agree".
4. Open $OPEN_VSX/user-settings/tokens, select "Generate New Token", and copy it.
EOF
  if ! "$dry_run"; then
    read -r -s -p "Paste the Open VSX token: " OVSX_PAT
    echo
  fi
fi
# ovsx reads the token from the environment, which keeps it out of the process list.
export OVSX_PAT="${OVSX_PAT:-}"

step "Open VSX namespace"
if [[ "$(status "$OPEN_VSX/api/$publisher")" == 200 ]]; then
  echo "Namespace $publisher exists; skipping."
else
  run npx --yes "$OVSX" create-namespace "$publisher"
fi

step "Open VSX placeholder"
if [[ "$(status "$OPEN_VSX/api/$publisher/$name")" == 200 ]]; then
  echo "$publisher.$name already has a version; skipping."
else
  placeholder="$(mktemp -d)"
  trap 'rm -rf "$placeholder"' EXIT
  NAME="$name" PUBLISHER="$publisher" DISPLAY="${display_name:-$name}" ENGINE="$engine" \
    SLUG="$slug" node -e '
    const fs = require("fs");
    const env = process.env;
    fs.writeFileSync(process.argv[1] + "/package.json", JSON.stringify({
      name: env.NAME,
      publisher: env.PUBLISHER,
      displayName: `${env.DISPLAY} (placeholder)`,
      description: "Placeholder that reserves the name; the first release is 1.0.0.",
      version: "0.0.0",
      engines: { vscode: env.ENGINE },
      categories: ["Other"],
      repository: { type: "git", url: `https://github.com/${env.SLUG}.git` },
      license: "UNLICENSED",
    }, null, 2) + "\n");
    fs.writeFileSync(process.argv[1] + "/README.md",
      `# ${env.DISPLAY}\n\nPlaceholder. See https://github.com/${env.SLUG}.\n`);
  ' "$placeholder"
  (cd "$placeholder" && run npx --yes "$VSCE" package --skip-license --out placeholder.vsix)
  run npx --yes "$OVSX" publish "$placeholder/placeholder.vsix"
fi

step "Remaining manual steps for Open VSX"
# A verified namespace has an owner; trusted publishing requires that you are it.
if curl -s "$OPEN_VSX/api/$publisher" | grep -q '"verified":true'; then
  echo "Namespace $publisher is verified. If you are not its owner, ask the owner to add you."
else
  cat <<EOF
Claim ownership of the "$publisher" namespace, which trusted publishing requires: open an issue at
https://github.com/EclipseFdn/open-vsx.org/issues/new/choose and wait for it to be granted. See
https://github.com/eclipse/openvsx/wiki/Namespace-Access.
EOF
fi
cat <<EOF
1. As the namespace owner, open $OPEN_VSX/user-settings/trusted-publishers, select "$publisher",
   choose "GitHub Actions", and enter:
     Organization or User name: $owner
     Repository name:           $repo
     Workflow filename:         $workflow
     Environment name:          $environment
   For a private repository, the dialog shows a registration code once; it expires in 7 days. Add
   it as an OVSX_REGISTRATION_CODE secret and pass it to the ovsx publish step for the first run.
2. Delete the access token at $OPEN_VSX/user-settings/tokens.
3. Release with: gh workflow run $workflow --ref main -f dry_run=false
EOF
