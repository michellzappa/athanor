import CoreGraphics
import Foundation

/// Runs one scene at a time: construct, hold, dissolve, then pick the next
/// figure. Owns the renderer and the timeline; a host just hands it a context.
final class Director {
    private enum Phase { case constructing, holding, dissolving }

    private struct Item {
        let stroke: Stroke
        let start: CGFloat
        var committed: Bool
    }

    private let renderer = InkRenderer()
    private let compact: Bool
    private let settingsProvider: () -> RenderSettings
    private var rng: SeededRandom

    private var settings: RenderSettings = .default
    private var items: [Item] = []
    private var totalUnits: CGFloat = 1
    private var palette: Palette = .bone
    private var rotationRate: CGFloat = 0

    private var phase: Phase = .constructing
    private var phaseStart: TimeInterval = 0
    private var driftTime: CGFloat = 0
    private var lastFrame: TimeInterval = 0
    private var lastFigureID: String?
    private var needsScene = true

    private var constructDuration: TimeInterval = 40
    private var holdDuration: TimeInterval = 9
    private var dissolveDuration: TimeInterval = 4

    private var ground: (CGFloat, CGFloat, CGFloat) = (0, 0, 0)

    /// Title of the figure currently on screen, for hosts that want to show it.
    private(set) var currentTitle: String = ""

    /// `compact` is for thumbnails and previews: tighter inset, quicker cycle.
    init(compact: Bool = false,
         seed: UInt64 = UInt64.random(in: 1...UInt64.max),
         settings: @escaping () -> RenderSettings = { .default }) {
        self.compact = compact
        self.settingsProvider = settings
        rng = SeededRandom(seed: seed)
    }

    func configure(size: CGSize, backingScale: CGFloat) {
        let changed = size != renderer.size
        renderer.configure(size: size, backingScale: backingScale, inset: compact ? 0.40 : 0.43)
        // A resize invalidates the baked bitmap; replay what has already been drawn.
        if changed, !needsScene { replayCommitted() }
    }

    func reset() {
        needsScene = true
        lastFrame = 0
    }

    /// Abandon the current figure and begin another.
    func skip() {
        needsScene = true
    }

    // MARK: - Scene lifecycle

    private func startScene(at time: TimeInterval) {
        settings = settingsProvider()
        var pool = FigureCatalog.enabled(ids: settings.enabledFigureIDs)
        if pool.count > 1, let last = lastFigureID {
            pool.removeAll { $0.id == last }
        }
        let kind = rng.pick(pool)
        lastFigureID = kind.id
        currentTitle = kind.title

        palette = settings.palette(using: &rng)
        var drawing = kind.build(&rng)
        if !settings.showConstruction {
            drawing.strokes.removeAll { $0.role == .construction }
        }
        rotationRate = drawing.rotationRate

        buildTimeline(drawing)

        let pace = max(0.2, settings.pace)
        let base: TimeInterval = compact ? 14 : 42
        constructDuration = base * TimeInterval(drawing.pacing) / TimeInterval(pace)
        holdDuration = (compact ? 3 : 9) / TimeInterval(pace)
        dissolveDuration = (compact ? 1.5 : 4) / TimeInterval(pace)

        renderer.clearCanvas()
        phase = .constructing
        phaseStart = time
        driftTime = 0
        needsScene = false
    }

    private func buildTimeline(_ drawing: Drawing) {
        let groups = Dictionary(grouping: drawing.strokes, by: \.group)
        var cursor: CGFloat = 0
        var out: [Item] = []
        for key in groups.keys.sorted() {
            let strokes = groups[key] ?? []
            var span: CGFloat = 0
            for stroke in strokes {
                out.append(Item(stroke: stroke, start: cursor, committed: false))
                span = max(span, stroke.length / stroke.role.drawSpeed)
            }
            // A breath between groups keeps the construction from reading as one
            // continuous scribble.
            cursor += span + max(0.012, span * 0.08)
        }
        items = out
        totalUnits = max(cursor, 0.001)
    }

    private func replayCommitted() {
        renderer.clearCanvas()
        for i in items.indices where items[i].committed {
            renderer.commit(items[i].stroke, palette: palette,
                            weight: settings.lineWeight, glow: settings.glow)
        }
    }

    // MARK: - Frame

    func draw(in ctx: CGContext, bounds: CGRect, time: TimeInterval) {
        if needsScene { startScene(at: time) }
        let dt = lastFrame == 0 ? 0 : min(CGFloat(time - lastFrame), 0.25)
        lastFrame = time

        let elapsed = time - phaseStart
        var progress: CGFloat = 1
        var alpha: CGFloat = 1
        var extraScale: CGFloat = 1

        switch phase {
        case .constructing:
            progress = clamp(CGFloat(elapsed / constructDuration), 0, 1)
            if elapsed >= constructDuration {
                phase = .holding
                phaseStart = time
            }
        case .holding:
            driftTime += dt
            if elapsed >= holdDuration {
                phase = .dissolving
                phaseStart = time
            }
        case .dissolving:
            driftTime += dt
            let t = easeInOut(CGFloat(elapsed / dissolveDuration))
            alpha = 1 - t
            extraScale = 1 + 0.06 * t
            if elapsed >= dissolveDuration {
                startScene(at: time)
                return draw(in: ctx, bounds: bounds, time: time)
            }
        }

        drawBackground(in: ctx, bounds: bounds, dt: dt)
        guard alpha > 0.001 else { return }

        let pos = progress * totalUnits

        // Bake anything that finished since the last frame.
        for i in items.indices where !items[i].committed {
            let s = items[i].stroke
            if (pos - items[i].start) * s.role.drawSpeed >= s.length {
                renderer.commit(s, palette: palette,
                                weight: settings.lineWeight, glow: settings.glow)
                items[i].committed = true
            }
        }

        // Slow drift, eased in so the figure settles rather than lurches.
        let angle = rotationRate * driftTime * smoothstep(driftTime / 3)
        let breath = 1 + 0.004 * sin(driftTime * 0.32)
        let c = CGPoint(x: bounds.midX, y: bounds.midY)

        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: angle)
        ctx.scaleBy(x: breath * extraScale, y: breath * extraScale)
        ctx.translateBy(x: -c.x, y: -c.y)
        ctx.setAlpha(alpha)

        if let image = renderer.canvasImage {
            ctx.saveGState()
            ctx.setBlendMode(.plusLighter)
            ctx.draw(image, in: CGRect(origin: .zero, size: renderer.size))
            ctx.restoreGState()
        }

        for item in items where !item.committed {
            let s = item.stroke
            let advance = (pos - item.start) * s.role.drawSpeed
            guard advance > 0 else { continue }
            renderer.drawLive(s, fraction: advance / max(s.length, 0.0001), in: ctx,
                              palette: palette, weight: settings.lineWeight, glow: settings.glow)
        }
        ctx.restoreGState()
    }

    /// Palettes carry their own near-black ground; fade between them so a scene
    /// change never flashes.
    private func drawBackground(in ctx: CGContext, bounds: CGRect, dt: CGFloat) {
        let target = palette.background.components ?? [0, 0, 0, 1]
        let k = min(1, dt * 0.9)
        ground.0 = lerp(ground.0, target[0], k)
        ground.1 = lerp(ground.1, target.count > 1 ? target[1] : target[0], k)
        ground.2 = lerp(ground.2, target.count > 2 ? target[2] : target[0], k)
        ctx.setFillColor(red: ground.0, green: ground.1, blue: ground.2, alpha: 1)
        ctx.fill(bounds)
    }
}
