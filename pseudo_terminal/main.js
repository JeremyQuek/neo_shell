const { app, BrowserWindow, ipcMain } = require("electron");
const pty = require("node-pty");
const path = require("path");
const os = require("os");

let mainWindow;
let shellProc;
let shellBin = "/bin/zsh";

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 600,
    backgroundColor: "#000000",
    webPreferences: { preload: path.join(__dirname, "preload.js") },
  });

  mainWindow.loadFile("index.html");

  // Send the username once the page finishes loading
  mainWindow.webContents.on("did-finish-load", () => {
    const userName = os.userInfo().username.toUpperCase();
    mainWindow.webContents.send("set-username", userName);
  });
}

// Run zsh inside a real pseudo-terminal, so signals (Ctrl+C), password
// prompts and full-screen apps (htop, vim) behave like a normal terminal.
// Started only once xterm.js is up, so the first prompt isn't dropped.
function startShell(cols, rows) {
  shellProc = pty.spawn(shellBin, ["-l"], {
    name: "xterm-256color",
    cols,
    rows,
    cwd: os.homedir(),
    env: {
      ...process.env,
      TERM: "xterm-256color",
      COLORTERM: "truecolor",
      // Don't inherit Terminal.app's identity, or /etc/zshrc_Apple_Terminal
      // redirects history into per-session files under ZDOTDIR
      TERM_PROGRAM: "NASH",
      SHELL_SESSIONS_DISABLE: "1",
      // NASH-only rc files: load ~/.z* then apply the green theme on top
      ZDOTDIR: path.join(__dirname, "zsh"),
    },
  });

  shellProc.onData((data) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send("proc-output", data);
    }
  });

  // Typing `exit` (or Ctrl+D) ends zsh — close the app with it
  shellProc.onExit(() => {
    shellProc = null;
    app.quit();
  });
}

ipcMain.on("terminal-ready", (event, { cols, rows }) => {
  if (!shellProc) startShell(cols, rows);
  else shellProc.resize(cols, rows); // page reload: keep the same session
});

// Raw keystrokes from xterm.js go straight to the pty
ipcMain.on("user-input", (event, data) => {
  if (shellProc) shellProc.write(data);
});

ipcMain.on("resize", (event, { cols, rows }) => {
  if (shellProc && cols > 0 && rows > 0) shellProc.resize(cols, rows);
});

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (shellProc) shellProc.kill();
  app.quit();
});

// The absolute final safety net
app.on("will-quit", () => {
  if (shellProc) shellProc.kill("SIGKILL");
});
