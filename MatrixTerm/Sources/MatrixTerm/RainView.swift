import AppKit
import MetalKit

// Device, pipeline and glyph atlases, shared by every window
final class RainRenderer {
    static let shared = RainRenderer()

    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    private var atlases: [CGFloat: MTLTexture] = [:]

    private init() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            fatalError("Metal is not available")
        }
        do {
            let library = try device.makeLibrary(source: rainShaderSource, options: nil)
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "rain_vertex")
            desc.fragmentFunction = library.makeFunction(name: "rain_fragment")
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            fatalError("Rain shader failed to compile: \(error)")
        }
        self.device = device
        self.queue = queue
    }

    // One atlas per pixel density, so a window moved to a non-Retina
    // screen gets glyphs drawn at the right size
    func atlas(scale: CGFloat) -> MTLTexture? {
        if let atlas = atlases[scale] { return atlas }
        let atlas = GlyphAtlas.make(device: device, scale: scale)
        atlases[scale] = atlas
        return atlas
    }
}

// The rain layer. Redraws at most 30 times a second, and only while its
// window is focused and on screen; otherwise it holds its last frame.
final class RainView: MTKView, MTKViewDelegate {
    private let renderer = RainRenderer.shared
    private var atlas: MTLTexture?
    private var scale: CGFloat = 1

    // Steps run on a clock that only advances while raining, so a frozen
    // window picks up where it stopped instead of jumping ahead
    private var stepsBeforePause: Double = 0
    private var runningSince: CFTimeInterval?

    init(frame: NSRect) {
        super.init(frame: frame, device: RainRenderer.shared.device)
        delegate = self
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        autoResizeDrawable = false
        enableSetNeedsDisplay = false
        isPaused = true
        layer?.isOpaque = true
        preferredFramesPerSecond = Config.rainFPS
    }

    required init(coder: NSCoder) { fatalError("not used") }

    // Clicks fall through to the window, which hands focus to the terminal
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: Pausing

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                     NSWindow.didChangeOcclusionStateNotification] {
            center.removeObserver(self, name: name, object: nil)
            if let window {
                center.addObserver(self, selector: #selector(updateRunning), name: name, object: window)
            }
        }
        updateDrawableSize()
        updateRunning()
    }

    @objc private func updateRunning() {
        guard let window else { return }
        let run = window.isKeyWindow && window.occlusionState.contains(.visible)
        guard run == isPaused else { return }
        if run {
            runningSince = CACurrentMediaTime()
        } else {
            stepsBeforePause = currentSteps()
            runningSince = nil
        }
        isPaused = !run
    }

    private func currentSteps() -> Double {
        guard let runningSince else { return stepsBeforePause }
        return stepsBeforePause + (CACurrentMediaTime() - runningSince) * Double(Config.rainFPS)
    }

    // MARK: Size

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        scale = (window?.backingScaleFactor ?? 2) * Config.rainResolution
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        guard size.width > 0, size.height > 0 else { return }
        atlas = renderer.atlas(scale: scale)
        if drawableSize != size {
            drawableSize = size
            // A paused view wouldn't repaint, leaving a stretched old frame
            if isPaused { draw() }
        }
    }

    // MARK: Drawing

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
              let commands = renderer.queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        encode(encoder)
        commands.present(drawable)
        commands.commit()
    }

    private func encode(_ encoder: MTLRenderCommandEncoder) {
        guard let atlas else { encoder.endEncoding(); return }

        let cell = SIMD2<Float>(Float(Config.rainCell.width * scale), Float(Config.rainCell.height * scale))
        var uniforms = RainUniforms(
            cellPx: cell,
            step: UInt32(truncatingIfNeeded: Int(currentSteps())),
            rows: UInt32((Float(drawableSize.height) / cell.y).rounded(.up)),
            glyphCount: UInt32(Config.rainGlyphs.count),
            gapMin: UInt32(Config.rainGap.lowerBound),
            gapSpan: UInt32(Config.rainGap.upperBound - Config.rainGap.lowerBound),
            fade: Config.rainFade,
            opacity: Config.rainOpacity,
            color: Config.rainColor)

        encoder.setRenderPipelineState(renderer.pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RainUniforms>.stride, index: 0)
        encoder.setFragmentTexture(atlas, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
