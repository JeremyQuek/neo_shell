import AppKit
import SwiftTerm

// zsh in a pty, drawn by SwiftTerm on a clear background so the rain shows
// through. Text, the cursor and selections stay opaque.
final class TerminalHost: LocalProcessTerminalView {
    override init(frame: NSRect) {
        super.init(frame: frame, font: Config.font,
                   options: TerminalOptions(cursorStyle: .blinkBlock, scrollback: Config.scrollback))
        nativeForegroundColor = Config.foreground
        nativeBackgroundColor = .black
        backgroundOpacity = 0
        caretColor = Config.foreground
        caretTextColor = .black
        selectedTextBackgroundColor = Config.selection
        installColors(Config.ansi.map { hex in
            Color(red: UInt16(hex >> 16 & 0xFF) * 257,
                  green: UInt16(hex >> 8 & 0xFF) * 257,
                  blue: UInt16(hex & 0xFF) * 257)
        })
        // SwiftTerm's scroll bar shows as a grey strip over the clear
        // background. Trackpad and wheel scrolling don't need it, and
        // re-applying the size hands its width back to the text.
        for case let scroller as NSScroller in subviews {
            scroller.isHidden = true
        }
        setFrameSize(frame.size)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func start() {
        let user = (ProcessInfo.processInfo.environment["USER"] ?? NSUserName()).uppercased()
        // Banner first, so zsh's first prompt lands underneath it
        feed(text: "< NEO SHELL UPLINK ESTABLISHED >\r\nWAKE UP....\(user)\r\n\r\n")

        startProcess(executable: Config.shell, args: ["-l"],
                     environment: Self.environment(),
                     currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    private static func environment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        // Don't inherit Terminal.app's identity, or /etc/zshrc_Apple_Terminal
        // redirects history into per-session files under ZDOTDIR
        env["TERM_PROGRAM"] = "neo_shell"
        env["SHELL_SESSIONS_DISABLE"] = "1"
        env.removeValue(forKey: "TERM_SESSION_ID")
        // Started from Finder there's no locale, and zsh would then treat
        // the ❯ in the prompt as raw bytes
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        if let dir = ZshTheme.install() { env["ZDOTDIR"] = dir }
        return env.map { "\($0.key)=\($0.value)" }
    }
}

// Neo Shell-only zsh rc files. zsh reads these from ZDOTDIR instead of ~/.z*; each
// loads the real file from $HOME first, so nothing in $HOME is modified.
enum ZshTheme {
    private static let files: [(String, String)] = [
        (".zshenv", """
            [[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"

            """),
        (".zprofile", """
            [[ -f "$HOME/.zprofile" ]] && source "$HOME/.zprofile"

            """),
        (".zshrc", """
            # Keep history in the usual place (/etc/zshrc would point it at ZDOTDIR)
            HISTFILE="$HOME/.zsh_history"

            [[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"

            # --- Neo Shell overrides: everything green ---
            PROMPT='%B%F{green}%n%f%b %F{22}❯%f %F{green}%1~%f %B%F{green}❯%f%b '
            RPROMPT='%F{22}%*%f'

            export CLICOLOR=1
            export LSCOLORS=cxcxcxcxcxcxcxcxcxcxcx   # ls -G: every file type green
            export GREP_COLORS='mt=01;32'

            """),
        (".zlogin", """
            [[ -f "$HOME/.zlogin" ]] && source "$HOME/.zlogin"
            # All rc files are read; don't pass ZDOTDIR to programs started from here (e.g. `code .`)
            unset ZDOTDIR

            """),
    ]

    // Written somewhere zsh can also keep its caches (.zcompdump), and
    // rewritten on every launch so app updates take effect
    static func install() -> String? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("com.jeremyquek.neoshell/zsh")
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for (name, body) in files {
                try body.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }
        } catch {
            return nil
        }
        return dir.path
    }
}
