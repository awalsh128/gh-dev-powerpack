// Runs inside the VS Code extension host. Adapt the scenario; keep the handshake and the helpers.
const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (m) => fs.appendFileSync(process.env.DEMO_LOG, m + "\n");

// Place the cursor inside the thing the extension acts on. A cursor outside it can make the
// command open an input box instead of the feature you wanted to show.
function at(editor, line, text, offset) {
  const col = editor.document.lineAt(line).text.indexOf(text) + offset;
  const p = new vscode.Position(line, col);
  editor.selection = new vscode.Selection(p, p);
  editor.revealRange(new vscode.Range(p, p));
}

exports.run = async function run() {
  try {
    const ws = vscode.workspace.workspaceFolders[0].uri.fsPath;
    let ed = await vscode.window.showTextDocument(vscode.Uri.file(path.join(ws, "demo.ts")));
    await vscode.commands.executeCommand("workbench.action.closeSidebar");

    // Handshake: go full screen first so the recorded window never changes size.
    await vscode.commands.executeCommand("workbench.action.toggleFullScreen");
    await sleep(3000);
    fs.writeFileSync(process.env.DEMO_READY, "1");
    while (!fs.existsSync(process.env.DEMO_FLAG)) await sleep(100);
    await sleep(1500);

    // --- scenario: native UI through commands ---
    at(ed, 1, "TARGET", 2);
    await vscode.commands.executeCommand("editor.action.showHover");
    await sleep(5000);
    await vscode.commands.executeCommand("editor.action.hideHover");
    // Pass the document, not the editor, when switching back: showTextDocument(ed.document, ...).

    // --- scenario: a webview panel, driven through CDP (see SKILL.md) ---
    // const c = await require(process.env.CDP).connect(Number(process.env.DEBUG_PORT || 9333));
    // await vscode.commands.executeCommand("workbench.action.focusSecondEditorGroup");
    // for (let i = 0; i < 8; i++) await vscode.commands.executeCommand("workbench.action.increaseViewSize");
    // await c.ev("document.querySelector('.some-input').focus()");
    // for (const ch of "typed text") { await c.insert(ch); await sleep(55); }
    // await c.key("Enter", "Enter", 13);
    // await c.ev("document.querySelector('details summary').click()");
    // c.close();
    log("done");
  } catch (e) {
    log("ERROR " + ((e && e.stack) || e));
  }
  await sleep(1000);
};
