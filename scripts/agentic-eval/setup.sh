#!/usr/bin/env bash
# Sets up one eval run: clones the source repo at the task commit's parent into
# $EVAL_DIR/runs/<task>-<cond>, installs dependencies, writes the shared AGENTS.md snapshot (plus
# the agentic set for "set"), and commits that as the start state.
#
# Usage: setup.sh <task-id> <baseline|set>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

task="${1:?task id}" cond="${2:?baseline or set}"
[[ "$cond" == baseline || "$cond" == set ]] || { echo "Condition must be baseline or set" >&2; exit 1; }
find_task "$task"

dir="$EVAL_DIR/runs/$task-$cond"
rm -rf "$dir"
mkdir -p "$EVAL_DIR/runs"
git clone -q --no-checkout "$SRC_REPO" "$dir"
git -C "$dir" checkout -q "$COMMIT~1"
git -C "$dir" remote set-url origin "$REMOTE_URL"
git -C "$dir" switch -q -c eval
(cd "$dir" && "${INSTALL[@]}" >/dev/null)

git -C "$SRC_REPO" show "$AGENTS_REF:AGENTS.md" >"$dir/AGENTS.md"
if [[ "$cond" == set ]]; then
  "$powerpack/bootstrap.sh" "$dir" agentic >/dev/null
  cat >>"$dir/AGENTS.md" <<'EOF'

## Subagents

You are the only agent that edits files. Subagents only read and report. Use the `delegate` skill
before starting one, and the `progress-notes` skill for work that spans sessions.
EOF
fi
git -C "$dir" add -A
git -C "$dir" -c core.hooksPath=/dev/null -c user.name=eval -c user.email=eval@localhost \
  commit -q -m "eval: start state ($cond)"
echo "$dir"
