/**
 * semantic-release configuration for the VS Code extension, run by
 * .github/workflows/publish-extension.yml from EXTENSION_DIR. See
 * docs/vscode-extension-publishing.md in gh-dev-powerpack.
 *
 * Versions follow VS Code's pre-release convention (scripts/vscode-release/release-version.mts):
 * releases use even minor versions and pre-releases odd ones. Releases never commit, so main can
 * keep fast-forwarding to staging; the version is written into package.json in the CI workspace
 * only. The workflow publishes to the registries itself, with trusted publishing.
 *
 * In a monorepo, move this file into the extension's directory and fix the plugin path below.
 */
const path = require("path");

module.exports = {
  branches: ["main"],
  tagFormat: "v${version}",
  plugins: [
    // Replaces @semantic-release/commit-analyzer. Node.js 24 loads it without a build step.
    path.join(__dirname, "scripts/vscode-release/release-version.mts"),
    ["@semantic-release/release-notes-generator", { preset: "conventionalcommits" }],
    // Sets the version and packages the VSIX for the GitHub release; publishing happens after.
    ["semantic-release-vsce", { packageVsix: true, publish: false }],
    [
      "@semantic-release/github",
      { assets: [{ path: "*.vsix", label: "Extension package (VSIX)" }] },
    ],
  ],
};
