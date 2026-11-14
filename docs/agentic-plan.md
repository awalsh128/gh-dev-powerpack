# Plan: model-agnostic agentic configuration template

Status: phases 0 to 3 done 2026-11-13 (sources, principles doc, template skeleton, roles).

## Goal

A new template set, `templates/agentic/`, that gives any repo one source of truth for coding-agent
configuration. It should keep the baseline context small, use narrowly scoped read-only roles,
and follow orchestration rules that hold across Claude Code, Codex CLI, GitHub Copilot and
Google's Gemini/Antigravity CLI.

## Principles

See [Agentic Configuration Principles](agentic-principles.md).

## Verified tool facts (phase 0)

| | Claude Code | Codex CLI | Copilot (VS Code / CLI) | Gemini CLI / Antigravity |
|---|---|---|---|---|
| Root instructions | `CLAUDE.md`; reads `AGENTS.md` only when no CLAUDE.md, so use `@AGENTS.md` import | `AGENTS.md` | `AGENTS.md` (not confirmed on the docs page) | Gemini: `context.fileName` accepts a list, so set `["AGENTS.md"]`. Antigravity reads `AGENTS.md` natively |
| Subagents | `.claude/agents/*.md` (`name`, `description` required; `tools`, `disallowedTools`, `model`, `permissionMode`, `mcpServers`, `skills`, `effort`, `maxTurns`, …) | `.codex/agents/*.toml` (`name`, `description`, `developer_instructions` required; `model`, `model_reasoning_effort`, `features.shell_tool=false`, …) | `.github/agents/*.agent.md` (`tools` aliases: `read`, `edit`, `search`, `execute`, `web`, `agent`); **VS Code also reads `.claude/agents/`** | `.gemini/agents/*.md` (`name`, `description`, `tools`, `model`, `mcpServers`, `max_turns`) |
| Skills | `.claude/skills/` | supported | supported | Antigravity: `.agents/skills/` |
| Per-agent MCP scoping | yes | **no**, MCP and sandbox inherit from the parent | yes (`mcp-servers`) | yes |
| Model value | alias (`sonnet`/`opus`/`haiku`/`fable`), full ID, or `inherit` | model ID | ID or ordered list | ID or `inherit` |

Effects on the design:

- **Codex can't make a role read-only through MCP or the sandbox.** The closest controls are
  `features.shell_tool = false` plus instructions. The single-writer rule therefore has to live
  in the role prompt as well as in tool lists.
- **Gemini CLI was replaced by Antigravity CLI** for unpaid and Google One users on 2026-06-18.
  rulesync supports `antigravity-cli` but not `geminicli`.
- Model IDs differ for every tool, so roles declare a **tier** (`fast`, `balanced`, `deep`, or
  `inherit`). The tier-to-model table lives in one place.

## Decisions

1. **Adapter: rulesync, for subagents only.** It generates subagent files for `claudecode`,
   `codexcli`, `copilot` and `antigravity-cli` from `.rulesync/subagents/*.md`, which have a
   shared `name`/`description`/body and per-tool blocks (`claudecode:`, `copilot:`, …). It has
   `generate --check` for CI. Its `rules` feature is off because it would overwrite the
   hand-written `AGENTS.md`. Gemini subagents are left out of v1.
   - **Instructions:** `AGENTS.md` is hand-written and read directly by Codex, Copilot and
     Antigravity. `CLAUDE.md` is just `@AGENTS.md`, and `.gemini/settings.json` sets
     `context.fileName` to `AGENTS.md`.
   - **Skills: symlinks.** The only copy is in `.agents/skills/`. Codex, Gemini CLI and
     Antigravity read it natively (Gemini also gives it precedence over `.gemini/skills/`).
     `.claude/skills` and `.github/skills` are symlinks to it. `bootstrap.sh` now copies
     symlinks as symlinks and never replaces a real directory with one.
2. **Targets: Claude Code, Codex CLI, Copilot, Antigravity CLI** (plus the Gemini CLI settings
   stub).
3. **No parallel-writer pattern in v1.**

## Template layout

```
templates/agentic/
  AGENTS.md                      # hand-written skeleton: commands, conventions, warnings (~60-line budget)
  CLAUDE.md                      # "@AGENTS.md"
  docs/agents/orchestration.md   # loaded on demand: when to delegate, roles, brief, review loop
  rulesync.jsonc                 # subagents only, 4 targets
  .claude/skills -> ../.agents/skills
  .github/skills -> ../.agents/skills
  .rulesync/
    subagents/
      explorer.md                # read-only codebase search; returns conclusion + file:line refs
      researcher.md              # read-only web/docs research; primary sources, cited
      planner.md                 # read-only; produces a step plan, no edits
      reviewer.md                # fresh context; reviews diff vs spec and repo standards
      verifier.md                # runs targeted tests/lint; reports pass/fail + minimal output
  .agents/skills/
    handoff/SKILL.md             # how to brief a subagent (goal, constraints, decisions, output shape)
    progress-notes/SKILL.md      # structured notes file for long tasks
  .gemini/settings.json          # context.fileName -> AGENTS.md
  .github/workflows/agent-config.yml   # rulesync generate --check
  .out-of-scope/                 # one file per rejected idea with the reason, so agents don't re-propose it
```

Patterns taken from Sandcastle's own repo: a short root file that links to `docs/agents/*.md`;
`.out-of-scope/`; skills kept in `.agents/skills/` with `.claude/skills` symlinked to it; and
`AGENTS.md` and `CLAUDE.md` with the same content.

Role conventions:

- Every role is read-only. The main session is the only writer. There is no implementer role.
- Prompt body under about 40 lines, ending in a strict output format with a length cap.
- Tools are the narrowest set that works, listed per tool in rulesync blocks.
- Each role has a tier comment, and the model is set per tool from the tier table.

## Phases

0. ~~Check the primary sources~~ (done; see the table above).
1. ~~`docs/agentic-principles.md`~~ (done).
2. ~~Template skeleton~~ (done). rulesync itself hasn't been run against the config yet; that
   happens in phase 5.
3. ~~Role library~~ (done): five read-only roles in `.rulesync/subagents/`, each with a 20–33
   line prompt and a tagged output block, plus `.rulesync/TIERS.md`. Antigravity tool names
   (`view_file`, `grep_search`, `run_command`) come from the examples in its docs; a misspelled
   name can hang the agent, so check them in phase 6.
4. **Skills**: `handoff` and `progress-notes`, checked with `skills-ref validate`.
5. **CI**: an `agent-config.yml` workflow that runs `rulesync generate --check`. Decide whether to
   commit generated files (needed so tools work without running rulesync) or to generate them in
   a hook.
6. **Evaluate**: bootstrap this repo and one real project. Compare baseline context with
   `/context` (or the tool's equivalent), run the same 3–5 tasks with and without the set, then
   trim whatever doesn't help.
7. **Wire up**: README template-set table, `docs/agentic-config.md` guide, and how to run
   bootstrap.

## Future: unattended (AFK) orchestration

Static config can't run parallel writers safely, because that needs sandboxes, branches and a
merge step. [Sandcastle](https://github.com/mattpocock/sandcastle) provides that runtime: a
TypeScript `run()` with agent providers (`claudeCode()`, `codex()`, `copilot()`, `pi()`, …),
OS, container and cloud sandboxes, branch strategies, completion signals and validated structured
output. Its init templates (`simple-loop`, `sequential-reviewer`, `parallel-planner`,
`parallel-planner-with-review`) cover the orchestration patterns we'd want.

A possible later set, `agentic-afk`, would layer Sandcastle prompts on top of `agentic`. Those
would be plan → implement per issue → review → merge, reusing the same roles and skills. It stays
out of v1.

## Open questions

- VS Code reads both `.claude/agents/` and `.github/agents/`, so Copilot in VS Code may list each
  role twice. Check in phase 6, and if it does, drop the `copilot` target and rely on
  `.claude/agents/`.
- Symlinks on Windows need `core.symlinks=true` (and Developer Mode). Document it in the guide.

- Commit generated per-tool files, or generate them on checkout? (Committing is simpler for
  people who don't install rulesync.)
- Pin a rulesync version through `npx rulesync@<version>` in CI.
- Confirm that Copilot reads root `AGENTS.md`. The VS Code agent reference page doesn't say.

## Sources

Primary:

- [Anthropic: Effective context engineering for AI agents](https://anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic: How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Anthropic: Building effective agents](https://www.anthropic.com/research/building-effective-agents)
- [Cognition: Don't build multi-agents](https://cognition.ai/blog/dont-build-multi-agents)
- [Cognition: Multi-agents: what's actually working](https://cognition.com/blog/multi-agents-working)
- [OpenAI: A practical guide to building agents (PDF)](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf)
- [Gloaguen et al.: Evaluating AGENTS.md (arXiv 2602.11988)](https://arxiv.org/pdf/2602.11988)
- [Do context files help coding agents? Two-agent ablation](https://arxiv.org/html/2607.27250v1)
- [Agent Skills specification](https://agentskills.io/specification)
- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Gemini CLI subagents](https://geminicli.com/docs/core/subagents/)
- [Gemini CLI configuration](https://geminicli.com/docs/reference/configuration/)
- [VS Code custom agent file reference](https://code.visualstudio.com/docs/agents/reference/custom-agent-file-reference)
- [GitHub: About custom agents](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-custom-agents)
- [rulesync](https://github.com/dyoshikawa/rulesync)
- [rulesync supported tools](https://rulesync.dyoshikawa.com/reference/supported-tools)
- [Sandcastle](https://github.com/mattpocock/sandcastle): orchestration runtime, plus its own
  `.sandcastle/` prompts and agent config as a worked example

Secondary:

- [AGENTS.md as an open standard](https://codex.danielvaughan.com/2026/04/07/agents-md-open-standard-cross-tool-portability/)
- [MCP context bloat fixes (2026)](https://mcp.directory/blog/mcp-context-bloat-fix-2026-tool-search-code-mode-progressive-disclosure)
- [How to reduce MCP token bloat](https://thenewstack.io/how-to-reduce-mcp-token-bloat/)
- [LangChain: How and when to build multi-agent systems](https://blog.langchain.com/how-and-when-to-build-multi-agent-systems)
- [One rules source: AGENTS.md, Ruler and rulesync](https://developertoolkit.ai/en/ecosystem/frameworks/rules-sync/)
- [AgentSync](https://awesome.ecosyste.ms/projects/github.com%2Fdallay%2Fagentsync)
- [awesome-agent-rules](https://gh.r-mj.com/cyq1017/awesome-agent-rules)
