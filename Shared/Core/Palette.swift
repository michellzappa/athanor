import CoreGraphics
import Foundation

/// Ink on black. The background is never pure #000 — a trace of colour in the
/// ground is what stops the whole thing reading as a flat void on an OLED panel.
struct Palette {
    let id: String
    let title: String
    let background: CGColor
    let construction: CGColor
    let primary: CGColor
    let accent: CGColor

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    static let bone = Palette(
        id: "bone", title: "Bone",
        background: rgb(6, 6, 8),
        construction: rgb(96, 98, 108),
        primary: rgb(238, 233, 222),
        accent: rgb(255, 252, 244))

    static let gold = Palette(
        id: "gold", title: "Gold Leaf",
        background: rgb(9, 7, 5),
        construction: rgb(104, 84, 52),
        primary: rgb(226, 190, 122),
        accent: rgb(255, 226, 160))

    static let verdigris = Palette(
        id: "verdigris", title: "Verdigris",
        background: rgb(4, 9, 9),
        construction: rgb(58, 96, 94),
        primary: rgb(158, 216, 205),
        accent: rgb(214, 245, 232))

    static let indigo = Palette(
        id: "indigo", title: "Indigo",
        background: rgb(5, 6, 12),
        construction: rgb(72, 84, 124),
        primary: rgb(178, 194, 240),
        accent: rgb(226, 232, 255))

    static let ember = Palette(
        id: "ember", title: "Ember",
        background: rgb(10, 6, 6),
        construction: rgb(110, 68, 58),
        primary: rgb(232, 168, 132),
        accent: rgb(255, 214, 178))

    static let all: [Palette] = [bone, gold, verdigris, indigo, ember]

    static func named(_ id: String) -> Palette? { all.first { $0.id == id } }

    /// The palette as a continuous ramp rather than three fixed inks. A figure
    /// grades families of strokes along it — dimmest scaffolding at 0, the
    /// brightest structural lines at 1 — and the hue shifts with the tone
    /// because the three stops are already tints of one another.
    func ink(tone: CGFloat) -> CGColor {
        let t = clamp(tone, 0, 1)
        return t < 0.5
            ? Palette.blend(construction, primary, t * 2)
            : Palette.blend(primary, accent, (t - 0.5) * 2)
    }

    static func blend(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
        guard let ca = a.components, let cb = b.components, ca.count >= 3, cb.count >= 3 else {
            return t < 0.5 ? a : b
        }
        return CGColor(srgbRed: lerp(ca[0], cb[0], t),
                       green: lerp(ca[1], cb[1], t),
                       blue: lerp(ca[2], cb[2], t),
                       alpha: 1)
    }
}
