# Publishing a VS Code Extension

The `vscode-extension` set releases a VS Code extension with
[semantic-release](https://semantic-release.gitbook.io/) and publishes it to the
[Visual Studio Marketplace](https://marketplace.visualstudio.com/vscode) and
[Open VSX](https://open-vsx.org/) with trusted publishing, so the repository stores no registry
token.

Versions follow VS Code's
[pre-release convention](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#pre-release-extensions):
releases use even minor versions and pre-releases odd ones.
`scripts/vscode-release/release-version.mts` picks the bump from
[Conventional Commits](https://www.conventionalcommits.org/):

| Last version | Run         | Commits             | Next version    |
| ------------ | ----------- | ------------------- | --------------- |
| 1.0.2        | pre-release | `fix` or `feat`     | 1.1.0           |
| 1.1.0        | pre-release | `fix` or `feat`     | 1.1.1           |
| 1.1.1        | release     | any, including none | 1.2.0 (promote) |
| 1.2.0        | release     | `fix`               | 1.2.1           |
| any          | release     | breaking            | next major      |

A release run refuses `feat` commits after a release, since it would have to skip an odd minor;
publish them as a pre-release first. Releases create a `vX.Y.Z` tag and a GitHub release with the
VSIX, and never commit.

## Bootstrap

```bash
./bootstrap.sh ~/repos/my-extension common conventional-commits release-flow node vscode-extension
```

This adds `.github/workflows/publish-extension.yml`, `release.config.cjs`,
`scripts/vscode-release/release-version.mts`, and the `setup` and `require-ci-success` actions. Then
complete [GitHub Setup for Releases](github-release-setup.md). `release-flow` is optional, but
without it, remove `staging` from the `release` environment's branches.

`promote.yml` starts `release.yml` (the `npm-publish` set). For an extension-only repository, change
its last step to start nothing, or to
`gh workflow run publish-extension.yml --ref main -f dry_run=false`.

## Extension

In `package.json`:

- `publisher`: your Marketplace publisher ID, which is also the Open VSX namespace. Open VSX matches
  it case-sensitively.
- `version`: a placeholder such as `0.0.0`.
- `engines.vscode`: `^1.63.0` or later, the first version with pre-release extensions.
- `repository`, `license`, and an `icon` (a 128×128 PNG or larger; SVG is not allowed).
- `scripts.vscode:prepublish`: the build. The release job installs with `--ignore-scripts`, and vsce
  runs `vscode:prepublish` when it packages.

In a monorepo, move `release.config.cjs` into the extension's directory, fix the plugin path in it,
and set `EXTENSION_DIR` in `publish-extension.yml`. Every commit counts toward the version, not only
those in that directory.

Check that it packages: `npx @vscode/vsce package`.

## Visual Studio Marketplace

### Publisher

1. Sign in at <https://marketplace.visualstudio.com/manage> with a Microsoft account.
2. Select **Create publisher** and fill in:
   - **ID**: the `publisher` in `package.json`. It appears in the extension's URL and can't be
     changed.
   - **Name**: the display name shown on the Marketplace.
3. Select **Create**.

### Trusted Publishing

1. On <https://marketplace.visualstudio.com/manage>, open the publisher and select **Trusted
   Publishing**.
2. Expand **Create** and fill in:

   | Field            | Value                                  |
   | ---------------- | -------------------------------------- |
   | Policy name      | Any label, such as `my-extension`      |
   | Repository owner | The GitHub owner                       |
   | Repository       | The repository name, without the owner |
   | Workflow         | `publish-extension.yml`                |
   | Environment      | `release`                              |

3. Select **Create**. For a private repository, run the workflow within 48 hours; the first
   successful exchange activates the policy.

The workflow publishes with `vsce publish --oidc`, which needs `id-token: write` and no personal
access token. Each OIDC token can be exchanged once, and the Marketplace credential lasts 15
minutes.

## Open VSX

Open VSX trusted publishing needs a namespace you own and an extension with at least one version, so
a placeholder version is published once with an access token.

`scripts/setup_vscode_extension_publish.sh` does the command-line steps and prints the website steps
with your values filled in, for both the Marketplace and Open VSX. Run it from a clone of the
repository; add `-n` for a dry run, and set `OVSX_PAT` to skip the token prompt:

```bash
~/repos/gh-dev-powerpack/scripts/setup_vscode_extension_publish.sh path/to/extension
```

It creates the namespace if it doesn't exist and publishes a placeholder version `0.0.0` (a
`package.json` and README, with "(placeholder)" in its display name) if the extension has no
version. Open VSX has no private extensions, so the placeholder is public; the first release
(`1.0.0`) replaces it as the latest version. The sections below are the same steps by hand.

### Account and Namespace

1. Create an Eclipse account at <https://accounts.eclipse.org/user/register>, and set its **GitHub
   Username** to the GitHub account you use on Open VSX.
2. On <https://open-vsx.org>, select the account icon and log in with GitHub.
3. Open <https://open-vsx.org/user-settings/profile>, select **Log in with Eclipse**, then **Show
   Publisher Agreement**, and **Agree**.
4. Open <https://open-vsx.org/user-settings/tokens>, select **Generate New Token**, and copy it; it
   is shown once.
5. Create the namespace, named exactly like `publisher`:

   ```bash
   npx ovsx create-namespace <publisher> -p <token>
   ```

6. Claim ownership of the namespace, which trusted publishing requires: open a public issue at
   <https://github.com/EclipseFdn/open-vsx.org/issues/new/choose> asking for ownership (see
   [Namespace Access](https://github.com/eclipse/openvsx/wiki/Namespace-Access)), and wait for it to
   be granted.

### Placeholder Version

Package a placeholder with the extension's `publisher` and `name`, version `0.0.0`, and a README,
then publish it:

```bash
npx @vscode/vsce package --skip-license --out placeholder.vsix
npx ovsx publish placeholder.vsix -p <token>
```

### Trusted Publisher

1. Open <https://open-vsx.org/user-settings/trusted-publishers> and select the namespace.
2. Choose **GitHub Actions** and fill in:

   | Field                     | Value                   |
   | ------------------------- | ----------------------- |
   | Organization or User name | The GitHub owner        |
   | Repository name           | The repository name     |
   | Workflow filename         | `publish-extension.yml` |
   | Environment name          | `release`               |

3. For a private repository, the dialog shows a registration code instead; it is shown once and
   expires after 7 days. Add it as an `OVSX_REGISTRATION_CODE` secret and pass it to the
   `ovsx publish` step's environment for the first publish.
4. Delete the access token at <https://open-vsx.org/user-settings/tokens>.

Registrations can't be edited; delete and recreate one to change it. The workflow publishes with
`ovsx publish --trusted-publishing`.

## Verify

1. Start a dry run on `main`, which prints the next version and release notes:

   ```bash
   gh workflow run publish-extension.yml --ref main
   ```

2. Publish a release, or a pre-release:

   ```bash
   gh workflow run publish-extension.yml --ref main -f dry_run=false
   gh workflow run publish-extension.yml --ref main -f dry_run=false -f pre_release=true
   ```

The workflow requires a successful CI run on the commit. After a partial failure, use **Re-run
failed jobs**: the commit already carries the tag, and `--skip-duplicate` skips the registry that
already has the version.

## Troubleshooting

- **Marketplace refuses the token:** a Trusted Publishing policy field doesn't match. The
  environment must be `release`, because the job runs in it.
- **Open VSX refuses trusted publishing:** check that you own the namespace, that the extension has
  a published version, and that `publisher` matches the namespace's case.
- **`Tag the last published version before publishing a pre-release`:** the first run must be a
  release, so pre-releases have a version to follow.
- **`Cannot create ref due to creations being restricted`:** the release-bot app isn't installed on
  the repository.
