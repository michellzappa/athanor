import CoreGraphics
import Foundation

/// Everything the shared core needs to know about user choices. Each platform
/// supplies its own store — ScreenSaverDefaults on the Mac, UserDefaults
/// elsewhere — and hands over one of these.
struct RenderSettings {
    var enabledFigureIDs: Set<String>
    var pace: CGFloat = 1
    var lineWeight: CGFloat = 1
    var glow: CGFloat = 1
    var showConstruction: Bool = true
    /// A palette id, or "auto" to let every scene choose for itself.
    var tint: String = "auto"

    static var `default`: RenderSettings {
        RenderSettings(enabledFigureIDs: Set(FigureCatalog.all.map(\.id)))
    }

    /// Always consumes a draw so that a given seed produces the same figure
    /// whether or not the ink is pinned to one palette.
    func palette(using rng: inout SeededRandom) -> Palette {
        let random = rng.pick(Palette.all)
        return Palette.named(tint) ?? random
    }
}
