# Orchestration

Read this before delegating to a subagent.

## When to delegate

Delegate when the work would fill your context with material you don't need to keep: a wide
codebase search, web research, a test run with long output, or a review of your own change.
Don't delegate:

- a task you could finish in a few tool calls;
- anything that edits files. You are the only writer, and subagents only read and report;
- work that needs the whole conversation to get right.

Delegate independent reads in parallel, in one message.

## Roles

| Role | Use it to |
| --- | --- |
| `explorer` | Find where something lives or how it works in this repo |
| `researcher` | Answer a question from external docs or the web |
| `planner` | Turn an agreed goal into steps before a large change |
| `reviewer` | Check your finished change against the task and this repo's standards |
| `verifier` | Run targeted tests or linters and report pass/fail |

## The brief

A subagent sees none of this conversation. Every brief has:

1. **Goal**: what to find out, and why it matters.
2. **Known context**: paste what it needs that you already have, such as the diff, the issue or
   the file paths. Don't make it rediscover them.
3. **Decisions already made**, and what is out of scope.
4. **Output**: each role ends its reply with a tagged block (`<findings>`, `<plan>`,
   `<review>` or `<result>`). Ask for something different only when you need it.

## Review loop

After a non-trivial change, send `reviewer` the task and the diff. Fix what it finds, then run
`verifier`. Stop after two review rounds and report anything still open.

## Long tasks

Record progress somewhere durable, not just in context. Commit with a message that says what was
done and what is left, or keep notes in a file the next session can read.
