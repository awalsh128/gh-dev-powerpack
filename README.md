# gh-dev-powerpack

Powerpack for developing code and managing CI/CD. This repo has generic helper code and templates
to quickly bootstrap new projects and to raise the quality of existing ones.

## Bootstrap a repo

```bash
./bootstrap.sh -n ~/repos/my-project common conventional-commits   # dry run
./bootstrap.sh    ~/repos/my-project common conventional-commits
```

Files that already exist in the target are skipped unless you pass `-f`. When two sets have the
same file, the set listed first wins, so put language sets before `common` (for example
`dotnet common` to get the .NET `.editorconfig`).

Placeholders `__OWNER__`, `__REPO__` and `__MAINTAINER__` are filled from the target's `origin`
remote. Override them with `OWNER=`, `REPO=` and `MAINTAINER=`.

## Template sets

| Set | What it adds |
| --- | --- |
| `common` | `.editorconfig`, issue forms (bug, feature, contact links), PR template, Dependabot for pinned actions, `labels.yaml` with a Sync Labels workflow, Issue Triage workflow (assign maintainer, label untemplated issues), CodeQL workflow, `require-ci-success` composite action |
| `conventional-commits` | `commitlint.config.js`, husky `commit-msg` hook, Commit Lint workflow that checks every PR commit and the PR title |
| `release-flow` | `promote.yml` that fast-forwards `main` to `staging` after CI passes and starts `release.yml`, plus branch rulesets for `main` and `staging` |
| `node` | Dev container for Node 24 and a Codecov config |
| `cpp` | `.clang-format`, `.clang-tidy`, pre-commit config, and a format check workflow that fails on unformatted files |
| `dotnet` | Full `.editorconfig` with .NET and C# code style rules |

After bootstrapping, edit:

- `codeql.yml`: the language matrix.
- `dependabot.yml`: uncomment the package ecosystem block.
- `labels.yaml`: add project-specific labels.
- `rulesets/staging.json`: the required status check names must match your CI job names.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/gh_auth.sh` | Log in with `gh`, make git use it for credentials, and export `GITHUB_TOKEN` (source it) |
| `scripts/install_pre_commit.sh` | Install pre-commit and the repo's hooks |
| `scripts/apply_rulesets.sh` | Create or update branch rulesets from JSON; `-a <app-id>` lets a release-bot app bypass `main` |

## Sources

These were made generic from awalsh128/ts-apt (release flow, PR and Dependabot config, CI
actions), awalsh128/vscode-keep-sorted (labels, issue forms, triage), awalsh128/fluentcpp (C++
formatting and linting) and awalsh128/PcapngFile (.NET `.editorconfig`). Actions are pinned to
commit SHAs.
