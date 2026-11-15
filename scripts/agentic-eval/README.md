# Agentic set evaluation

Measures whether the `agentic` template set changes how well Claude Code completes real tasks,
and at what cost. Each task replays a past fix: the agent starts from the fix commit's parent with
a bug report as its prompt. Scoring then overlays the commit's own tests, which the agent never
saw, and runs them, the unit suite and the type check.

Every task runs in two conditions, side by side:

- **baseline:** the source repo's `AGENTS.md`;
- **set:** the same `AGENTS.md` plus the `agentic` set and its Subagents section.

Results from 2026-11-14 are in [the plan](../../docs/agentic-plan.md#evaluation-2026-11-14).

## Run

```bash
scripts/agentic-eval/run.sh                    # every task
scripts/agentic-eval/run.sh t1-inst-lines      # one task
python3 -I scripts/agentic-eval/analyze.py     # table of scores, cost, turns, subagents, skills
```

Each run is a fresh clone under `$EVAL_DIR` (default `$TMPDIR/agentic-eval`), so the source repo
is never changed. Claude Code runs headless with project settings only, no MCP servers, a shell
allowlist, and a cap of `BUDGET_USD` (default 5) per run. Runs count against your Claude plan or
API usage. Small fixes cost about $0.10–0.20 each on Sonnet.

| Variable | Default | Meaning |
| --- | --- | --- |
| `EVAL_DIR` | `$TMPDIR/agentic-eval` | Clones, transcripts (`runs/*.jsonl`) and `results.tsv` |
| `TASKS_FILE` | `tasks_example.sh` | Task definitions |
| `SRC_REPO` | none (required) | Local clone of the repo the tasks come from |
| `AGENTS_REF` | `HEAD` | Ref of the source repo's `AGENTS.md` to use in both conditions |
| `MODEL`, `EFFORT` | `sonnet`, `medium` | Agent model and effort |
| `BUDGET_USD`, `TIMEOUT_S` | `5`, `1800` | Per-run cost and time limits |

## Files

| File | Purpose |
| --- | --- |
| `run.sh` | Sets up, runs and scores each task in both conditions |
| `setup.sh` | Clones one task and condition and commits the start state |
| `score.sh` | Overlays the hidden tests and runs the checks for one run |
| `analyze.py` | Joins scores with cost, turns, tokens, and subagent and skill use from the transcripts |
| `common.sh` | Shared settings and task lookup |
| `tasks_example.sh` | Example tasks, prompts and commands |

## Add tasks or another repo

Copy `tasks_example.sh`, point `TASKS_FILE` at it, and set the source repo, install, test and
type-check commands and the shell allowlist. For each task, pick a fix commit whose tests are
small and self-contained. Then check that its hidden tests fail before the fix and pass after:

```bash
scripts/agentic-eval/setup.sh <task> baseline
scripts/agentic-eval/score.sh <task> baseline                      # expect hidden=fail
git -C "$EVAL_DIR/runs/<task>-baseline" checkout <commit> -- src
scripts/agentic-eval/score.sh <task> baseline                      # expect hidden=pass
```

Write each prompt as a bug report or feature request. Name any new API the hidden tests call, but
don't describe the fix.

## Limits

- One run per task and condition is noisy. Use at least three before drawing conclusions.
- Small fixes don't make the main agent delegate, so they say nothing about the roles or the
  review loop. Use larger, multi-file changes to test those.
- Only Claude Code is wired up.
