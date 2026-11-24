<p align="center">
  <img src="docs/assets/logo.svg" alt="gh-dev-powerpack logo" width="128" height="128">
</p>

# GitHub Dev Powerpack

Powerpack for developing code and managing CI/CD (GitHub currently). This repo has generic helper code and
templates to quickly bootstrap new projects and to raise the quality of existing ones.

- 🚀 **Bootstrap**: one command copies composable template sets into a new or existing repo.
- 🧰 **Repo hygiene**: issue forms, PR template, labels, triage, CodeQL and Dependabot for pinned actions.
- ✍️ **Conventional commits**: commitlint, a husky hook and PR checks for commits and titles.
- 📦 **Release flow**: `staging` to `main` promotion with rulesets, plus semantic-release for npm and VS Code
  extensions.
- 📚 **API docs**: TypeDoc built and deployed to GitHub Pages on official releases.
- 🧹 **Language tooling**: C++, .NET, Node and Rust formatting, linting and CI.
- 🤖 **Agentic config**: one source of coding-agent config for Claude Code, Codex, Copilot, Gemini and
  Antigravity.
- 🔒 **Safer installs**: `safe_fetch_exec.sh` checks a SHA-256 before running a downloaded script.

## Bootstrap a repo

```bash
./bootstrap.sh -n ~/repos/my-project common conventional-commits   # dry run
./bootstrap.sh    ~/repos/my-project common conventional-commits
```

Or install it as a `gh` extension and run it from anywhere:

```bash
gh extension install awalsh128/gh-dev-powerpack
gh dev-powerpack ~/repos/my-project common conventional-commits
gh extension upgrade dev-powerpack   # later, to get new templates
```

Files that already exist in the target are skipped unless you pass `-f`. When two sets have the same file, the
set listed first wins, so put language sets before `common` (for example `dotnet common` to get the .NET
`.editorconfig`).

Placeholders `__OWNER__`, `__REPO__` and `__MAINTAINER__` are filled from the target's `origin` remote.
Override them with `OWNER=`, `REPO=` and `MAINTAINER=`.

## Template sets

Sets live in `templates/<category>/<set>`; pass just the set name to `bootstrap.sh`.

<!-- prettier-ignore-start -->
<!-- sets:start -->

### `core`

| Set | What it adds |
| --- | --- |
| `common` | `.editorconfig`, `SECURITY.md`, issue forms (bug, feature, contact links), PR template, Dependabot for pinned actions, `labels.yaml` with a Sync Labels workflow (crazy-max/ghaction-github-labeler; dry run on PRs, never deletes), Issue Triage workflow (assign maintainer, label untemplated issues), CodeQL workflow, `require-ci-success` composite action |
| `conventional-commits` | `commitlint.config.mjs`, husky `commit-msg` hook, Commit Lint workflow that checks the PR title, which squash merges use as the commit (amannn/action-semantic-pull-request) |

### `release`

| Set | What it adds |
| --- | --- |
| `release-flow` | `promote.yml` that fast-forwards `main` to `staging` after CI passes and starts `publish.yml`, a `pr.yml` that requires `staging` as the base branch and runs dependency review, plus rulesets for `main`, `staging` and release tags; the `staging` ruleset requires the checks `test` (from the `node` set's `ci.yml`), `Check branch`, `Dependency review` and `pr-title`, so supply a `ci.yml` with a `test` job if you don't use `node`; needs `common`, `conventional-commits`, `npm-publish` |
| `npm-publish` | `publish.yml`, `nightly.yml`, `release-preview.yml` and `release.config.cjs`: semantic-release cuts `-rc` candidates on `staging` (nightly, when it has shippable changes) and publishes official releases from `main` to npm with trusted publishing, and comments on each pull request with the release it would cut (cycjimmy/semantic-release-action, marocchino/sticky-pull-request-comment); needs `node`, `release-flow` |
| `npm-pages` | `typedoc.json`: the `npm-publish` release builds TypeDoc API docs and deploys them to GitHub Pages on official releases; needs `npm-publish` |
| `vscode-extension` | `publish-extension.yml`, `release.config.cjs` and `scripts/vscode-release/release-version.mts`: semantic-release with VS Code's even/odd pre-release versions, publishing to the Marketplace and Open VSX with trusted publishing, and a `vsce-demos` skill for recording demo videos (add `agentic` for its symlinks); needs `node` |

### `languages`

| Set | What it adds |
| --- | --- |
| `node` | Dev container for Node 24, a Codecov config, a `setup` composite action (Node 24, `npm ci`, optional `--ignore-scripts`), a `ci.yml` (npm audit by risk, format check, build, typecheck, test, pack), and a slim Prettier setup (`.prettierrc.json` at 110 columns, `.prettierignore`, format-on-save `.vscode` settings and extension recommendations, a `.lintstagedrc.json` and `.husky/pre-commit` that format staged files; add `prettier`, `husky`, `lint-staged` and `build`, `typecheck`, `format` and `format:check` scripts to `package.json` yourself) |
| `cpp` | `.clang-format`, `.clang-tidy`, pre-commit config, and a format check workflow (jidicula/clang-format-action, clang-format 22) that fails on unformatted files |
| `dotnet` | Full `.editorconfig` with .NET and C# code style rules |
| `rust` | `rustfmt.toml` and a Rust workflow with `fmt`, `clippy` and `test` jobs (stable toolchain from the runner's rustup, warnings denied, `--locked`). Needs a committed `Cargo.lock` |

### `agentic-config`

| Set | What it adds |
| --- | --- |
| `agentic` | Coding-agent config for Claude Code, Codex, Copilot, Gemini and Antigravity from one source: a short `AGENTS.md` skeleton, five read-only subagent roles generated with rulesync, `delegate` and `progress-notes` skills shared through symlinks, and an Agent Config check workflow. See [Agentic Configuration](docs/agentic-config.md) |
| `agentic-powerpack` | Optional, off by default: a `powerpack-sync` skill that compares the repo with this one's current patterns and proposes updates, with per-set and per-path controls in `.agents/powerpack.json`, and a `dev-powerpack-exemplars` skill that adds one tool or config to the repo by adapting this one's matching template; needs `agentic` |

<!-- sets:end -->
<!-- prettier-ignore-end -->

_These tables are generated from [`templates/sets.json`](templates/sets.json); edit it and run
`scripts/check-docs.sh --fix`._

After bootstrapping, edit:

- `codeql.yml`: the language matrix (for Rust, add `language: rust` with `build-mode: none`).
- `dependabot.yml`: uncomment the package ecosystem block (`cargo` for Rust).
- `labels.yaml`: add project-specific labels.
- `rulesets/staging.json`: the required status check names (`test`, `Check branch`, `Dependency review`,
  `pr-title`) must match your CI job names. They match the `node` set's `ci.yml` and the `release-flow` and
  `conventional-commits` workflows.
- `AGENTS.md`: replace the `TODO`s with the repo's commands, conventions and warnings.

## Publishing guides

- [GitHub setup for releases](docs/github-release-setup.md): `staging`, the Octo STS app, the `release`
  environment, and rulesets.
- [Publishing an npm package](docs/npm-publishing.md): npmjs.com account, first version, and trusted
  publisher.
- [Publishing API docs to GitHub Pages](docs/github-pages.md): TypeDoc, the Pages source, and the
  `github-pages` environment.
- [Publishing a VS Code extension](docs/vscode-extension-publishing.md): Marketplace publisher and Trusted
  Publishing policy, Open VSX namespace and trusted publisher.

## Scripts

| Script                                      | Purpose                                                                                                                                                                                                                                                          |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/gh_auth.sh`                        | Log in with `gh`, make git use it for credentials, and export `GITHUB_TOKEN` (source it)                                                                                                                                                                         |
| `scripts/install_pre_commit.sh`             | Install pre-commit and the repo's hooks                                                                                                                                                                                                                          |
| `scripts/apply_rulesets.sh`                 | Create or update rulesets from JSON; `-a <app-id>` lets the Octo STS app bypass `main` and `tags`                                                                                                                                                                |
| `scripts/setup_github_release.sh`           | Create the `release` environment (main and staging only), turn on immutable releases, check the Octo STS trust policies are on the default branch, and apply the rulesets with the Octo STS app allowed to bypass `main` and `tags`; prints the app install step |
| `scripts/agentic-eval/`                     | Replays past fixes with and without the `agentic` set in Claude Code headless, and scores them against the fixes' own tests. See its [README](scripts/agentic-eval/README.md)                                                                                    |
| `scripts/drift-check.sh`                    | Print drift findings for the repo in the current directory as JSON (unpinned `uses:` so far); set it as `DRIFT_CHECK_CMD` for the cross-repo-drift skill                                                                                                         |
| `scripts/drift-fix.sh`                      | Fix one drift rule (`DRIFT_RULE=unpinned-uses`) in the repo in the current directory by pinning each `uses:` to its commit SHA; set it as `DRIFT_FIX_CMD` for the cross-repo-drift skill                                                                         |
| `scripts/setup_npm_publish.sh`              | Publish a placeholder npm package (public and deprecated, or private with `-p`) and register its trusted publisher with `npm trust`; prints the npmjs.com steps                                                                                                  |
| `scripts/setup_github_pages.sh`             | Turn on Pages with GitHub Actions as the source, let `main` deploy to the `github-pages` environment, and set the repository website                                                                                                                             |
| `scripts/setup_vscode_extension_publish.sh` | Create the Open VSX namespace and publish a placeholder version; prints the Marketplace and Open VSX trusted publishing steps with your values                                                                                                                   |
| `scripts/check-docs.sh`                     | Check that the README, docs, scripts and templates agree (set list, `needs`, links, script mentions); `--fix` regenerates the README set tables from `templates/sets.json`                                                                                       |
| `scripts/safe_fetch_exec.sh`                | Safer replacement for `curl \| bash`: download over HTTPS, check the SHA-256 the publisher lists, then run (`--dry-run` to read it first). Cite the published hash in a repo's install docs; see [Installing from a script](docs/safe-install.md)                |

## Sources

These were made generic from the author's own projects (release flow, npm publishing, API docs on Pages, PR
and Dependabot config, CI actions), awalsh128/vscode-keep-sorted and awalsh128/vscode-regex-explain (extension
publishing, labels, issue forms, triage), awalsh128/fluentcpp (C++ formatting and linting) and
awalsh128/PcapngFile (.NET `.editorconfig`). Actions are pinned to commit SHAs.

Workflows use published actions where a maintained one exists, so templates carry little hand-written script.
The remaining shell steps (issue triage, `require-ci-success`, promote) are short `gh` and `git` calls with no
good published equivalent.
