import AppKit
import Metal

// The rain's characters, drawn once into a single-channel texture: one cell
// per glyph, left to right. White coverage only; the shader adds the colour.
enum GlyphAtlas {
    static func make(device: MTLDevice, scale: CGFloat) -> MTLTexture? {
        let glyphs = Config.rainGlyphs
        let cellW = Int((Config.rainCell.width * scale).rounded())
        let cellH = Int((Config.rainCell.height * scale).rounded())
        let width = cellW * glyphs.count

        guard let ctx = CGContext(data: nil, width: width, height: cellH, bitsPerComponent: 8,
                                  bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)

        // NSAttributedString falls back to a font that has the katakana
        // (Arial doesn't), which plain Core Graphics text wouldn't
        let font = Config.rainFont
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        // draw(at:) puts the bottom of the line (descender included) at y,
        // so y = 0 keeps descenders inside the cell
        for (i, ch) in glyphs.enumerated() {
            NSAttributedString(string: String(ch), attributes: attrs)
                .draw(at: NSPoint(x: CGFloat(i) * Config.rainCell.width, y: 0))
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let data = ctx.data else { return nil }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width,
                                                            height: cellH, mipmapped: false)
        desc.usage = .shaderRead
        desc.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: desc) else { return nil }
        // A bitmap context's first row is the top of the image, which is
        // also what Metal treats as row 0, so no flip is needed
        texture.replace(region: MTLRegionMake2D(0, 0, width, cellH), mipmapLevel: 0,
                        withBytes: data, bytesPerRow: width)
        return texture
    }
}
