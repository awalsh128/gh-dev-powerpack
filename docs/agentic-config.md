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
| `.agents/skills/` | Skills: `delegate` (when and how to use a subagent), `progress-notes` (notes for work that spans sessions) and `vsce-demos` (record a demo video of a VS Code extension) |
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
  request is merged or closed), from `templates/agentic/AGENTS.md` to your `AGENTS.md`;
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

Create `.agents/skills/<name>/SKILL.md`; the rules are in `templates/agentic/.agents/skills/README.md`.
The symlinks make it visible to every tool, so there is nothing to generate.

## Recommended skills

The set doesn't ship general-purpose skills; install upstream ones instead
([principle 11](agentic-principles.md#11-reuse-existing-skills-before-writing-your-own)). All are
optional and none is enabled by default. Each adds its `name` and `description` to every session,
so install only what you use.

| Need | Skill | From |
| --- | --- | --- |
| Test-first changes | `tdd` | [mattpocock/skills](https://github.com/mattpocock/skills) |
| Review a branch against standards and the spec | `code-review` | same |
| Stress-test a plan before building | `grilling` | same |
| Plan work that won't fit in one session | `wayfinder`: a map of decision tickets on the issue tracker | same |
| Notes for one task across a few sessions | `progress-notes` (shipped here, local file, no tracker) | this set |
| TypeScript conventions (types, functions, variables, naming, tests) | `typescript-*`, see [TypeScript style](#typescript-style) | [mkosir/typescript-style-guide](https://github.com/mkosir/typescript-style-guide) |

Use `wayfinder` when the work spans many sessions and several people or agents; use
`progress-notes` when it is one task you will resume.

Install a pack either as a plugin, which updates itself, or with [skills.sh](https://skills.sh),
which copies editable files into the repo. Pick one per agent, or you get every skill twice. For
Claude Code:

```bash
claude plugin install mattpocock-skills@claude-plugins-official
```

The [upstream README](https://github.com/mattpocock/skills#installation-30-second-setup) has the
commands for Codex, Copilot and Gemini CLI. Skills installed as plugins live outside the repo, so
they aren't part of what the Agent Config check validates.

### TypeScript style

For an npm library (the `node` and `npm-publish` sets), install only the skills that fit, not the
whole pack. The pack's `typescript-react` and `typescript-source-organization` skills suit apps and
monorepos, and the umbrella `typescript-style-guide` overlaps the specific ones and triggers on any
TypeScript task. `--copy` and `-a codex` put real files in `.agents/skills/`, which every other
tool reads through the symlinks:

```bash
npx skills add mkosir/typescript-style-guide -a codex --copy -y \
  -s typescript-types typescript-functions typescript-variables typescript-naming typescript-tests
# add typescript-discriminated-unions if the code models variants
```

Read the installed files before you commit them, since skills run with the agent's permissions.
Commit `skills-lock.json` too, so `npx skills update` can tell what changed.

A skill only loads when its description matches, so route to it from `AGENTS.md`. Paste this,
trimmed to the skills you installed, under Conventions. It names the trigger and nothing else, so
it costs a few lines per session:

```markdown
## TypeScript Style

Before writing or reviewing TypeScript, load only the skill in `.agents/skills/` that the change touches:

- Type definitions, `any`/`unknown`, assertions, `readonly`, constants: `typescript-types`.
- Function signatures, arguments, return types, purity: `typescript-functions`.
- `const`, enum alternatives, boolean flags, `null` vs `undefined`: `typescript-variables`.
- New exports, identifiers, comments, TSDoc: `typescript-naming`.
- Tests: `typescript-tests`.

This file wins over the skills where they disagree. Don't rewrite existing code to match a skill.
```

The skills carry opinions that may not match the repo, such as `type` over `interface` and test
titles written as `should ... when ...`. List each override in `AGENTS.md` (for example "keep
`interface`") so the agent doesn't flip existing code. The skills pass `skills-ref validate`, the
check the Agent Config workflow runs.

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
