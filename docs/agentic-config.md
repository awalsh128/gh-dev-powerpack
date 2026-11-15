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
| `.agents/skills/` | Skills: `delegate` (when and how to use a subagent) and `progress-notes` (notes for work that spans sessions) |
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

Every agent loads this file in every session and follows it closely, so each line costs tokens
and steers behavior. Keep it under about 60 lines, and write it yourself. Generated files did
worst in the [AGENTS.md study](https://arxiv.org/pdf/2602.11988). Include only what an agent
can't learn from the code:

- exact build, test, lint and type-check commands, with the fast way to test one file;
- conventions that differ from the language or framework defaults;
- warnings: slow or destructive commands, generated files, what not to touch.

Put task-specific detail, such as releasing or triage, in `docs/agents/<topic>.md`, and link it
from `AGENTS.md` with the situation it applies to.

## Change a role

1. Edit `.rulesync/subagents/<role>.md`. The shared `name`, `description` and prompt body come
   first, followed by one block per tool (`claudecode:`, `codexcli:`, `copilot:`,
   `antigravity-cli:`) for its model and tool settings.
2. Regenerate the tools' files and commit both:

   ```bash
   npx -y rulesync@43.4.1 generate
   ```

A new role should follow the same pattern as the existing ones:

- read-only: say so in the prompt, and list only reading tools for each tool;
- a prompt under about 40 lines;
- a tagged output block with a length limit (`<findings>`, `<plan>`, …);
- a tier from `TIERS.md`;
- a row in the `delegate` skill's role table.

## Add a skill

Create `.agents/skills/<name>/SKILL.md` following the [Agent Skills
spec](https://agentskills.io/specification). The folder name must match `name`, and the
`description` should say what the skill does and when to use it. Keep `SKILL.md` under 500 lines
and move detail into `references/`. The symlinks make every skill visible to every tool, so there
is nothing to generate.

## Tool support

| Tool | Instructions | Roles | Skills |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` → `AGENTS.md` | `.claude/agents/`, read-only by tool list | `.claude/skills` (symlink) |
| Codex CLI | `AGENTS.md` | `.codex/agents/*.toml`, read-only **by prompt only** | `.agents/skills/` |
| GitHub Copilot | `AGENTS.md`, plus `.github/copilot-instructions.md` pointing to it | `.github/agents/*.agent.md`, read-only by tool list | `.github/skills` (symlink) |
| Antigravity CLI | `AGENTS.md` | `.agents/agents/`, read-only by tool list | `.agents/skills/` |
| Gemini CLI | `AGENTS.md` via `.gemini/settings.json` | not generated | `.agents/skills/` |

Known limits:

- **Codex** agent files can't restrict tools or the sandbox, and Codex reads files through its
  shell. Roles there are read-only only because their prompts say so.
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
