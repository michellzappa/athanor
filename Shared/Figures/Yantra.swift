import CoreGraphics
import Foundation

/// A yantra assembled from the traditional layer stack, working inward: the
/// bhupura with its four gates, circle bands, lotus petals, an interlocking
/// star, and the bindu. Which layers appear, and how many petals or points they
/// carry, is drawn fresh each time.
enum Yantra {
    static let kind = FigureKind(
        id: "yantra",
        title: "Yantra",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        var radius: CGFloat = 0.98

        // Bhupura: the earth-square and its gates.
        if rng.chance(0.85) {
            let half = radius * 0.72
            let gate = half * rng.value(0.30, 0.42)
            let depth = half * rng.value(0.09, 0.15)
            let rims = rng.int(1...3)
            for i in 0..<rims {
                let inset = CGFloat(i) * half * 0.055
                b.add(bhupura(half: half - inset, gate: gate, depth: depth - inset * 0.5),
                      i == 0 ? .accent : .primary, weight: i == 0 ? 1.0 : 0.75)
                b.advance()
            }
            radius = half * 0.94
        }

        // Circle bands.
        let bands = rng.int(1...3)
        for i in 0..<bands {
            b.circle(centre: .zero, radius: radius - CGFloat(i) * radius * 0.035,
                     i == 0 ? .accent : .primary, weight: 0.8)
        }
        radius -= CGFloat(bands) * radius * 0.035
        b.advance()

        // Lotus bands, outer first.
        let lotusBands = rng.int(1...2)
        for band in 0..<lotusBands {
            let petals = rng.pick(band == 0 ? [12, 16, 16, 24] : [8, 8, 12])
            let inner = radius * rng.value(0.66, 0.76)
            let spin = band == 0 ? 0 : CGFloat.pi / CGFloat(petals)
            let spread = (.pi / CGFloat(petals)) * rng.value(0.85, 0.98)
            for i in 0..<petals {
                b.petal(angle: spin + tau * CGFloat(i) / CGFloat(petals),
                        inner: inner, outer: radius, spread: spread, .primary)
            }
            b.advance()
            radius = inner
            b.circle(centre: .zero, radius: radius, .construction, weight: 0.8)
            b.advance()
        }

        // The star at the heart.
        let heart = rng.int(0...2)
        if heart == 0 {
            // Interlocking triangles, alternating point-up and point-down.
            let layers = rng.int(2...4)
            for i in 0..<layers {
                let r = radius * (1 - CGFloat(i) * 0.13)
                let up = i % 2 == 0
                b.polygon(radius: r, sides: 3, rotation: up ? .pi / 2 : -.pi / 2,
                          .primary, weight: 0.95)
                b.advance()
            }
        } else if heart == 1 {
            for i in 0..<2 {
                b.polygon(radius: radius, sides: 3, rotation: i == 0 ? .pi / 2 : -.pi / 2,
                          .primary)
                b.advance()
            }
            b.polygon(radius: radius * 0.5, sides: 6, rotation: 0, .construction, weight: 0.8)
            b.advance()
        } else {
            let n = rng.pick([8, 10, 12])
            let k = n == 8 ? 3 : (n == 10 ? 3 : 5)
            var path: [CGPoint] = []
            for i in 0...n {
                path.append(CGPoint(angle: .pi / 2 + tau * CGFloat((i * k) % n) / CGFloat(n),
                                    radius: radius))
            }
            b.add(path, .primary)
            b.advance()
        }

        // Inner circle and bindu.
        let core = radius * rng.value(0.26, 0.40)
        b.circle(centre: .zero, radius: core, .accent, weight: 0.85)
        b.advance()
        if rng.chance(0.7) {
            b.polygon(radius: core * 0.8, sides: 3, rotation: rng.chance(0.5) ? .pi / 2 : -.pi / 2,
                      .primary, weight: 0.9)
            b.advance()
        }
        for i in 0..<3 {
            b.dot(.zero, radius: core * (0.10 + CGFloat(i) * 0.045))
        }

        return b.build(pacing: 1.1, rotationRate: rng.value(-0.005, 0.005))
    }

    /// The square enclosure with a gate at the middle of each side.
    private static func bhupura(half s: CGFloat, gate g: CGFloat, depth d: CGFloat) -> [CGPoint] {
        var pts: [CGPoint] = []
        for side in 0..<4 {
            let a = CGFloat(side) * .pi / 2
            let local = [
                CGPoint(x: -s, y: -s),
                CGPoint(x: -g / 2, y: -s),
                CGPoint(x: -g / 2, y: -s - d),
                CGPoint(x: g / 2, y: -s - d),
                CGPoint(x: g / 2, y: -s),
            ]
            pts.append(contentsOf: local.map { $0.rotated(by: a) })
        }
        pts.append(pts[0])
        return pts
    }
}
