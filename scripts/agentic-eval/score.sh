#!/usr/bin/env bash
# Scores one run: overlays the task commit's hidden tests on the agent's work, then runs them,
# the unit suite and the type check. Logs go to score-*.log in the run directory.
#
# Usage: score.sh <task-id> <baseline|set>
# Prints: hidden=<pass|fail> unit=<pass|fail> type_errors=<n>
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

task="${1:?task id}" cond="${2:?baseline or set}"
find_task "$task"
cd "$EVAL_DIR/runs/$task-$cond" || exit 1

git checkout -q "$COMMIT" -- "${HIDDEN[@]}"
specs=()
for path in "${HIDDEN[@]}"; do
  [[ "$path" == *.test.* ]] && specs+=("$path")
done
"${TEST_HIDDEN[@]}" "${specs[@]}" >score-hidden.log 2>&1 && hidden=pass || hidden=fail
"${TEST_UNIT[@]}" >score-unit.log 2>&1 && unit=pass || unit=fail
"${TYPECHECK[@]}" >score-types.log 2>&1
echo "hidden=$hidden unit=$unit type_errors=$(grep -c "$TYPE_ERROR_PATTERN" score-types.log)"
