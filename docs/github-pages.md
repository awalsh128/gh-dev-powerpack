# Publishing API Docs to GitHub Pages

The `npm-pages` set adds API docs, generated with [TypeDoc](https://typedoc.org/), to an npm
package released by the `npm-publish` set. Each official release deploys the docs for that version
to GitHub Pages:

| Branch    | Docs                                                                  |
| --------- | --------------------------------------------------------------------- |
| `staging` | Built during the release, so a broken docs build stops the candidate |
| `main`    | Built, then deployed to `https://<owner>.github.io/<repo>/`           |

The docs show the released version, and their source links point at the release tag.

## Bootstrap

```bash
./bootstrap.sh ~/repos/my-package common conventional-commits release-flow node npm-publish npm-pages
```

`npm-pages` only adds `typedoc.json`. The `npm-publish` set's `release.config.cjs` builds the docs
when it finds `typedoc.json` next to it, and `release.yml` deploys them; without `typedoc.json`
neither does anything. Finish [Publishing an npm Package](npm-publishing.md) first.

## Package

1. Add TypeDoc and a script to run it locally:

   ```bash
   npm install --save-dev typedoc
   npm pkg set scripts.docs=typedoc
   ```

2. In `typedoc.json`, set `entryPoints` to the modules that make up the public API, such as
   `src/index.ts`, and `tsconfig` to the project's TypeScript config.
3. Add `docs/api/` to `.gitignore`. The release writes the docs there (`DOCS_DIR` in
   `release.config.cjs`), and `npm run docs` does the same locally.
4. Check the output with `npm run docs` and open `docs/api/index.html`.

The release job installs with `--ignore-scripts`, so TypeDoc must work from source, without a build
step.

## GitHub

`scripts/setup_github_pages.sh` does the GitHub setup; add `-n` for a dry run:

```bash
~/repos/gh-dev-powerpack/scripts/setup_github_pages.sh path/to/repo
```

It:

1. Turns on Pages with **GitHub Actions** as the source.
2. Limits the `github-pages` environment to `main`. GitHub only allows the default branch, which the
   release flow makes `staging`, so deployments from `main` would otherwise be rejected.
3. Sets the repository's website to the Pages URL.

### By Hand

1. Open **Settings → Pages**. Under **Build and deployment → Source**, choose **GitHub Actions**.
2. Open **Settings → Environments → github-pages**. Under **Deployment branches and tags**, remove
   the `staging` rule and add `main`.
3. Optionally, on the repository page, select the gear next to **About** and set **Website** to the
   Pages URL.

## Release Candidates

If `ci.yml` calls `release.yml` for release candidates, the calling job must grant every permission
`release.yml` asks for, including the Pages ones, even though candidates never deploy:

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

## Verify

1. Merge a `feat:` or `fix:` pull request into `staging`. The candidate release log shows TypeDoc
   running in the `prepare` step.
2. Run **Promote staging to main**. The release run has a **deploy-pages** job, and the deployment
   appears under the repository's **Environments → github-pages**.

## Troubleshooting

- **`Branch "main" is not allowed to deploy to github-pages`:** the environment still only allows
  `staging`; see [GitHub](#github).
- **`Get Pages site failed` in Setup Pages:** Pages isn't turned on, or its source isn't GitHub
  Actions.
- **`could not determine executable to run` for typedoc:** `typedoc` isn't in `devDependencies`.
- **Workflow validation error about requested permissions:** the `ci.yml` job that calls
  `release.yml` doesn't grant `pages: write` and `id-token: write`.
