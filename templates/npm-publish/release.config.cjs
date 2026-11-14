/**
 * semantic-release configuration for the npm package, run by .github/workflows/release.yml. See
 * docs/npm-publishing.md in gh-dev-powerpack.
 *
 * Releases never commit: main only fast-forwards to staging (promote.yml), so the committed
 * package.json keeps a placeholder version and semantic-release writes the real one in the CI
 * workspace. In a monorepo, move this file into the package's directory, set PACKAGE_DIR in
 * release.yml, and give tagFormat a package prefix, such as "my-lib-v${version}".
 */
const fs = require("fs");

// API docs for GitHub Pages (npm-pages set): built only when typedoc.json is next to this file.
// release.yml deploys DOCS_DIR on official releases. See docs/github-pages.md in gh-dev-powerpack.
const DOCS_DIR = "docs/api";
const hasDocs = fs.existsSync(`${__dirname}/typedoc.json`);

module.exports = {
  branches: [
    // Release candidates, such as 1.1.0-rc.1: a tag and GitHub prerelease, not published to npm.
    { name: "staging", prerelease: "rc" },
    // Official releases, such as 1.1.0, started by promote.yml after it fast-forwards main.
    "main",
  ],
  tagFormat: "v${version}",
  plugins: [
    ["@semantic-release/commit-analyzer", { preset: "conventionalcommits" }],
    ["@semantic-release/release-notes-generator", { preset: "conventionalcommits" }],
    // Only main publishes. npm trusts release.yml when it is started on its own (promote.yml or a
    // manual run), not when ci.yml calls it for a candidate.
    ["@semantic-release/npm", { npmPublish: process.env.GITHUB_REF === "refs/heads/main" }],
    // Reports the released version (and the docs directory, when built) as release.yml step
    // outputs; dry runs and runs that release nothing set neither. The docs build runs after
    // @semantic-release/npm, so it shows the version written into package.json, and in 'prepare', so
    // a failed build stops the release before it is tagged. Source links point at the release tag.
    // Commands are lodash templates: '${...}' is a semantic-release value, so shell variables are
    // written as '$NAME'.
    [
      "@semantic-release/exec",
      {
        ...(hasDocs && {
          prepareCmd: `npx --no-install typedoc --out ${DOCS_DIR} --gitRevision \${nextRelease.gitTag}`,
        }),
        successCmd: [
          'if [ -n "$GITHUB_OUTPUT" ]; then',
          '  echo "version=${nextRelease.version}" >> "$GITHUB_OUTPUT";',
          ...(hasDocs ? [`  echo "docs-dir=$PWD/${DOCS_DIR}" >> "$GITHUB_OUTPUT";`] : []),
          "fi",
        ].join("\n"),
      },
    ],
    "@semantic-release/github",
  ],
};
