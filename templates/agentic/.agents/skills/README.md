# Skills

One folder per skill, following the [Agent Skills spec](https://agentskills.io/specification):
`<name>/SKILL.md`, plus optional `scripts/`, `references/` and `assets/`. The folder name must match
the skill's `name`.

Codex, Gemini CLI and Antigravity read this folder directly. `.claude/skills` and
`.github/skills` (Copilot) are symlinks to it, so add skills only here.

Agents load only a skill's `name` and `description` at startup and read the body when the skill
is used. Write the description as "what it does + when to use it". Keep `SKILL.md` under 500
lines and move detail to `references/`, one level deep.
