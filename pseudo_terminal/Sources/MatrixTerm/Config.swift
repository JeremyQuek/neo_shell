import AppKit

// Every tunable in one place. Values carried over from the old Tauri
// build, so NASH looks the same as before.
enum Config {
    // --- Rain ---
    static let rainFPS = 30
    static let rainGlyphs = Array("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃ1234567890")
    static let rainFont = NSFont(name: "Arial", size: 16) ?? .systemFont(ofSize: 16)
    static let rainCell = CGSize(width: 16, height: 16)   // points
    static let rainColor = SIMD3<Float>(0x38, 0xE0, 0x57) / 255
    static let rainOpacity: Float = 0.8
    // Each step a trail cell keeps this much of its brightness (the old
    // canvas painted black at 8% over everything each frame)
    static let rainFade: Float = 0.92
    // Gap between drops, in steps, after a drop leaves the bottom
    static let rainGap = 10...70
    // Render the rain at a fraction of the backing scale (1 = full Retina)
    static let rainResolution: CGFloat = 1

    // --- Terminal ---
    static let font = NSFont(name: "Courier New Bold", size: 14)
        ?? .monospacedSystemFont(ofSize: 14, weight: .bold)
    static let margin: CGFloat = 20
    static let scrollback = 2000
    static let shell = "/bin/zsh"

    static let foreground = NSColor(hex: 0x38E057)
    static let selection = NSColor(hex: 0x38E057).withAlphaComponent(0x55 / 255)
    // Every ANSI colour is a shade of green, so whatever programs print
    // (git, htop, errors) stays on theme
    static let ansi: [UInt32] = [
        0x0A2A12, 0x7CFF8F, 0x38E057, 0x9CFF6B, 0x1F8F3A, 0x5CE07A, 0x2FBF5A, 0xB8FFC4,
        0x1F6B33, 0xA6FFB0, 0x5CFF7A, 0xC4FF9C, 0x2FBF5A, 0x7CFF8F, 0x4CE070, 0xE0FFE6,
    ]
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255,
                  green: CGFloat(hex >> 8 & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
