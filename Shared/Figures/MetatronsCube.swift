import CoreGraphics
import Foundation

/// The Fruit of Life — thirteen circles — with every centre joined to every
/// other. The seventy-eight lines arrive in bands of equal length, which is what
/// makes the hidden cube surface a layer at a time.
enum MetatronsCube {
    static let kind = FigureKind(
        id: "metatrons-cube",
        title: "Metatron's Cube",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        let r: CGFloat = 1 / 4.62
        let spin = rng.chance(0.5) ? CGFloat.pi / 6 : 0

        var centres: [CGPoint] = [.zero]
        for k in 0..<6 {
            centres.append(CGPoint(angle: spin + tau * CGFloat(k) / 6, radius: 2 * r))
        }
        for k in 0..<6 {
            centres.append(CGPoint(angle: spin + .pi / 6 + tau * CGFloat(k) / 6, radius: 2 * root3 * r))
        }

        b.circle(centre: .zero, radius: 2 * root3 * r + r, .construction)
        b.advance()

        // The circles sit back so the line structure can read on top of them.
        b.circle(centre: centres[0], radius: r, .primary, weight: 0.9, tone: 0.34)
        b.advance()
        for (i, c) in centres[1...6].enumerated() {
            b.circle(centre: c, radius: r, .primary, weight: 0.9, tone: 0.34,
                     clockwise: i % 2 == 1)
        }
        b.advance()
        for (i, c) in centres[7...12].enumerated() {
            b.circle(centre: c, radius: r, .primary, weight: 0.9, tone: 0.30,
                     clockwise: i % 2 == 0)
        }
        b.advance()

        // Group the 78 chords by length so equal-length bands appear together,
        // shortest first, and grade the bands up the palette as they lengthen.
        // The short interior chords stay as scaffolding; the long spans that
        // carry the cube arrive last and brightest.
        var bands: [CGFloat: [(CGPoint, CGPoint)]] = [:]
        for i in 0..<centres.count {
            for j in (i + 1)..<centres.count {
                let d = (centres[i].distance(to: centres[j]) / r * 100).rounded() / 100
                bands[d, default: []].append((centres[i], centres[j]))
            }
        }
        let keys = bands.keys.sorted()
        for (index, key) in keys.enumerated() {
            let t = keys.count > 1 ? CGFloat(index) / CGFloat(keys.count - 1) : 1
            let tone = lerp(0.22, 0.82, t)
            let weight = lerp(0.6, 0.95, t)
            for (p, q) in bands[key] ?? [] {
                b.line(p, q, .primary, weight: weight, tone: tone)
            }
            b.advance()
        }

        // The star tetrahedron the outer ring carries, at the top of the ramp.
        let outer = Array(centres[7...12])
        b.add([outer[0], outer[2], outer[4], outer[0]], .accent)
        b.add([outer[1], outer[3], outer[5], outer[1]], .accent)
        b.advance()
        b.add(outer + [outer[0]], .accent, weight: 0.9, tone: 0.88)

        return b.build(pacing: 1.25, rotationRate: rng.value(-0.010, 0.010))
    }
}
