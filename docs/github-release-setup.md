# GitHub Setup for Releases

The `release-flow`, `npm-publish` and `vscode-extension` sets share one GitHub setup: Octo STS tokens that can
push to `main` and push tags, a `release` environment that publishing is bound to, and branch rulesets. Do
this once per repository.

`scripts/setup_github_release.sh` does the environment, trust policy check and rulesets below from the command
line (add `-n` for a dry run); you still install the Octo STS app yourself.

## Branches

Create `staging` from `main` and make it the default branch, so pull requests target it:

```bash
git push origin main:staging
gh repo edit --default-branch staging
```

`main` only ever fast-forwards to a commit already on `staging` (`promote.yml`), and releases never commit, so
`main` stays an ancestor of `staging`.

## Octo STS

The default `GITHUB_TOKEN` can't bypass the `main` ruleset or create tags that a ruleset restricts. Instead of
a GitHub App of your own, with a private key stored as a secret, the workflows use
[Octo STS](https://github.com/octo-sts/app): a GitHub App that exchanges a workflow's OIDC token for a
short-lived installation token, as a trust policy in your repository allows. No key or token is stored.

1. Install the [Octo STS app](https://github.com/apps/octo-sts) on the repository (**Only select
   repositories**).
2. Bootstrap adds the trust policies, with your owner, repository and their numeric IDs filled in (looked up
   with `gh api`; pass `OWNER_ID=` and `REPO_ID=` if it can't), to the default branch (Octo STS reads them
   from there). The IDs mean a repository that later takes the same name doesn't match:
   - `.github/chainguard/promote.sts.yaml` (`release-flow`): `promote.yml` on `staging` may get a token with
     `contents: write` to push `main`.
   - `.github/chainguard/release.sts.yaml` (`npm-publish`, `vscode-extension`): the release workflow, in the
     `release` environment on `main` or `staging`, may get a token with `contents: write` to push tags.
3. Allow the app to bypass the `main` and `tags` rulesets (see [Rulesets](#rulesets)). Its app ID is public:
   `gh api /apps/octo-sts --jq .id` (801323).

## Release Environment

The npm, Marketplace and Open VSX trusted publishers are bound to the `release` environment, so only `main`
and `staging` can publish.

1. Open the repository's **Settings → Environments → New environment**, name it `release`, and select
   **Configure environment**.
2. Under **Deployment branches and tags**, choose **Selected branches and tags** and add the rules `main` and
   `staging`.

## Immutable Releases

Turn on immutable releases so a published release's tag and assets can't be changed or deleted, and GitHub
attaches a signed attestation to it. `setup_github_release.sh` does this; by hand it is **Settings → General →
Releases → Enable release immutability**, or:

```bash
gh api -X PUT repos/OWNER/REPO/immutable-releases
```

It applies to releases published after it is on. `@semantic-release/github` uploads assets to a draft and
publishes it afterwards, so the workflows work unchanged; any step that edits assets or moves the tag after
publishing will fail. Release notes and the pre-release flag stay editable.

## Release Switch

`publish.yml` runs its job only when the repository variable `RELEASES_ENABLED` is not `false`, and a dry run
always runs. Every route to a release (a `staging` push, `promote.yml`, a manual run) goes through that job,
so one variable holds them all. Hold releases while a repository settles with
`gh variable set RELEASES_ENABLED --body false`, and release again with `--body true` (or delete the
variable). A release job that merely fails is not a hold: with no tags, every `staging` push plans
`1.0.0-rc.1`.

## Major Releases

`promote.yml` takes an optional `confirm-major` input. When the latest candidate on `staging` starts a new
major version, or is the first official release, the run stops unless `confirm-major` is that version (for
example `2.0.0`). There is no maintenance branch, so a major leaves users of the previous one without fixes.
It reads the `vX.Y.Z` and `vX.Y.Z-rc.N` tags, so it assumes the default tag format.

## Repository Settings

For a public repository, also:

- Add a `SECURITY.md` (the `common` set has one) and turn on private vulnerability reporting, which
  `setup_github_release.sh` does: `gh api -X PUT repos/OWNER/REPO/private-vulnerability-reporting`.
- Turn on **Require actions to be pinned to a full-length commit SHA** (Settings → Actions → General), or
  `gh api -X PUT repos/OWNER/REPO/actions/permissions -F enabled=true -f allowed_actions=all -F sha_pinning_required=true`.
  Do it after every workflow pins its actions, or the unpinned ones stop running.
- Merging a changed `.github/rulesets/*.json` applies nothing; apply it, then compare the live ruleset with
  the file.

## Rulesets

`release-flow` adds `.github/rulesets/main.json`, `staging.json` and `tags.json`. `tags.json` stops anyone
creating, moving or deleting a tag, so only the Octo STS app (the release workflow) can tag a release. Edit
the required status check names in `staging.json` to match your CI job names, then apply them with the Octo
STS app allowed to bypass `main` and `tags`:

```bash
scripts/apply_rulesets.sh -a "$(gh api /apps/octo-sts --jq .id)"
```

## CI

`ci.yml` must run on pushes to `staging` and `main`, and on pull requests. To cut npm release candidates, add
a last job that starts `publish.yml` on `staging` pushes; see
[npm-publishing.md](npm-publishing.md#release-candidates).
