# Shared settings for the agentic eval scripts. Source it; don't run it.
#
# EVAL_DIR    Where clones, transcripts and results go (default: $TMPDIR/agentic-eval).
# TASKS_FILE  Repo-specific task definitions (default: tasks_example.sh next to this file).

eval_scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
powerpack="$(cd "$eval_scripts/../.." && pwd)"
EVAL_DIR="${EVAL_DIR:-${TMPDIR:-/tmp}/agentic-eval}"
TASKS_FILE="${TASKS_FILE:-$eval_scripts/tasks_example.sh}"
# shellcheck source=tasks_example.sh
source "$TASKS_FILE"

# find_task <id>: sets COMMIT and HIDDEN (array of hidden test paths) for a task, or exits.
find_task() {
  local row id commit rest
  for row in "${TASKS[@]}"; do
    read -r id commit rest <<<"$row"
    if [[ "$id" == "$1" ]]; then
      COMMIT="$commit"
      read -r -a HIDDEN <<<"$rest"
      return
    fi
  done
  echo "Unknown task '$1'. Tasks: $(printf '%s\n' "${TASKS[@]}" | cut -d' ' -f1 | tr '\n' ' ')" >&2
  exit 1
}
