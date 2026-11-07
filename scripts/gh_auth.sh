#!/usr/bin/env bash
# Logs in to GitHub with gh (browser flow if needed), makes git use gh for credentials, and exports
# GITHUB_TOKEN. Source it to keep the token in your shell: source scripts/gh_auth.sh
set -e

if ! gh auth status >/dev/null 2>&1; then
  echo "Not authenticated. Opening browser for login..."
  gh auth login --web
else
  echo "Already authenticated."
fi

# Clear existing helpers to avoid a "multiple values" error.
git config --global --unset-all credential.helper 2>/dev/null || true
git config --global --add credential.helper '!gh auth git-credential'
echo "Git uses gh for credentials."

GITHUB_TOKEN="$(gh auth token)"
export GITHUB_TOKEN
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "GITHUB_TOKEN was exported in a subshell only; source this script to keep it."
else
  echo "GITHUB_TOKEN exported."
fi
