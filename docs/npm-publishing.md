# Publishing an npm Package

The `npm-publish` set releases an npm package with [semantic-release](https://semantic-release.gitbook.io/)
and publishes it with [npm trusted publishing](https://docs.npmjs.com/trusted-publishers), so the repository
stores no npm token. Versions come from [Conventional Commits](https://www.conventionalcommits.org/):

| Branch    | Releases           | Example      | Started by                                   | npm                        |
| --------- | ------------------ | ------------ | -------------------------------------------- | -------------------------- |
| `staging` | Release candidates | `1.2.0-rc.1` | The last CI job on a `staging` push          | Not published              |
| `main`    | Official releases  | `1.2.0`      | `promote.yml`, after it fast-forwards `main` | Published, with provenance |

Releases create a `vX.Y.Z` tag and a GitHub release, and never commit: `package.json` keeps a placeholder
version and semantic-release writes the real one in the CI workspace.

## Bootstrap

```bash
./bootstrap.sh ~/repos/my-package common conventional-commits release-flow node npm-publish
```

This adds `.github/workflows/publish.yml`, `.github/workflows/release-preview.yml`, `release.config.cjs`, the
`setup` and `require-ci-success` actions, and `promote.yml`. Then complete
[GitHub Setup for Releases](github-release-setup.md).

## Package

In `package.json`:

- `version`: a placeholder such as `0.0.0`.
- `repository.url`: must exactly match the GitHub repository, such as `git+https://github.com/owner/repo.git`,
  or npm rejects the provenance. In a monorepo, also set `repository.directory`.
- `publishConfig`: `{ "access": "public" }` for a scoped package such as `@owner/name`.
- `files`: what ships, such as `["dist"]`.
- `scripts.prepack`: the build. The release job installs with `--ignore-scripts`, and `npm publish` runs
  `prepack`.

In a monorepo, move `release.config.cjs` into the package's directory, give `tagFormat` a package prefix (such
as `my-lib-v${version}`), and set `PACKAGE_DIR` in `publish.yml`. Only commits that change that directory then
count, through [semantic-release-monorepo](https://github.com/pmowrer/semantic-release-monorepo).

For API docs on GitHub Pages, add the `npm-pages` set; see [github-pages.md](github-pages.md).

## npmjs.com

### Account

1. Sign up at <https://www.npmjs.com/signup> and verify your email address.
2. Under your avatar, open **Account** and turn on two-factor authentication.
3. For a package under an organization scope, create the organization with **Add Organization** (free for
   public packages). Your username is already a scope.

### Setup Script

`scripts/setup_npm_publish.sh` does the rest of the npmjs.com setup from the command line, and prints the
steps only the website can do. Run it from a clone of the repository after you have an account; add `-n` for a
dry run:

```bash
~/repos/gh-dev-powerpack/scripts/setup_npm_publish.sh path/to/package
```

It:

1. Checks `repository.url` and, for a scoped package, `publishConfig.access`.
2. Runs `npm login` if needed.
3. Publishes a placeholder version `0.0.0` (a `package.json` and README only) when the package doesn't exist,
   because npm only configures trusted publishing on an existing package. It is public and deprecated by
   default. With `-p`, it is private (`--access restricted`), which needs a scoped name and a paid npm plan;
   make the package public before the first release with `npm access set status=public <name>`.
4. Registers the trusted publisher with `npm trust github`, for `publish.yml` and the `release` environment
   (change them with `-w` and `-e`). npm asks for two-factor authentication.

semantic-release's first release is then `1.0.0`. To do the same by hand, publish the placeholder and fill in
the form below.

### Trusted Publisher by Hand

1. Open `https://www.npmjs.com/package/<name>/access`, or the package page's **Settings** tab.
2. In **Trusted Publisher**, under **Select your publisher**, choose **GitHub Actions**.
3. Fill in:

   | Field                | Value                              |
   | -------------------- | ---------------------------------- |
   | Organization or user | The repository owner               |
   | Repository           | The repository name                |
   | Workflow filename    | `publish.yml` (the file name only) |
   | Environment name     | `release`                          |
   | Allowed actions      | Allow `npm publish`                |

4. Save. npm does not check the values when you save them, and the configuration expires unless it publishes
   successfully within 2 days, so release soon after (see [Verify](#verify)).
5. Once a release has published, go to **Publishing access**, select **Require two-factor authentication and
   disallow tokens**, select **Update Package Settings**, and revoke any old automation tokens. Trusted
   publishing keeps working because it uses no token.

npm generates provenance automatically when a public package is published from a public repository.

## Release Candidates

Add a last job to `ci.yml` that starts a release candidate after every other job passes on `staging`. It
starts `publish.yml` on its own instead of calling it, because npm trusts `publish.yml` only when it is the
top-level workflow:

```yaml
release-candidate:
  if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/staging' }}
  needs: [lint, test] # every other CI job
  runs-on: ubuntu-latest
  timeout-minutes: 5
  permissions:
    actions: write # Start the publish workflow
  steps:
    - name: Start release candidate
      env:
        GH_TOKEN: ${{ github.token }}
      run: gh workflow run publish.yml --ref staging
```

Never call `publish.yml` with `uses:` from another workflow: a called workflow isn't the top-level one, so npm
trusted publishing and the Octo STS trust policy (which names the workflow file) wouldn't match it. Candidates
aren't published to npm anyway: `release.config.cjs` only publishes on `main`.

## Release Preview

`release-preview.yml` comments on each pull request to `staging` with the release candidate that merging it
would cut: the version and its release notes, or a note that it releases nothing. It squash-merges the pull
request into `staging` locally with its title as the commit subject, runs semantic-release in dry-run mode
through [cycjimmy/semantic-release-action](https://github.com/cycjimmy/semantic-release-action), and keeps one
comment up to date with
[marocchino/sticky-pull-request-comment](https://github.com/marocchino/sticky-pull-request-comment).

- It sets `RELEASE_PREVIEW=true`, so `release.config.cjs` keeps only the commit analyzer and release notes
  generator: a dry run still verifies every plugin, and the npm and GitHub release plugins can't pass on a
  pull request.
- It runs on `pull_request_target`, so the workflow and `release.config.cjs` come from `staging`. The pull
  request's commits are only read as history; its files are reset to `staging`'s before semantic-release runs,
  so none of its code or config runs. Keep it that way: never build, install or run the pull request's files
  in this workflow.
- Its job token has `contents: write`, because semantic-release checks that it could push even in a dry run.
  Nothing is pushed, and the rulesets still protect `staging`, `main` and the release tags.
- Pull requests from forks get a preview too. Dependabot's get a read-only token, so the preview skips them.
- A change to `release-preview.yml` or `release.config.cjs` shows up in previews once it is on `staging`.
- Keep its `PACKAGE_DIR` and pinned versions in step with `publish.yml`.

## Verify

1. Preview the next version without tagging:

   ```bash
   gh workflow run publish.yml --ref staging -f dry-run=true
   ```

2. Merge a `feat:` or `fix:` pull request into `staging`; CI releases `1.0.0-rc.1`.
3. Run **Promote staging to main**. It fast-forwards `main` and starts `publish.yml`, which tags `v1.0.0` and
   publishes it to npm.

## README Badges

Once the first real version is published, add the npm version badge to the README badge row. If `ci.yml`
uploads coverage with `codecov/codecov-action` (the `node` set ships the matching `.codecov.yml`), add the
Codecov badge too:

```markdown
[![npm version](https://img.shields.io/npm/v/<package>)](https://www.npmjs.com/package/<package>)
[![codecov](https://codecov.io/gh/<owner>/<repo>/branch/main/graph/badge.svg)](https://codecov.io/gh/<owner>/<repo>)
```

The Codecov badge shows "unknown" until the repository is authorized on [Codecov](https://app.codecov.io) and
has a first upload. The `create-readme` skill applies the same rule.

## Troubleshooting

- **`E404` or `ENEEDAUTH` on publish:** a trusted publisher field doesn't match. Check the owner, repository,
  workflow file name and environment exactly; delete and recreate the publisher if it expired.
- **Provenance error about the repository:** `repository.url` in `package.json` doesn't match the GitHub
  repository.
- **`Cannot create ref due to creations being restricted`:** the tag was pushed with `GITHUB_TOKEN`, or the
  Octo STS app isn't installed on the repository.
