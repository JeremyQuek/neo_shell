<div align=center>
  <h1 style="margin: 0;"> NEO Shell    
  </h1>
</div>


<!-- <div align="center">
      <img width="40" alt="image" src="https://github.com/user-attachments/assets/3c84286e-9154-4326-bcd0-0277b134f9f6" />
    <img width="40"  alt="image" src="https://github.com/user-attachments/assets/e1d15ced-4ae0-4436-8ca2-130e87180653" />
</div> -->

<div align="center">
<img width="100" alt="Neo Shell icon" src="pseudo_terminal/icon/icon.png" />
</div>

<div align=center>
  <img width="850"  alt="Screenshot 2026-02-23 at 4 11 37 PM" src="https://github.com/user-attachments/assets/6eb97f71-d09e-4eef-b959-6a774c10e5ce" />
</div>

This started out as a way to build my own shell. A shell design inspired from CS 162. Implements REPL architecture "Read-Eval-Print Loop" and Unix standards according to Bash and Zsh. That shell (NASH) still lives in `src/shell`.

Obviously, this isn't the most pristine piece of code I've written, and I learned that there's insanely more depth and complexity to a shell engine than I can imagine. But at least I enjoyed doing it, learned alot about TTYs, pipes & fds and it works (🙏 on my hardware).

From there I pivoted into building a polished terminal app instead, running zsh behind a pseudo-terminal (`/dev/pty`). That's Neo Shell.

## Neo Shell

Neo Shell is this repo's terminal app: a native macOS window with Matrix-style rain falling behind a zsh session, with its own green prompt theme.

It used to be built with Tauri (a WebKit page with xterm.js). It's now native Swift: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) runs zsh in a pseudo-terminal on a transparent background, and a Metal shader draws the rain underneath. The CPU only hands the GPU a step counter each frame, so with the rain on it uses about 2% CPU and 60 MB of memory, against about 10% and 143 MB for the Tauri version.

The zsh theme only applies inside Neo Shell. It loads your normal `~/.zshrc` first and never edits anything in your home folder.

### Build and run

Needs macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
bash precheck.sh     # check the tools are installed
./run.sh             # debug build, launched straight from source
./build.sh --open    # release build → pseudo_terminal/build/neo_shell.app
```

The first build downloads and compiles SwiftTerm, which takes about a minute.
