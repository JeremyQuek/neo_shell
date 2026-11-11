use std::collections::HashMap;
use std::error::Error;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Mutex};
use std::{fs, thread};

use portable_pty::{native_pty_system, ChildKiller, CommandBuilder, MasterPty, PtySize};
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem, Submenu};
use tauri::window::Color;
use tauri::{
    AppHandle, Emitter, Manager, RunEvent, State, WebviewUrl, WebviewWindow, WebviewWindowBuilder,
    WindowEvent,
};

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

// One shell per window, keyed by window label
#[derive(Default)]
struct Sessions(Mutex<HashMap<String, Pty>>);

static NEXT_WINDOW: AtomicUsize = AtomicUsize::new(1);

fn size(cols: u16, rows: u16) -> PtySize {
    PtySize { rows, cols, pixel_width: 0, pixel_height: 0 }
}

fn open_window(app: &AppHandle) -> tauri::Result<()> {
    let label = format!("nash-{}", NEXT_WINDOW.fetch_add(1, Ordering::Relaxed));
    let builder = WebviewWindowBuilder::new(app, label, WebviewUrl::App("index.html".into()))
        .title("NASH")
        .inner_size(900.0, 600.0)
        .background_color(Color(0, 0, 0, 255));
    // Same identifier on every window, so macOS can group them as tabs
    #[cfg(target_os = "macos")]
    let builder = builder.tabbing_identifier("nash");
    builder.build()?;
    Ok(())
}

fn build_menu(app: &AppHandle) -> tauri::Result<Menu<tauri::Wry>> {
    let new_window = MenuItem::with_id(app, "new-window", "New Window", true, Some("CmdOrCtrl+N"))?;
    let window_menu = Submenu::with_items(
        app,
        "Window",
        true,
        &[
            &PredefinedMenuItem::minimize(app, None)?,
            &PredefinedMenuItem::maximize(app, None)?,
        ],
    )?;
    // Lets macOS fill in the window list and the tab commands
    #[cfg(target_os = "macos")]
    window_menu.set_as_windows_menu_for_nsapp()?;

    Menu::with_items(
        app,
        &[
            &Submenu::with_items(
                app,
                "NASH",
                true,
                &[
                    &PredefinedMenuItem::about(app, None, None)?,
                    &PredefinedMenuItem::separator(app)?,
                    &PredefinedMenuItem::hide(app, None)?,
                    &PredefinedMenuItem::hide_others(app, None)?,
                    &PredefinedMenuItem::show_all(app, None)?,
                    &PredefinedMenuItem::separator(app)?,
                    &PredefinedMenuItem::quit(app, None)?,
                ],
            )?,
            &Submenu::with_items(
                app,
                "Shell",
                true,
                &[
                    &new_window,
                    &PredefinedMenuItem::separator(app)?,
                    &PredefinedMenuItem::close_window(app, None)?,
                ],
            )?,
            // Without these the WebView never sees Cmd+C / Cmd+V
            &Submenu::with_items(
                app,
                "Edit",
                true,
                &[
                    &PredefinedMenuItem::copy(app, None)?,
                    &PredefinedMenuItem::paste(app, None)?,
                    &PredefinedMenuItem::select_all(app, None)?,
                ],
            )?,
            &Submenu::with_items(app, "View", true, &[&PredefinedMenuItem::fullscreen(app, None)?])?,
            &window_menu,
        ],
    )
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
fn start_shell(app: &AppHandle, label: &str, cols: u16, rows: u16) -> Result<Pty, Box<dyn Error>> {
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

    let (handle, target) = (app.clone(), label.to_string());
    thread::spawn(move || pump_output(reader, handle, target));

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

    // Typing `exit` (or Ctrl+D) ends zsh — close its window with it
    let (handle, target) = (app.clone(), label.to_string());
    thread::spawn(move || {
        let _ = child.wait();
        if let Some(window) = handle.get_webview_window(&target) {
            let _ = window.close();
        }
    });

    Ok(Pty { master: pair.master, input, killer })
}

// Shell output -> that window's xterm.js
fn pump_output(mut reader: Box<dyn Read + Send>, app: AppHandle, label: String) {
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
        let _ = app.emit_to(label.as_str(), "proc-output", text);
    }
}

#[tauri::command]
fn username() -> String {
    std::env::var("USER").unwrap_or_default().to_uppercase()
}

#[tauri::command]
fn terminal_ready(
    app: AppHandle,
    window: WebviewWindow,
    sessions: State<Sessions>,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    let mut sessions = sessions.0.lock().unwrap();
    match sessions.get(window.label()) {
        // page reload: keep the same session
        Some(pty) => pty.master.resize(size(cols, rows)).map_err(|e| e.to_string()),
        None => {
            let pty = start_shell(&app, window.label(), cols, rows).map_err(|e| e.to_string())?;
            sessions.insert(window.label().to_string(), pty);
            Ok(())
        }
    }
}

// Raw keystrokes from xterm.js go straight to the pty
#[tauri::command]
fn user_input(window: WebviewWindow, sessions: State<Sessions>, data: String) {
    if let Some(pty) = sessions.0.lock().unwrap().get(window.label()) {
        let _ = pty.input.send(data);
    }
}

#[tauri::command]
fn resize(window: WebviewWindow, sessions: State<Sessions>, cols: u16, rows: u16) {
    if let Some(pty) = sessions.0.lock().unwrap().get(window.label()) {
        if cols > 0 && rows > 0 {
            let _ = pty.master.resize(size(cols, rows));
        }
    }
}

fn main() {
    tauri::Builder::default()
        .manage(Sessions::default())
        .invoke_handler(tauri::generate_handler![username, terminal_ready, user_input, resize])
        .menu(build_menu)
        .on_menu_event(|app, event| {
            if event.id() == "new-window" {
                let _ = open_window(app);
            }
        })
        .setup(|app| {
            open_window(app.handle())?;
            Ok(())
        })
        // Window closed: take its zsh (and whatever it's running) down too
        .on_window_event(|window, event| {
            if let WindowEvent::Destroyed = event {
                if let Some(mut pty) = window.state::<Sessions>().0.lock().unwrap().remove(window.label()) {
                    let _ = pty.killer.kill();
                }
            }
        })
        .build(tauri::generate_context!())
        .expect("failed to start NASH")
        .run(|app, event| {
            if let RunEvent::Exit = event {
                for pty in app.state::<Sessions>().0.lock().unwrap().values_mut() {
                    let _ = pty.killer.kill();
                }
            }
        });
}
