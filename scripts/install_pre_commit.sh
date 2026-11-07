#!/usr/bin/env bash
# Installs pre-commit (if missing) and the repo's hooks from .pre-commit-config.yaml.
set -euo pipefail

if ! command -v pre-commit >/dev/null 2>&1; then
  echo "pre-commit not found; installing..."
  if command -v pipx >/dev/null 2>&1; then
    pipx install pre-commit
  else
    python3 -m pip install --user pre-commit
  fi
fi

pre-commit install
echo "pre-commit installed. Run 'pre-commit run --all-files' to check every file."
