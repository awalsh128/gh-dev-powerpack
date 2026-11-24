import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  analyzeCommits,
  capChange,
  changeType,
  commitReleaseType,
  nextReleaseType,
  type ReleaseType,
} from "./release-version.mts";

const run = (
  commits: string[],
  lastVersion: string | undefined,
  env: NodeJS.ProcessEnv,
  options?: { requireAllowMajor?: boolean },
) => {
  const logged: string[] = [];
  const result = analyzeCommits(options, {
    commits: commits.map((message) => ({ message })),
    lastRelease: { version: lastVersion },
    env,
    logger: { log: (message) => logged.push(message) },
  });
  return { result, logged };
};

describe("commitReleaseType", () => {
  const cases: [string, ReleaseType | null][] = [
    ["fix: handle empty classes", "patch"],
    ["perf(explainer): cache char sets", "patch"],
    ["feat: explain modifiers", "minor"],
    ["feat!: rename explainRegex", "major"],
    ["fix: x\n\nBREAKING CHANGE: removed y", "major"],
    ["docs: reword README", null],
    ["not conventional", null],
  ];
  for (const [message, expected] of cases) {
    it(`maps ${JSON.stringify(message.split("\n")[0])} to ${expected}`, () => {
      assert.equal(commitReleaseType(message), expected);
    });
  }
});

describe("changeType", () => {
  it("returns the largest bump", () => {
    assert.equal(changeType(["docs: a", "fix: b", "feat: c"]), "minor");
  });

  it("returns null when nothing releases", () => {
    assert.equal(changeType(["docs: a", "ci: b"]), null);
  });
});

describe("capChange", () => {
  const cases: [ReleaseType | null, boolean, ReleaseType | null][] = [
    ["major", false, "minor"],
    ["major", true, "major"],
    ["minor", false, "minor"],
    ["patch", false, "patch"],
    [null, false, null],
  ];
  for (const [change, allow, expected] of cases) {
    it(`maps ${change} to ${expected} when major is ${allow ? "" : "not "}allowed`, () => {
      assert.equal(capChange(change, allow), expected);
    });
  }
});

describe("nextReleaseType", () => {
  const bumps: [ReleaseType | null, string | undefined, boolean, ReleaseType][] = [
    ["patch", "1.0.2", true, "minor"],
    ["minor", "1.1.0", true, "patch"],
    [null, "1.1.1", false, "minor"],
    ["patch", "1.2.0", false, "patch"],
    ["major", "1.2.0", false, "major"],
    ["minor", undefined, false, "minor"],
  ];
  for (const [change, last, pre, expected] of bumps) {
    it(`bumps ${expected} after ${last} for a ${change} ${pre ? "pre-release" : "release"}`, () => {
      assert.equal(nextReleaseType(change, last, pre), expected);
    });
  }

  const refusals: [ReleaseType, string | undefined, boolean, RegExp][] = [
    ["minor", "1.2.0", false, /publish them as a pre-release/],
    ["major", "1.2.0", true, /publish them as a release/],
    ["patch", undefined, true, /Tag the last published version/],
  ];
  for (const [change, last, pre, expected] of refusals) {
    it(`refuses a ${change} ${pre ? "pre-release" : "release"} after ${last}`, () => {
      assert.throws(() => nextReleaseType(change, last, pre), expected);
    });
  }
});

describe("analyzeCommits", () => {
  it("reads VSCE_PRE_RELEASE and logs the decision", async () => {
    const { result, logged } = run(["fix: a"], "1.0.0", { VSCE_PRE_RELEASE: "true" });

    assert.equal(await result, "minor");
    assert.ok(logged.some((line) => /publishing a pre-release with minor bump/.test(line)));
  });

  it("bumps major for breaking commits by default, ignoring ALLOW_MAJOR", async () => {
    assert.equal(await run(["feat!: remove the syntax tree"], "1.4.0", {}).result, "major");
    assert.equal(
      await run(["feat!: remove the syntax tree"], "1.4.0", { ALLOW_MAJOR: "false" }).result,
      "major",
    );
  });

  describe("with requireAllowMajor", () => {
    const options = { requireAllowMajor: true };
    const breaking = ["feat!: remove the syntax tree"];

    it("releases a breaking commit as a pre-release when ALLOW_MAJOR is unset", async () => {
      const { result, logged } = run(breaking, "1.4.0", { VSCE_PRE_RELEASE: "true" }, options);

      assert.equal(await result, "minor");
      assert.ok(logged.some((line) => /counted as features/.test(line)));
    });

    it("bumps major when ALLOW_MAJOR is true or 1", async () => {
      assert.equal(await run(breaking, "1.4.0", { ALLOW_MAJOR: "true" }, options).result, "major");
      assert.equal(await run(breaking, "1.4.0", { ALLOW_MAJOR: "1" }, options).result, "major");
    });

    it("refuses a breaking release after a release when ALLOW_MAJOR is unset", async () => {
      await assert.rejects(run(breaking, "1.4.0", {}, options).result, /skip a minor version/);
    });
  });
});
