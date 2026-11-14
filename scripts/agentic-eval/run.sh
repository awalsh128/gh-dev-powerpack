#!/usr/bin/env bash
# Runs the eval: for each task, sets up a baseline and a set clone, runs Claude Code headless in
# both at the same time, then scores them. Transcripts go to $EVAL_DIR/runs/<task>-<cond>.jsonl
# and scores are appended to $EVAL_DIR/results.tsv. Summarize with analyze.py.
#
# Usage: run.sh [task-id ...]   (default: every task)
# MODEL (default sonnet), EFFORT (medium), BUDGET_USD (5 per run) and TIMEOUT_S (1800 per run)
# override the agent settings. Each run counts against your Claude plan or API usage.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODEL="${MODEL:-sonnet}"
EFFORT="${EFFORT:-medium}"
BUDGET_USD="${BUDGET_USD:-5}"
TIMEOUT_S="${TIMEOUT_S:-1800}"
allowed=(Read Edit Write Glob Grep Agent Skill TodoWrite "${ALLOWED_BASH[@]}")

# Project settings only and no MCP servers, so user-level config doesn't differ between runs.
run_agent() {
  local dir="$1" prompt="$2" log="$3"
  (cd "$dir" && timeout "$TIMEOUT_S" claude -p "$prompt" \
    --output-format stream-json --verbose \
    --model "$MODEL" --effort "$EFFORT" \
    --setting-sources project --strict-mcp-config \
    --allowedTools "${allowed[@]}" \
    --max-budget-usd "$BUDGET_USD" \
    </dev/null >"$log" 2>"$log.err")
}

mkdir -p "$EVAL_DIR/runs"
results="$EVAL_DIR/results.tsv"
[[ -f "$results" ]] || printf 'task\tcond\thidden\tunit\ttype_errors\n' >"$results"

for row in "${TASKS[@]}"; do
  read -r id _ <<<"$row"
  if (( $# )) && [[ " $* " != *" $id "* ]]; then continue; fi
  prompt="$(prompt_for "$id")"
  for cond in baseline set; do "$eval_scripts/setup.sh" "$id" "$cond" >/dev/null || exit 1; done
  echo "$(date +%T) $id: running"
  for cond in baseline set; do
    run_agent "$EVAL_DIR/runs/$id-$cond" "$prompt" "$EVAL_DIR/runs/$id-$cond.jsonl" &
  done
  wait
  for cond in baseline set; do
    score="$("$eval_scripts/score.sh" "$id" "$cond")"
    echo "$(date +%T) $id $cond: $score"
    printf '%s\t%s\t%s\n' "$id" "$cond" "$(sed -E 's/[a-z_]+=//g; s/ /\t/g' <<<"$score")" >>"$results"
  done
done
