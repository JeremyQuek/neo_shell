import AppKit
import SwiftTerm

// One window = rain underneath, terminal on top, its own zsh
final class TerminalWindow: NSWindow, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    let terminal: TerminalHost
    var onClose: ((TerminalWindow) -> Void)?

    init() {
        let frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        terminal = TerminalHost(frame: frame.insetBy(dx: Config.margin, dy: Config.margin))
        super.init(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered, defer: false)
        title = "NASH"
        backgroundColor = .black
        isReleasedWhenClosed = false
        // Same identifier on every window, so macOS can group them as tabs
        tabbingIdentifier = "nash"
        delegate = self

        let content = ClickToFocusView(frame: frame)
        let rain = RainView(frame: frame)
        rain.autoresizingMask = [.width, .height]
        terminal.autoresizingMask = [.width, .height]
        content.addSubview(rain)
        content.addSubview(terminal)
        contentView = content

        terminal.processDelegate = self
        makeFirstResponder(terminal)
        terminal.start()
    }

    // MARK: LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    // Typing `exit` (or Ctrl+D) ends zsh: close its window with it
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { self.close() }
    }

    // MARK: NSWindowDelegate

    // Window closed: take its zsh (and whatever it's running) down too
    func windowWillClose(_ notification: Notification) {
        if terminal.process.running {
            terminal.terminate()
        }
        onClose?(self)
    }
}

// Clicking the margin or the rain still focuses the terminal
private final class ClickToFocusView: NSView {
    override func mouseDown(with event: NSEvent) {
        if let terminal = subviews.compactMap({ $0 as? TerminalHost }).first {
            window?.makeFirstResponder(terminal)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [TerminalWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()
        newWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        for window in windows where window.terminal.process.running {
            window.terminal.terminate()
        }
    }

    @objc func newWindow(_ sender: Any?) {
        let window = TerminalWindow()
        window.onClose = { [weak self] closed in self?.windows.removeAll { $0 === closed } }
        windows.append(window)
        // Each new window sits a little down and right of the previous one
        if let last = windows.dropLast().last {
            window.setFrameTopLeftPoint(NSPoint(x: last.frame.minX + 24, y: last.frame.maxY - 24))
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            let holder = NSMenuItem()
            holder.submenu = menu
            main.addItem(holder)
            return menu
        }
        func item(_ title: String, _ action: Selector, _ key: String, _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = mods
            return item
        }

        _ = submenu("NASH", [
            item("About NASH", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""),
            .separator(),
            item("Hide NASH", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:)), ""),
            .separator(),
            item("Quit NASH", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = submenu("Shell", [
            item("New Window", #selector(newWindow(_:)), "n"),
            .separator(),
            item("Close Window", #selector(NSWindow.performClose(_:)), "w"),
        ])
        _ = submenu("Edit", [
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ])
        _ = submenu("View", [
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ])
        let windowMenu = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:)), ""),
        ])
        // Lets macOS fill in the window list and the tab commands
        NSApp.windowsMenu = windowMenu
        return main
    }
}
