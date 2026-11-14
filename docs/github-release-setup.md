# GitHub Setup for Releases

The `release-flow`, `npm-publish` and `vscode-extension` sets share one GitHub setup: a release-bot
app that can push to `main` and push tags, a `release` environment that publishing is bound to, and
branch rulesets. Do this once per repository.

## Branches

Create `staging` from `main` and make it the default branch, so pull requests target it:

```bash
git push origin main:staging
gh repo edit --default-branch staging
```

`main` only ever fast-forwards to a commit already on `staging` (`promote.yml`), and releases never
commit, so `main` stays an ancestor of `staging`.

## Release-bot GitHub App

The default `GITHUB_TOKEN` can't bypass the `main` ruleset or create tags that a ruleset restricts,
so the workflows use a GitHub App token.

1. Open **Settings → Developer settings → GitHub Apps → New GitHub App** for your account
   (<https://github.com/settings/apps/new>), or the organization's equivalent.
2. Enter a **GitHub App name** (such as `my-name-release-bot`) and a **Homepage URL** (the
   repository URL is fine).
3. Under **Webhook**, clear **Active**.
4. Under **Repository permissions**, set **Contents** to **Read and write**. Leave everything else
   at **No access**.
5. Under **Where can this GitHub App be installed?**, choose **Only on this account**, then **Create
   GitHub App**.
6. Note the **App ID** on the app's page. Under **Private keys**, select **Generate a private key**;
   a `.pem` file downloads.
7. Select **Install App**, choose the account, then **Only select repositories** and pick the
   repository.

Store the credentials on the repository (the workflows read `vars.RELEASE_BOT_APP_ID` and
`secrets.RELEASE_BOT_PK`):

```bash
gh variable set RELEASE_BOT_APP_ID --body "<app id>"
gh secret set RELEASE_BOT_PK < my-release-bot.private-key.pem
```

Delete the `.pem` file afterwards.

## Release Environment

The npm, Marketplace and Open VSX trusted publishers are bound to the `release` environment, so only
`main` and `staging` can publish.

1. Open the repository's **Settings → Environments → New environment**, name it `release`, and
   select **Configure environment**.
2. Under **Deployment branches and tags**, choose **Selected branches and tags** and add the rules
   `main` and `staging`.

Environment jobs still see the repository variable and secret above. For tighter scoping, move them
into the `release` environment and add a `promote` environment for `promote.yml`.

## Rulesets

`release-flow` adds `.github/rulesets/main.json` and `staging.json`. Edit the required status check
names in `staging.json` to match your CI job names, then apply them with the app allowed to bypass
`main`:

```bash
scripts/apply_rulesets.sh -a "<app id>"
```

## CI

`ci.yml` must run on pushes to `staging` and `main`, and on pull requests. To cut npm release
candidates, add a last job that calls `release.yml` on `staging` pushes; see
[npm-publishing.md](npm-publishing.md#release-candidates).
