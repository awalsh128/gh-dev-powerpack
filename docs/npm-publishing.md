# Publishing an npm Package

The `npm-publish` set releases an npm package with
[semantic-release](https://semantic-release.gitbook.io/) and publishes it with
[npm trusted publishing](https://docs.npmjs.com/trusted-publishers), so the repository stores no npm
token. Versions come from [Conventional Commits](https://www.conventionalcommits.org/):

| Branch    | Releases           | Example      | Started by                                   | npm                        |
| --------- | ------------------ | ------------ | -------------------------------------------- | -------------------------- |
| `staging` | Release candidates | `1.2.0-rc.1` | The last CI job on a `staging` push          | Not published              |
| `main`    | Official releases  | `1.2.0`      | `promote.yml`, after it fast-forwards `main` | Published, with provenance |

Releases create a `vX.Y.Z` tag and a GitHub release, and never commit: `package.json` keeps a
placeholder version and semantic-release writes the real one in the CI workspace.

## Bootstrap

```bash
./bootstrap.sh ~/repos/my-package common conventional-commits release-flow node npm-publish
```

This adds `.github/workflows/release.yml`, `release.config.cjs`, the `setup` and
`require-ci-success` actions, and `promote.yml`. Then complete
[GitHub Setup for Releases](github-release-setup.md).

## Package

In `package.json`:

- `version`: a placeholder such as `0.0.0`.
- `repository.url`: must exactly match the GitHub repository, such as
  `git+https://github.com/owner/repo.git`, or npm rejects the provenance. In a monorepo, also set
  `repository.directory`.
- `publishConfig`: `{ "access": "public" }` for a scoped package such as `@owner/name`.
- `files`: what ships, such as `["dist"]`.
- `scripts.prepack`: the build. The release job installs with `--ignore-scripts`, and `npm publish`
  runs `prepack`.

In a monorepo, move `release.config.cjs` into the package's directory, give `tagFormat` a package
prefix (such as `my-lib-v${version}`), and set `PACKAGE_DIR` in `release.yml`. Only commits that
change that directory then count, through
[semantic-release-monorepo](https://github.com/pmowrer/semantic-release-monorepo).

For API docs on GitHub Pages, add the `npm-pages` set; see [github-pages.md](github-pages.md).

## npmjs.com

### Account

1. Sign up at <https://www.npmjs.com/signup> and verify your email address.
2. Under your avatar, open **Account** and turn on two-factor authentication.
3. For a package under an organization scope, create the organization with **Add Organization**
   (free for public packages). Your username is already a scope.

### Setup Script

`scripts/setup_npm_publish.sh` does the rest of the npmjs.com setup from the command line, and
prints the steps only the website can do. Run it from a clone of the repository after you have an
account; add `-n` for a dry run:

```bash
~/repos/gh-dev-powerpack/scripts/setup_npm_publish.sh path/to/package
```

It:

1. Checks `repository.url` and, for a scoped package, `publishConfig.access`.
2. Runs `npm login` if needed.
3. Publishes a placeholder version `0.0.0` (a `package.json` and README only) when the package
   doesn't exist, because npm only configures trusted publishing on an existing package. It is
   public and deprecated by default. With `-p`, it is private (`--access restricted`), which needs a
   scoped name and a paid npm plan; make the package public before the first release with
   `npm access set status=public <name>`.
4. Registers the trusted publisher with `npm trust github`, for `release.yml` and the `release`
   environment (change them with `-w` and `-e`). npm asks for two-factor authentication.

semantic-release's first release is then `1.0.0`. To do the same by hand, publish the placeholder
and fill in the form below.

### Trusted Publisher by Hand

1. Open `https://www.npmjs.com/package/<name>/access`, or the package page's **Settings** tab.
2. In **Trusted Publisher**, under **Select your publisher**, choose **GitHub Actions**.
3. Fill in:

   | Field                | Value                              |
   | -------------------- | ---------------------------------- |
   | Organization or user | The repository owner               |
   | Repository           | The repository name                |
   | Workflow filename    | `release.yml` (the file name only) |
   | Environment name     | `release`                          |
   | Allowed actions      | Allow `npm publish`                |

4. Save. npm does not check the values when you save them, and the configuration expires unless it
   publishes successfully within 2 days, so release soon after (see [Verify](#verify)).
5. Once a release has published, go to **Publishing access**, select **Require two-factor
   authentication and disallow tokens**, select **Update Package Settings**, and revoke any old
   automation tokens. Trusted publishing keeps working because it uses no token.

npm generates provenance automatically when a public package is published from a public repository.

## Release Candidates

Add a last job to `ci.yml` that releases a candidate after every other job passes on `staging`:

```yaml
release-candidate:
  if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/staging' }}
  needs: [lint, test] # every other CI job
  permissions:
    actions: read
    contents: write
    issues: write
    pull-requests: write
    id-token: write
    pages: write
  uses: ./.github/workflows/release.yml
```

The caller must grant every permission `release.yml` asks for, including `pages: write` for the
API docs job ([github-pages.md](github-pages.md)), even though candidates never deploy.

npm trusts `release.yml` only when it is the top-level workflow, which a call from `ci.yml` is not,
and `release.config.cjs` only publishes on `main` anyway.

## Verify

1. Preview the next version without tagging:

   ```bash
   gh workflow run release.yml --ref staging -f dry-run=true
   ```

2. Merge a `feat:` or `fix:` pull request into `staging`; CI releases `1.0.0-rc.1`.
3. Run **Promote staging to main**. It fast-forwards `main` and starts `release.yml`, which tags
   `v1.0.0` and publishes it to npm.

## Troubleshooting

- **`E404` or `ENEEDAUTH` on publish:** a trusted publisher field doesn't match. Check the owner,
  repository, workflow file name and environment exactly; delete and recreate the publisher if it
  expired.
- **Provenance error about the repository:** `repository.url` in `package.json` doesn't match the
  GitHub repository.
- **`Cannot create ref due to creations being restricted`:** the tag was pushed with `GITHUB_TOKEN`,
  or the release-bot app isn't installed on the repository.
