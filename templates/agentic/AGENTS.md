<!-- Every agent loads this file in every session. Keep it under about 60 lines, and include only
what an agent can't learn from the code: exact commands, non-standard conventions and warnings.
Put task-specific detail in docs/agents/ and link it below. Delete this comment. -->

# Agent Instructions

## Commands

- Build: `TODO`
- Test one file or case: `TODO`. Use this while working.
- Full test suite: `TODO`. Slow, so run it once before finishing.
- Lint and format: `TODO`

## Conventions

- TODO: only rules that differ from the language or framework defaults.

## Warnings

- TODO: slow or destructive commands, generated files not to edit by hand, and so on.

## Subagents

You are the only agent that edits files. Subagents only read and report. Use the `delegate` skill
before starting one, and the `progress-notes` skill for work that spans sessions.

## More context

- TODO: `docs/agents/<topic>.md`: read it when <situation>.
- `.out-of-scope/` lists ideas that were considered and rejected. Check it before proposing a
  feature.
