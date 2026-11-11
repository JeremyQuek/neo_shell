use std::error::Error;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::{mpsc, Mutex};
use std::{fs, thread};

use portable_pty::{native_pty_system, ChildKiller, CommandBuilder, MasterPty, PtySize};
use tauri::{AppHandle, Emitter, Manager, RunEvent, State};

const SHELL_BIN: &str = "/bin/zsh";

// NASH-only rc files, baked into the binary so the .app needs no loose files
const ZSH_RC: [(&str, &str); 4] = [
    (".zshenv", include_str!("../theme/.zshenv")),
    (".zprofile", include_str!("../theme/.zprofile")),
    (".zshrc", include_str!("../theme/.zshrc")),
    (".zlogin", include_str!("../theme/.zlogin")),
];

struct Pty {
    master: Box<dyn MasterPty + Send>,
    input: mpsc::Sender<String>,
    killer: Box<dyn ChildKiller + Send + Sync>,
}

#[derive(Default)]
struct Session(Mutex<Option<Pty>>);

fn size(cols: u16, rows: u16) -> PtySize {
    PtySize { rows, cols, pixel_width: 0, pixel_height: 0 }
}

// Write the rc files somewhere zsh can also write its caches (.zcompdump),
// rather than inside the signed, read-only app bundle
fn zdotdir(app: &AppHandle) -> Result<PathBuf, Box<dyn Error>> {
    let dir = app.path().app_data_dir()?.join("zsh");
    fs::create_dir_all(&dir)?;
    for (name, body) in ZSH_RC {
        fs::write(dir.join(name), body)?;
    }
    Ok(dir)
}

// Run zsh inside a real pseudo-terminal, so signals (Ctrl+C), password
// prompts and full-screen apps (htop, vim) behave like a normal terminal.
// Started only once xterm.js is up, so the first prompt isn't dropped.
fn start_shell(app: &AppHandle, cols: u16, rows: u16) -> Result<Pty, Box<dyn Error>> {
    let pair = native_pty_system().openpty(size(cols, rows))?;

    let mut cmd = CommandBuilder::new(SHELL_BIN);
    cmd.arg("-l");
    if let Ok(home) = std::env::var("HOME") {
        cmd.cwd(home);
    }
    cmd.env("TERM", "xterm-256color");
    cmd.env("COLORTERM", "truecolor");
    // Don't inherit Terminal.app's identity, or /etc/zshrc_Apple_Terminal
    // redirects history into per-session files under ZDOTDIR
    cmd.env("TERM_PROGRAM", "NASH");
    cmd.env("SHELL_SESSIONS_DISABLE", "1");
    // NASH-only rc files: load ~/.z* then apply the green theme on top
    cmd.env("ZDOTDIR", zdotdir(app)?);

    let mut child = pair.slave.spawn_command(cmd)?;
    // zsh holds the slave end now; dropping ours lets reads hit EOF when it exits
    drop(pair.slave);
    let killer = child.clone_killer();
    let reader = pair.master.try_clone_reader()?;
    let mut writer = pair.master.take_writer()?;

    let handle = app.clone();
    thread::spawn(move || pump_output(reader, handle));

    // Writes go through their own thread: a pty only buffers ~1 KB of input,
    // so a big paste into a busy program would otherwise freeze the window
    let (input, keystrokes) = mpsc::channel::<String>();
    thread::spawn(move || {
        for data in keystrokes {
            if writer.write_all(data.as_bytes()).is_err() {
                break;
            }
        }
    });

    // Typing `exit` (or Ctrl+D) ends zsh — close the app with it
    let handle = app.clone();
    thread::spawn(move || {
        let _ = child.wait();
        handle.exit(0);
    });

    Ok(Pty { master: pair.master, input, killer })
}

// Shell output -> xterm.js
fn pump_output(mut reader: Box<dyn Read + Send>, app: AppHandle) {
    let mut buf = [0u8; 8192];
    let mut pending = Vec::new();
    loop {
        let n = match reader.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => n,
        };
        pending.extend_from_slice(&buf[..n]);
        // A read can stop partway through a multi-byte character (like the
        // ❯ in the prompt); hold those bytes back until the rest arrives
        let complete = match std::str::from_utf8(&pending) {
            Err(e) if e.error_len().is_none() => e.valid_up_to(),
            _ => pending.len(),
        };
        let text = String::from_utf8_lossy(&pending[..complete]).into_owned();
        pending.drain(..complete);
        let _ = app.emit("proc-output", text);
    }
}

#[tauri::command]
fn username() -> String {
    std::env::var("USER").unwrap_or_default().to_uppercase()
}

#[tauri::command]
fn terminal_ready(app: AppHandle, session: State<Session>, cols: u16, rows: u16) -> Result<(), String> {
    let mut pty = session.0.lock().unwrap();
    match pty.as_ref() {
        // page reload: keep the same session
        Some(pty) => pty.master.resize(size(cols, rows)).map_err(|e| e.to_string()),
        None => {
            *pty = Some(start_shell(&app, cols, rows).map_err(|e| e.to_string())?);
            Ok(())
        }
    }
}

// Raw keystrokes from xterm.js go straight to the pty
#[tauri::command]
fn user_input(session: State<Session>, data: String) {
    if let Some(pty) = session.0.lock().unwrap().as_ref() {
        let _ = pty.input.send(data);
    }
}

#[tauri::command]
fn resize(session: State<Session>, cols: u16, rows: u16) {
    if let Some(pty) = session.0.lock().unwrap().as_ref() {
        if cols > 0 && rows > 0 {
            let _ = pty.master.resize(size(cols, rows));
        }
    }
}

fn main() {
    tauri::Builder::default()
        .manage(Session::default())
        .invoke_handler(tauri::generate_handler![username, terminal_ready, user_input, resize])
        .build(tauri::generate_context!())
        .expect("failed to start NASH")
        .run(|app, event| {
            // Window closed or app quit: take zsh (and whatever it's running) down too
            if let RunEvent::Exit = event {
                if let Some(pty) = app.state::<Session>().0.lock().unwrap().as_mut() {
                    let _ = pty.killer.kill();
                }
            }
        });
}
