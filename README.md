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
| `common` | `.editorconfig`, issue forms (bug, feature, contact links), PR template, Dependabot for pinned actions, `labels.yaml` with a Sync Labels workflow (crazy-max/ghaction-github-labeler; dry run on PRs, never deletes), Issue Triage workflow (assign maintainer, label untemplated issues), CodeQL workflow, `require-ci-success` composite action |
| `conventional-commits` | `commitlint.config.mjs`, husky `commit-msg` hook, Commit Lint workflow that checks every PR commit (wagoid/commitlint-github-action) and the PR title (amannn/action-semantic-pull-request) |
| `release-flow` | `promote.yml` that fast-forwards `main` to `staging` after CI passes and starts `release.yml`, plus branch rulesets for `main` and `staging` |
| `node` | Dev container for Node 24, a Codecov config, and a `setup` composite action (Node 24, `npm ci`, optional `--ignore-scripts`) |
| `npm-publish` | `release.yml` and `release.config.cjs`: semantic-release cuts `-rc` candidates on `staging` and publishes official releases from `main` to npm with trusted publishing; needs `node` and `release-flow` |
| `npm-pages` | `typedoc.json`: the `npm-publish` release builds TypeDoc API docs and deploys them to GitHub Pages on official releases; needs `npm-publish` |
| `vscode-extension` | `publish-extension.yml`, `release.config.cjs` and `scripts/vscode-release/release-version.mts`: semantic-release with VS Code's even/odd pre-release versions, publishing to the Marketplace and Open VSX with trusted publishing; needs `node` |
| `cpp` | `.clang-format`, `.clang-tidy`, pre-commit config, and a format check workflow (jidicula/clang-format-action, clang-format 22) that fails on unformatted files |
| `dotnet` | Full `.editorconfig` with .NET and C# code style rules |

After bootstrapping, edit:

- `codeql.yml`: the language matrix.
- `dependabot.yml`: uncomment the package ecosystem block.
- `labels.yaml`: add project-specific labels.
- `rulesets/staging.json`: the required status check names must match your CI job names.

## Publishing guides

- [GitHub setup for releases](docs/github-release-setup.md): `staging`, the release-bot app, the
  `release` environment, and rulesets.
- [Publishing an npm package](docs/npm-publishing.md): npmjs.com account, first version, and trusted
  publisher.
- [Publishing API docs to GitHub Pages](docs/github-pages.md): TypeDoc, the Pages source, and the
  `github-pages` environment.
- [Publishing a VS Code extension](docs/vscode-extension-publishing.md): Marketplace publisher and
  Trusted Publishing policy, Open VSX namespace and trusted publisher.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/gh_auth.sh` | Log in with `gh`, make git use it for credentials, and export `GITHUB_TOKEN` (source it) |
| `scripts/install_pre_commit.sh` | Install pre-commit and the repo's hooks |
| `scripts/apply_rulesets.sh` | Create or update branch rulesets from JSON; `-a <app-id>` lets a release-bot app bypass `main` |
| `scripts/setup_npm_publish.sh` | Publish a placeholder npm package (public and deprecated, or private with `-p`) and register its trusted publisher with `npm trust`; prints the npmjs.com steps |
| `scripts/setup_github_pages.sh` | Turn on Pages with GitHub Actions as the source, let `main` deploy to the `github-pages` environment, and set the repository website |
| `scripts/setup_vscode_extension_publish.sh` | Create the Open VSX namespace and publish a placeholder version; prints the Marketplace and Open VSX trusted publishing steps with your values |

## Sources

These were made generic from awalsh128/ts-apt (release flow, npm publishing, API docs on Pages, PR and Dependabot
config, CI actions), awalsh128/vscode-keep-sorted and awalsh128/vscode-regex-explain (extension
publishing, labels, issue forms, triage), awalsh128/fluentcpp (C++
formatting and linting) and awalsh128/PcapngFile (.NET `.editorconfig`). Actions are pinned to
commit SHAs.

Workflows use published actions where a maintained one exists, so templates carry little
hand-written script. The remaining shell steps (issue triage, `require-ci-success`, promote) are
short `gh` and `git` calls with no good published equivalent.
