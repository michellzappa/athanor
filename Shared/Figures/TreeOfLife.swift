import CoreGraphics
import Foundation

/// The Kircher arrangement: ten sephirot on three pillars, joined by the
/// twenty-two paths, closing with the lightning flash from crown to kingdom.
enum TreeOfLife {
    static let kind = FigureKind(
        id: "tree-of-life",
        title: "Tree of Life",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        let xs: CGFloat = 0.26
        // Six levels tall, centred, and sized so the overlay circles below land
        // exactly on the unit circle rather than off the top of the screen.
        let ys: CGFloat = 0.25
        let top = 3 * ys
        let nodeR: CGFloat = 0.07

        func node(_ i: Int, _ j: Int) -> CGPoint {
            CGPoint(x: CGFloat(i) * xs, y: top - CGFloat(j) * ys)
        }

        //                        keter  chokmah binah chesed gevurah tiferet
        let sephirot: [CGPoint] = [node(0, 0), node(1, 1), node(-1, 1), node(1, 2), node(-1, 2), node(0, 3),
        //                        netzach hod        yesod      malkuth
                                   node(1, 4), node(-1, 4), node(0, 5), node(0, 6)]
        let daat = node(0, 2)

        let paths: [(Int, Int)] = [
            (0, 1), (0, 2), (0, 5), (1, 2), (1, 3), (1, 5), (2, 4), (2, 5),
            (3, 4), (3, 5), (3, 6), (4, 5), (4, 7), (5, 6), (5, 7), (5, 8),
            (6, 7), (6, 8), (6, 9), (7, 8), (7, 9), (8, 9),
        ]

        // Three pillars and the level lines they hang from.
        for x in [-xs, 0, xs] {
            b.line(CGPoint(x: x, y: top + 0.05), CGPoint(x: x, y: -top - 0.05),
                   .construction, weight: 0.7)
        }
        b.advance()
        for j in 0...6 {
            b.line(CGPoint(x: -xs * 1.35, y: top - CGFloat(j) * ys),
                   CGPoint(x: xs * 1.35, y: top - CGFloat(j) * ys), .construction, weight: 0.5)
        }
        b.advance()

        // The overlapping circles the tree is cut from.
        if rng.chance(0.5) {
            for p in sephirot {
                b.circle(centre: p, radius: ys, .construction, weight: 0.5)
            }
            b.advance()
        }

        for (i, p) in sephirot.enumerated() {
            b.circle(centre: p, radius: nodeR, .primary, tone: lerp(0.75, 0.5, CGFloat(i) / 9),
                     clockwise: i % 2 == 1)
            b.advance()
        }

        if rng.chance(0.6) {
            b.circle(centre: daat, radius: nodeR * 0.9, .construction, weight: 0.9)
            b.advance()
        }

        // Paths, shortened so they meet the rims rather than the centres, and
        // released a few at a time so the tree fills in from the crown down.
        for (index, pair) in paths.enumerated() {
            let p = sephirot[pair.0], q = sephirot[pair.1]
            let d = q - p
            let unit = d / max(d.length, 0.0001)
            b.line(p + unit * nodeR, q - unit * nodeR, .primary, weight: 0.8)
            if index % 3 == 2 { b.advance() }
        }
        b.advance()

        if rng.chance(0.75) {
            b.add(sephirot, .accent, weight: 1.1)
            b.advance()
        }

        for p in sephirot { b.dot(p, radius: 0.011) }

        return b.build(pacing: 1.0, rotationRate: 0)
    }
}
