---
name: vsce-demos
description: >-
  Record a demo video (.webm) of a VS Code extension running in VS Code, for a README or
  Marketplace page. Use when asked for a demo, screencast, video or GIF of a VS Code extension,
  or to re-record one after a UI change, especially on Linux under Wayland with no xdotool.
---

# VS Code extension demos

Record the real extension in a real VS Code window. A script drives VS Code from inside its
extension host, so no mouse or keyboard automation tool is needed, and ffmpeg records the window.
These steps come from a recording that worked on Ubuntu (Wayland session, XWayland, ffmpeg 6+).

## Before you start

- Check `ffmpeg` (with `libvpx-vp9`), `xwininfo`, and `$DISPLAY`. Do not install packages without
  asking.
- Find a VS Code to run: `<repo>/.vscode-test/vscode-linux-x64-*/code` if the repo's tests have
  downloaded one, else let `@vscode/test-electron` download it. The extension must be built
  (`dist/` current) and `@vscode/test-electron` resolvable from the extension folder.
- Warn the user that the recording takes over their screen for a minute or two per take.
- Work in the agent's scratchpad, not the repo. Only the final `.webm` and README text go in the
  repo. Keep the throwaway workspace (a few small sample files) outside it, so the demo never edits
  real source.

## Method

1. **Sample workspace and settings.** Write a small workspace with just the files the story needs
   and a fresh profile `User/settings.json`: `workbench.startupEditor: none`, minimap off, status
   bar and activity bar hidden, `window.zoomLevel` about 3, `editor.wordWrap: on`,
   `editor.hover.delay` very large (so stray mouse positions never open hovers),
   `telemetry.telemetryLevel: off`, `update.mode: none`. Do not pass `--disable-extensions`: it
   shows a "extensions are disabled" toast.
2. **Driver.** Copy `assets/driver-template.js`. It runs in the extension host and uses
   `vscode.commands.executeCommand` for native UI: open files, move the cursor, `showHover`, the
   extension's own commands, `type` for live typing in the editor.
3. **Record.** Run `scripts/record.js` (env vars are in its header). It starts VS Code, waits for
   the driver's ready file, starts ffmpeg on the window, then releases the driver.
4. **Look before you ship.** Pull frames with `ffmpeg -ss T -i raw.mkv -frames:v 1` and tile them
   into one sheet (`hstack`/`vstack`), then read the sheet. Check every phase: text legible,
   nothing cut off, no stray toast or Untitled editor, features actually on screen. Expect two or
   three takes.
5. **Encode.** `ffmpeg -ss <skip> -i raw.mkv -vf "setpts=PTS/1.25,fps=30" -c:v libvpx-vp9 -crf 36
   -b:v 0 -row-mt 1 -an demo.webm`. Raw capture is already scaled to 1920 wide. Aim for about
   1 to 1.5 MB per minute. Choose the speed-up with the user (1.25x was asked for once).

## Lessons that cost time

- **Wayland + XWayland.** Launch with `--ozone-platform=x11` or ffmpeg's `x11grab` sees nothing.
  `x11grab -window_id` captures one window and is live.
- **GPU.** Do not pass `--disable-gpu`: software rendering at high resolution made typing look
  laggy in the video. The extension was not slow; a latency measurement in the page showed about
  175 ms from keystroke to result, nearly all of it the extension's own debounce.
- **Full screen, then record.** The window opens at about half the screen. Run
  `workbench.action.toggleFullScreen` first and start ffmpeg only afterwards (the ready/flag
  handshake). If the window resizes mid-capture, the recording breaks.
- **Text size vs layout.** The capture is scaled to 1920 wide, so small text is unreadable, but a
  high zoom makes the CSS viewport narrow and responsive webviews stack their panes. Pick the zoom
  for readable text, then widen the panel's editor group instead of lowering the zoom:
  `workbench.action.focusSecondEditorGroup`, then `workbench.action.increaseViewSize` several
  times, and `workbench.action.evenEditorWidths` to restore. The group must be focused first, or
  the command widens the code editor and squeezes the panel. Do not use
  `toggleMaximizeEditorGroup`: it reloads the webview and the CDP session loses it.
- **XTest does not work.** `libXtst` mouse and keyboard events (for example from a ctypes script)
  were accepted but never reached VS Code under XWayland. Do not spend time on it; use CDP.
- **Driving a webview: CDP.** The extension API cannot type into a webview. Launch with
  `--remote-debugging-port=9333 --remote-allow-origins=*` (without the second flag the WebSocket
  hangs), then use `scripts/cdp.js`: it attaches to the webview frame (a nested iframe inside an
  iframe target) and offers `ev(js)` to run code in the panel's document, `insert(text)` and
  `key(...)` for real typing, retrying while a frame reattaches. The webview only exists once the panel is open: if the cursor was outside the target, the
  command shows an input box instead and there is nothing to attach to. To expand a collapsible
  section, call `.click()` on its `summary` element through `ev`.
- **Web components.** Set widget state the way the widget listens: for a checkbox set `.checked`
  and dispatch a `change` event (`.click()` on the host element did nothing). For a split layout,
  set `handlePosition` after the content has been typed, as earlier values were overridden.
- **Show state changes honestly.** Anchored patterns match nothing on multi-line input; turn on
  per-line mode in the demo rather than hiding it.
- **Never kill by process name.** `pkill -f` patterns match the agent's own shell, and
  `kill $(pgrep -x node)` hits the user's other processes. Kill only PIDs you started, or let the
  run finish (`timeout` it).
- **Passing arguments.** `vscode.window.showTextDocument` takes a document or URI, not the editor
  it returned.

## Wiring it into the README

- GitHub renders `<video src="path/demo.webm" controls muted width="100%"></video>` in a
  repository README. The Marketplace and Open VSX READMEs do not play video, so keep it out of the
  README that ships in the `.vsix`, and check `.vscodeignore` so the file does not ship either.
- Put the file beside the extension's images (for example `images/demo.webm`) and add one
  sentence saying what the video shows. Say plainly which part is unverified (how GitHub renders
  it) instead of claiming it.
- Re-record when the UI changes. If a feature in the video was removed from the product, remove
  it from the scenario before recording, not after.
