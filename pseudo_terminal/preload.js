const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  sendInput: (input) => ipcRenderer.send("user-input", input),
  ready: (cols, rows) => ipcRenderer.send("terminal-ready", { cols, rows }),
  resize: (cols, rows) => ipcRenderer.send("resize", { cols, rows }),
  onOutput: (callback) =>
    ipcRenderer.on("proc-output", (event, data) => callback(data)),
  onSetUsername: (callback) =>
    ipcRenderer.on("set-username", (event, name) => callback(name)),
});
