# Agentic Configuration Principles

The `agentic` set configures coding agents (Claude Code, Codex CLI, GitHub Copilot, Gemini and Antigravity
CLI) from one source. Every file in it follows the rules below. Each rule says what it means for the template
and links to the evidence behind it. Template comments link back to this page instead of repeating it.

## 1. Keep the root instruction file short and hand-written

`AGENTS.md` loads into every session, and agents follow it closely. A file that says too much makes them
search, read and test more without solving more tasks. In one study, context files gave no gain in task
success and added more than 20% to inference cost, and LLM-generated files did worst
([Gloaguen et al.](https://arxiv.org/pdf/2602.11988)). What did change behavior was a specific warning, such
as "run targeted tests, not the full suite" ([ablation study](https://arxiv.org/html/2607.27250v1)).

**In the template:** `AGENTS.md` keeps to about 60 lines. It holds only what an agent can't find on its own:
exact build and test commands, non-standard conventions, and warnings about slow or dangerous operations.
Don't generate it with `/init` or let an agent write it; anything that duplicates the README or the code
belongs out.

## 2. Load detail only when a task needs it

Context is an attention budget: as it grows, recall gets worse. The goal is the smallest set of high-signal
tokens, pulled in just in time
([Anthropic](https://anthropic.com/engineering/effective-context-engineering-for-ai-agents)). Agent Skills do
this in three stages: only `name` and `description` (about 100 tokens) load at startup, the body loads when
the skill is used, and files in `references/` load only when read
([spec](https://agentskills.io/specification)).

**In the template:** procedures (delegating, keeping notes, releasing) are skills, not sections of
`AGENTS.md`. A `SKILL.md` stays under 500 lines, with detail moved to `references/` one level deep. Background
that only some tasks need goes in `docs/agents/<topic>.md`, linked from the root file with the situation it
applies to.

## 3. Use subagents to isolate context, not to model an org chart

A subagent gets its own context window, does wide or noisy work in it, and returns a short result. Anthropic's
research system did much better with parallel read-only subagents than with a single agent, but used about 15×
the tokens of a chat. It suits breadth-first work that doesn't fit one window, and doesn't suit tasks where
every agent needs the same context
([Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)).

**In the template:** subagents are for searching, researching, reviewing and verifying, never for splitting up
an edit. Each returns a conclusion in a fixed format with a length cap, not raw tool output.

## 4. Only one agent writes

Agents working in parallel make conflicting implicit decisions, and summaries between them lose those
decisions ([Cognition, 2025](https://cognition.ai/blog/dont-build-multi-agents)). The multi-agent pattern that
works keeps writes single-threaded while other agents contribute findings, and a reviewer that starts without
the writer's context catches what the writer missed
([Cognition, 2026](https://cognition.com/blog/multi-agents-working)).

Parallel writing works only with isolation on top. Sandcastle's `parallel-planner` first builds a dependency
graph of the issues, treating overlapping files as a block. It then gives each unblocked issue its own branch
and sandbox and merges them at the end with a separate agent
([Sandcastle](https://github.com/mattpocock/sandcastle)). That needs a runtime, not just config files.

**In the template:** every role is read-only, and there is no implementer role. The read-only rule is stated
in the role's prompt as well as in its tool list, because Codex agent files can't remove MCP servers or change
the sandbox ([Codex docs](https://learn.chatgpt.com/docs/agent-configuration/subagents)).

## 5. Hand off decisions, not just tasks

A subagent that gets only a one-line task fills the gaps with its own assumptions
([Cognition](https://cognition.ai/blog/dont-build-multi-agents)).

**In the template:** every delegation uses the `delegate` skill's brief: goal, context pasted in, decisions
already made and what's out of scope, and any change to the expected output.

## 6. Add structure only when it pays

Start with one agent and a good prompt. Move to prompt chaining, routing, parallel workers,
orchestrator-workers or evaluator-optimizer loops only when a simpler setup measurably falls short
([Anthropic](https://www.anthropic.com/research/building-effective-agents),
[OpenAI](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf)).

**In the template:** the defaults are a single main agent, optional read-only helpers, and one review loop
(main agent, then `reviewer`, then main agent). Add roles or patterns only after measuring the tasks they're
meant to improve.

## 7. Keep the tool surface small

Tool definitions load on every request. One MCP server can cost about 17k tokens before the first message, and
verbose tool results fill the window quickly
([The New Stack](https://thenewstack.io/how-to-reduce-mcp-token-bloat/)). The fixes are fewer servers,
deferred or search-based tool loading, and tools that return only the fields needed.

**In the template:** no MCP servers are enabled globally. A role that needs a server lists it in its own
config, where the tool allows that. Roles name the smallest tool set that works.

## 8. Roles name a capability tier, not a model

Every tool spells model names differently: Claude Code uses aliases or IDs, Codex and Gemini use IDs, and
Copilot accepts a ranked list. They also change faster than roles do.

**In the template:** each role is `fast`, `balanced` or `deep`, and `.rulesync/TIERS.md` is the only place
that maps a tier to per-tool settings.

## 9. Inject context you already know is needed

When a task always needs the same facts, such as the issue, the diff or recent commits, an agent that has to
find them spends turns and tokens on discovery. Sandcastle's prompts insert them by running a shell command
when the prompt is built (`` !`git diff main..HEAD` ``, `` !`gh issue view 42` ``), and leave exploration for
what can't be known in advance ([Sandcastle](https://github.com/mattpocock/sandcastle/tree/main/.sandcastle)).

**In the template:** a skill or role with a fixed input, like `reviewer` on a diff, inserts that input in its
brief or skill body. It doesn't tell the agent to "go find the changes".

## 10. Give every delegated run an output contract and a stop condition

A run that ends in free-form prose has to be read by a model to be used. Sandcastle ends each step with a
tagged block (`<plan>{…}</plan>`, `<output>{…}</output>`) that code validates, and it retries on bad output.
Loops stop on an explicit signal (`<promise>COMPLETE</promise>`) or an iteration cap. Its implementer writes
"blockers or notes for next iteration" into the commit message, so the git log carries state between runs
([Sandcastle iterations](https://github.com/mattpocock/sandcastle/blob/main/docs/guide/iterations.md)).

**In the template:** each role ends with a fixed, tagged output block. Long tasks record progress somewhere
durable (commit messages or the notes file), not only in the context window.

## 11. Reuse healthy existing skills before writing your own

A skill costs tokens in every session (its `name` and `description` load at startup), and a copy of someone
else's skill goes stale. A skill that someone else keeps maintaining is cheaper to install than to recreate,
but only if it is actually maintained and cheap to load.

**In the template:** it ships only skills that depend on this set's own roles or layout (`delegate`,
`progress-notes`). A skill that one repo type needs lives in that type's set (`vsce-demos` in
`vscode-extension`). For general workflows such as TDD, code review, grilling or multi-session planning, it
recommends an upstream skill and doesn't copy it.

A recommendation rests on measured health, not on who wrote it: a license, recent commits and the number of
authors behind them, releases, and the skill's startup and body cost. Don't use stars. Compare at least two
packs for each need and name the alternative. Write your own skill only when it needs repo-specific roles or
conventions. Install one pack per agent, and check that its descriptions don't trigger on the same requests as
yours.
