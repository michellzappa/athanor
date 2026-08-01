import CoreGraphics
import Foundation

/// Overlapping circles on a triangular lattice, each passing through its
/// neighbours' centres. Two or three rings, optionally trimmed at the boundary
/// the way the Osirion wall version is.
enum FlowerOfLife {
    static let kind = FigureKind(
        id: "flower-of-life",
        title: "Flower of Life",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        let rings = rng.int(2...3)
        let r = 1 / CGFloat(rings + 1)
        let boundary = CGFloat(rings + 1) * r
        let trimmed = rng.chance(0.45)

        b.circle(centre: .zero, radius: boundary, .construction)
        b.line(CGPoint(x: -boundary, y: 0), CGPoint(x: boundary, y: 0), .construction)
        b.line(CGPoint(x: 0, y: -boundary), CGPoint(x: 0, y: boundary), .construction)
        b.advance()

        b.circle(centre: .zero, radius: r, .primary, tone: 0.72)
        b.advance()

        let lattice = Geo.hexLattice(rings: rings, spacing: r)
        for ring in 1...rings {
            // Rings recede as they go out, so the seed stays the brightest thing.
            let tone = lerp(0.66, 0.38, CGFloat(ring - 1) / CGFloat(max(rings - 1, 1)))
            for (index, item) in lattice.filter({ $0.ring == ring }).enumerated() {
                // Each circle opens where it faces the seed, alternating hand, so
                // a ring drawn at once never sweeps in lockstep.
                let start = DrawingBuilder.startAngle(for: item.point)
                let sweep: CGFloat = index % 2 == 0 ? tau : -tau
                let pts = DrawingBuilder.arcPoints(centre: item.point, radius: r,
                                                   from: start, to: start + sweep)
                if trimmed {
                    for run in Geo.clip(pts, toRadius: boundary) {
                        b.add(run, .primary, tone: tone)
                    }
                } else {
                    b.add(pts, .primary, tone: tone)
                }
                // The first ring earns its own beat each; outer rings bloom at once.
                if ring == 1 { b.advance() }
            }
            b.advance()
        }

        b.circle(centre: .zero, radius: boundary, .accent)
        if rng.chance(0.6) {
            b.circle(centre: .zero, radius: boundary * 0.965, .accent, weight: 0.7)
        }
        b.advance()

        // The hexagram and hexagon that the first ring already implies.
        if rng.chance(0.55) {
            let seed = lattice.filter { $0.ring == 1 }.map(\.point)
            if seed.count == 6 {
                b.add(seed + [seed[0]], .accent, weight: 0.8)
                b.add([seed[0], seed[2], seed[4], seed[0]], .accent, weight: 0.8)
                b.add([seed[1], seed[3], seed[5], seed[1]], .accent, weight: 0.8)
            }
        }

        return b.build(pacing: rings == 3 ? 1.2 : 1.0,
                       rotationRate: rng.value(-0.014, 0.014))
    }
}
