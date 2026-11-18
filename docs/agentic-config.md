# Agentic Configuration

The `agentic` set configures coding agents from one source: Claude Code, Codex CLI, GitHub
Copilot, Gemini CLI and Antigravity. Every tool reads the same instructions and skills. Five
read-only subagent roles are generated for each tool, and the main agent is the only one that
edits files. [Agentic Configuration Principles](agentic-principles.md) explains each choice and
the evidence behind it.

## Bootstrap

```bash
./bootstrap.sh -n ~/repos/my-project agentic   # dry run
./bootstrap.sh    ~/repos/my-project agentic
```

| Path | What it is |
| --- | --- |
| `AGENTS.md` | Instructions every tool reads in every session. A skeleton for you to fill in |
| `CLAUDE.md` | `@AGENTS.md`, so Claude Code reads the same file |
| `.gemini/settings.json` | Points Gemini CLI at `AGENTS.md` |
| `.github/copilot-instructions.md` | Points GitHub Copilot at `AGENTS.md`. Don't add rules here |
| `.agents/skills/` | Skills: `delegate` (when and how to use a subagent), and `progress-notes` (notes for work that spans sessions) |
| `.claude/skills`, `.github/skills` | Symlinks to `.agents/skills/` for Claude Code and Copilot |
| `.rulesync/subagents/` | Source for the five roles: `explorer`, `researcher`, `planner`, `reviewer`, `verifier` |
| `.rulesync/TIERS.md` | How each role's tier (`fast`, `balanced`, `deep`) maps to each tool's model settings |
| `.claude/agents/`, `.codex/agents/`, `.github/agents/`, `.agents/agents/` | Roles generated from `.rulesync/` for Claude Code, Codex, Copilot and Antigravity. Don't edit these |
| `rulesync.jsonc` | rulesync config: subagents only, for the four tools above |
| `.agents/notes/` | Local progress notes, ignored by git |
| `.out-of-scope/` | One file per rejected idea, so agents don't propose it again |
| `.github/workflows/agent-config.yml` | Checks the generated roles and the skills |

If the repo already has an `AGENTS.md` or `CLAUDE.md`, bootstrap keeps it. In that case:

- add the `## Subagents` section, and optionally `## Housekeeping` (delete branches whose pull
  request is merged or closed), from `templates/agentic-config/agentic/AGENTS.md` to your `AGENTS.md`;
- if `CLAUDE.md` has content of its own, add `@AGENTS.md` as its first line.

## Optional: sync with the powerpack

The `agentic-powerpack` set adds a `powerpack-sync` skill that compares your repo with the
current patterns in this repo and proposes updates. It needs `agentic` and is off until you turn
it on.

```bash
./bootstrap.sh ~/repos/my-project agentic agentic-powerpack
```

`.agents/powerpack.json` controls it:

- `mode`: `off` (default) or `suggest`.
- `sets`: per-set override, such as `{"node": "off", "common": "suggest"}`.
- `ignore`: paths the skill never compares, such as `.github/labels.yaml`.

The skill finds which sets your repo uses from their signature files (listed in
`.agents/skills/powerpack-sync/references/signatures.md`), reports differences that matter, and
changes nothing until you approve each patch.

## Fill in AGENTS.md

Write it yourself and keep it short; the skeleton's header comment says what belongs in it, and
[principle 1](agentic-principles.md#1-keep-the-root-instruction-file-short-and-hand-written) has
the evidence. Put task-specific detail in `docs/agents/<topic>.md` and link it from `AGENTS.md`.

## Change a role

1. Edit `.rulesync/subagents/<role>.md`. The shared `name`, `description` and prompt body come
   first, followed by one block per tool (`claudecode:`, `codexcli:`, `copilot:`,
   `antigravity-cli:`) for its model and tool settings.
2. Regenerate the tools' files and commit both:

   ```bash
   npx -y rulesync@43.4.1 generate
   ```

A new role follows the existing ones (read-only, prompt under about 40 lines, a tagged output
block with a length limit, a tier from `TIERS.md`) and gets a row in the `delegate` skill's role
table. [Principles 3, 4 and 10](agentic-principles.md) explain why.

## Add a skill

Create `.agents/skills/<name>/SKILL.md`; the rules are in `templates/agentic-config/agentic/.agents/skills/README.md`.
The symlinks make it visible to every tool, so there is nothing to generate.

## Recommended skills

The set doesn't ship general-purpose skills. For those, pick an upstream pack on the evidence
below ([principle 11](agentic-principles.md#11-reuse-existing-skills-before-writing-your-own)).
All are optional and none is enabled by default. Each adds its `name` and `description` to every
session, so install only what you use.

**Pack health** (measured 2026-11-15 with the GitHub API; commits are for the last 90 days and
capped at 100):

| Pack | License | Commits | Authors | Latest release | Open issues |
| --- | --- | ---: | ---: | --- | ---: |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | MIT | 100+ | 12 | 2026-11-14 | 128 |
| [mattpocock/skills](https://github.com/mattpocock/skills) (plugin 1.3.2) | MIT | 100+ | 6 | 2026-10-29 | 248 |
| [OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files) | MIT | 100+ | 15 | 2026-11-07 | 12 |
| [anthropics/skills](https://github.com/anthropics/skills) | none at repo level | 15 | 7 | none | 1,548 |
| [obra/superpowers](https://github.com/obra/superpowers) | MIT | 6 | 1 | 2026-11-03 | 355 |

**Skills by need.** Cost is estimated tokens at startup / when the skill body loads (4 characters
per token). The default comes from a pack with several recent authors and has the lowest body cost; the
alternative is the next best. Some superpowers skills are cheaper still (`test-driven-development`
25 / 2,356, `requesting-code-review` 32 / 703), but that pack has one author and 6 recent commits.

| Need | Default | Cost | Alternative | Relation to the shipped set |
| --- | --- | ---: | --- | --- |
| Test-first changes | mattpocock `tdd` | 38 / 860 | addyosmani `test-driven-development` (146 / 4,035) | none |
| Review a branch against a spec | mattpocock `code-review` (needs `/setup-matt-pocock-skills`) | 108 / 1,557 | addyosmani `code-review-and-quality` (99 / 5,202) | `reviewer` role is a quick read-only diff check; use this for a whole branch against a spec |
| Stress-test a plan | mattpocock `grilling` | 40 / 469 | superpowers `brainstorming` (57 / 3,733) | none |
| Plan work across many sessions | mattpocock `wayfinder` (issue-tracker tickets) | 51 / 3,035 | planning-with-files (156 / 9,709, files on disk) | `progress-notes` covers one task you will resume; use this for work that needs a shared map |

What this does not show: how well any skill works, whether it passes `skills-ref validate`, and
which tools it supports beyond Claude Code. Stars are left out because the most-starred results
for agent skills include counts that don't look credible. Re-measure when you update a pack, by
hand, with the same method.

Install a pack as a plugin, which updates itself, or with [skills.sh](https://skills.sh), which
copies editable files into the repo. Pick one per agent, or you get every skill twice. For
mattpocock/skills on Claude Code:

```bash
claude plugin install mattpocock-skills@claude-plugins-official
```

The [upstream README](https://github.com/mattpocock/skills#installation-30-second-setup) has the
commands for Codex, Copilot and Gemini CLI. Skills installed as plugins live outside the repo, so
they aren't part of what the Agent Config check validates.

The `vsce-demos` skill (record a demo video of a VS Code extension) ships with the
`vscode-extension` set, not this one, so repos that aren't extensions don't pay for it. It lands
in `.agents/skills/`, so install `agentic` too for the Claude Code and Copilot symlinks.

## Tool support

| Tool | Instructions | Roles | Skills |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` → `AGENTS.md` | `.claude/agents/`, read-only by tool list | `.claude/skills` (symlink) |
| Codex CLI | `AGENTS.md` | `.codex/agents/*.toml`, read-only **by prompt only** | `.agents/skills/` |
| GitHub Copilot | `AGENTS.md`, plus `.github/copilot-instructions.md` pointing to it | `.github/agents/*.agent.md`, read-only by tool list | `.github/skills` (symlink) |
| Antigravity CLI | `AGENTS.md` | `.agents/agents/`, read-only by tool list | `.agents/skills/` |
| Gemini CLI | `AGENTS.md` via `.gemini/settings.json` | not generated | `.agents/skills/` |

Known limits:

- **Codex** roles are read-only by prompt only; see "Read-only enforcement" in
  `.rulesync/TIERS.md`.
- **VS Code** also reads `.claude/agents/`, so Copilot in VS Code may list each role twice. If it
  does, remove `copilot` from `rulesync.jsonc` and regenerate.
- **Antigravity** tool names come from its docs' examples and haven't been tested. A wrong tool
  name can make a subagent hang.
- **Windows** needs `git config core.symlinks true` and Developer Mode for the skill symlinks.
  Without them, Git checks the symlinks out as small text files.

## CI

The Agent Config workflow runs on PRs that touch agent config, and on pushes to `main`:

- `rulesync generate --check` fails when the generated roles don't match `.rulesync/`. Fix it by
  running `generate` and committing the result.
- The skill symlinks must point at `../.agents/skills`.
- `skills-ref validate` checks every skill against the spec.

Dependabot doesn't update the rulesync version (`RULESYNC_VERSION` in the workflow). Update it by
hand, ideally to a release at least two weeks old, and change the command above to match.

## Does it help?

The set adds about 640 tokens to each session before `AGENTS.md` is filled in. A first evaluation
on two small fixes found no difference in success or cost, and the agent didn't delegate
on such small tasks, as intended. Its effect on larger changes hasn't been measured yet. See the
[evaluation](agentic-plan.md#evaluation-2026-11-14) for details.
