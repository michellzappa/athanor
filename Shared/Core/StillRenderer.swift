import CoreGraphics
import Foundation

/// Draws a whole figure at once instead of over a minute. Same strokes, same
/// palettes, same seeds as the animated path — a still is just the last frame.
enum StillRenderer {
    struct Recipe {
        var figureID: String?
        var seed: UInt64
        var settings: RenderSettings

        /// A recipe nobody has seen before.
        static func random(figureID: String? = nil,
                           settings: RenderSettings = .default) -> Recipe {
            Recipe(figureID: figureID, seed: UInt64.random(in: 1...UInt64.max), settings: settings)
        }

        var kind: FigureKind {
            if let figureID, let match = FigureCatalog.kind(id: figureID) { return match }
            var rng = SeededRandom(seed: seed &* 0x2545F4914F6CDD1D)
            return rng.pick(FigureCatalog.enabled(ids: settings.enabledFigureIDs))
        }

        /// The palette this recipe will render with. Mirrors the first draw
        /// `render` makes, so a host can match its own chrome to the ground
        /// without rendering anything.
        var palette: Palette {
            var rng = SeededRandom(seed: seed)
            return settings.palette(using: &rng)
        }
    }

    /// `inset` is the fraction of the short edge the figure's unit circle fills.
    /// Wallpapers want a little more air than a screen saver does. With `ground`
    /// off the ink comes back on transparency, which is what Lock Screen
    /// accessory widgets need so the system can tint it.
    static func render(_ recipe: Recipe, size: CGSize, scale: CGFloat,
                       inset: CGFloat = 0.40, ground: Bool = true) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        var rng = SeededRandom(seed: recipe.seed)
        let settings = recipe.settings
        let palette = settings.palette(using: &rng)
        var drawing = recipe.kind.build(&rng)
        if !settings.showConstruction {
            drawing.strokes.removeAll { $0.role == .construction }
        }

        let renderer = InkRenderer()
        renderer.configure(size: size, backingScale: scale, inset: inset)
        renderer.clearCanvas()
        for stroke in drawing.strokes {
            renderer.commit(stroke, palette: palette,
                            weight: settings.lineWeight, glow: settings.glow)
        }
        return ground ? renderer.composite(background: palette.background) : renderer.canvasImage
    }
}
