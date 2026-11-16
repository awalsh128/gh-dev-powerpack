// Minimal CDP client that evaluates code inside the Regex Explain webview frame.
const http = require("http");
const WS = typeof WebSocket !== "undefined" ? WebSocket : require("ws");
function getJson(url) {
  return new Promise((res, rej) => http.get(url, (r) => { let b = ""; r.on("data", (d) => (b += d)); r.on("end", () => res(JSON.parse(b))); }).on("error", rej));
}
exports.connect = async function connect(port = 9333) {
  const targets = await getJson(`http://127.0.0.1:${port}/json`);
  const page = targets.find((t) => t.type === "page");
  const ws = new WS(page.webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  let id = 0; const pending = new Map(); const sessions = new Set();
  ws.onmessage = (ev) => {
    const m = JSON.parse(typeof ev.data === "string" ? ev.data : ev.data.toString());
    if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); }
    else if (m.method === "Target.attachedToTarget") {
      sessions.add(m.params.sessionId);
      send("Target.setAutoAttach", { autoAttach: true, waitForDebuggerOnStart: false, flatten: true }, m.params.sessionId).catch(() => {});
    } else if (m.method === "Target.detachedFromTarget") sessions.delete(m.params.sessionId);
  };
  const send = (method, params = {}, sessionId) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params, sessionId })); });
  await send("Target.setAutoAttach", { autoAttach: true, waitForDebuggerOnStart: false, flatten: true });
  await new Promise((r) => setTimeout(r, 1000));
  // Finds the session of the frame that holds the panel (it has the match input).
  const DOC = "(document.querySelector('vscode-textarea.input') ? document : ((document.querySelector('iframe') || {}).contentDocument && document.querySelector('iframe').contentDocument.querySelector('vscode-textarea.input') ? document.querySelector('iframe').contentDocument : null))";
  async function panelSession() {
    for (let attempt = 0; attempt < 25; attempt++) {
    for (const s of [...sessions]) {
      try {
        const r = await send("Runtime.evaluate", { expression: "!!(" + DOC + ")", returnByValue: true }, s);
        if (r.result.value === true) return s;
      } catch {}
    }
    await new Promise((r) => setTimeout(r, 400));
    }
    throw new Error("panel frame not found among " + sessions.size + " sessions");
  }
  return {
    async ev(expression) { const sid = await panelSession(); const r = await send("Runtime.evaluate", { expression: "(function(document){ return eval(" + JSON.stringify(expression) + ") })(" + DOC + ")", returnByValue: true, awaitPromise: true }, sid); if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails)); return r.result.value; },
    insert: (text) => send("Input.insertText", { text }),
    key: (key, code, vk) => send("Input.dispatchKeyEvent", { type: "keyDown", key, code, windowsVirtualKeyCode: vk, text: key === "Enter" ? "\r" : undefined }).then(() => send("Input.dispatchKeyEvent", { type: "keyUp", key, code, windowsVirtualKeyCode: vk })),
    close: () => ws.close(),
  };
};
