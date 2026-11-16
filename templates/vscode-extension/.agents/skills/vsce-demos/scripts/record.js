#!/usr/bin/env node
// Launches VS Code with an extension, records its window with ffmpeg, and runs a driver script
// inside the extension host. Linux, X11 or XWayland only.
//
//   VSCODE_EXE=<path to code>  EXT_DIR=<extension folder>  WORKSPACE=<folder to open>
//   DRIVER=<driver.js>  PROFILE=<user-data-dir>  OUT=<raw.mkv>  node record.js
//
// Handshake: the driver goes full screen, then writes the file named by DEMO_READY. The launcher
// finds the window and starts ffmpeg, then writes DEMO_FLAG. The driver waits for DEMO_FLAG
// before its first visible step, so the recording starts on a still window.
const { createRequire } = require("module");
const { spawn, execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const need = (k) => process.env[k] || (console.error(`set ${k}`), process.exit(2));
const EXT_DIR = need("EXT_DIR");
const { runTests } = createRequire(path.join(EXT_DIR, "package.json"))("@vscode/test-electron");
const OUT = process.env.OUT || "raw.mkv";
const DEBUG_PORT = process.env.DEBUG_PORT || "9333";
const FLAG = (process.env.DEMO_FLAG = path.resolve("flag"));
const READY = (process.env.DEMO_READY = path.resolve("ready"));
process.env.DEMO_LOG = path.resolve("log.txt");
for (const f of [FLAG, READY, process.env.DEMO_LOG]) fs.rmSync(f, { force: true });
delete process.env.ELECTRON_RUN_AS_NODE; // set by some terminals; Electron must start as an editor

let ff;
const watcher = setInterval(() => {
  if (ff || !fs.existsSync(READY)) return;
  let tree = "";
  try { tree = execSync("xwininfo -root -tree", { encoding: "utf8" }); } catch { return; }
  const line = tree.split("\n").find((l) => /Visual Studio Code/.test(l) && /\d+x\d+\+/.test(l));
  if (!line) return;
  const id = line.trim().split(/\s+/)[0];
  ff = spawn("ffmpeg", ["-y", "-f", "x11grab", "-framerate", "30", "-draw_mouse", "0",
    "-window_id", id, "-i", process.env.DISPLAY || ":0", "-vf", "scale=1920:-2",
    "-c:v", "libx264", "-preset", "ultrafast", "-crf", "16", "-pix_fmt", "yuv420p", OUT],
    { stdio: ["pipe", "inherit", "inherit"] });
  setTimeout(() => fs.writeFileSync(FLAG, "1"), 2500);
}, 500);

runTests({
  vscodeExecutablePath: need("VSCODE_EXE"),
  extensionDevelopmentPath: EXT_DIR,
  extensionTestsPath: path.resolve(need("DRIVER")),
  launchArgs: [
    `--user-data-dir=${path.resolve(need("PROFILE"))}`,
    "--disable-workspace-trust",
    "--ozone-platform=x11", // x11grab can only see X windows; do not add --disable-gpu
    `--remote-debugging-port=${DEBUG_PORT}`, "--remote-allow-origins=*", // for cdp.js
    path.resolve(need("WORKSPACE")),
  ],
}).catch((e) => console.error("run failed", e)).finally(() => {
  clearInterval(watcher);
  if (ff) { ff.stdin.write("q"); ff.on("exit", () => process.exit(0)); } else process.exit(1);
});
