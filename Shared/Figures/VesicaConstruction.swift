import CoreGraphics
import Foundation

/// Two circles, each through the other's centre. Either the single classical
/// construction with its triangles and root-three proportions, or a chain of
/// them running across the plate.
enum VesicaConstruction {
    static let kind = FigureKind(
        id: "vesica",
        title: "Vesica Piscis",
        collection: .core
    ) { rng in
        rng.chance(0.55) ? single(&rng) : chain(&rng)
    }

    private static func single(_ rng: inout SeededRandom) -> Drawing {
        let b = DrawingBuilder()
        let r: CGFloat = 0.62
        let a = CGPoint(x: -r / 2, y: 0)
        let c = CGPoint(x: r / 2, y: 0)
        let h = r * root3 / 2
        let top = CGPoint(x: 0, y: h)
        let bottom = CGPoint(x: 0, y: -h)

        b.line(CGPoint(x: -r * 1.5, y: 0), CGPoint(x: r * 1.5, y: 0), .construction)
        b.advance()
        b.dot(a, radius: 0.012)
        b.dot(c, radius: 0.012)
        b.advance()

        b.circle(centre: a, radius: r, .primary)
        b.advance()
        b.circle(centre: c, radius: r, .primary)
        b.advance()

        b.dot(top, radius: 0.012)
        b.dot(bottom, radius: 0.012)
        b.advance()

        // The lens itself, traced out of the two arcs that bound it.
        b.arc(centre: a, radius: r, from: -.pi / 3, to: .pi / 3, .accent)
        b.arc(centre: c, radius: r, from: tau / 3, to: tau * 2 / 3, .accent)
        b.advance()

        b.add([a, c, top, a], .primary, weight: 0.9)
        b.add([a, c, bottom, a], .primary, weight: 0.9)
        b.advance()

        b.line(top, bottom, .construction)
        if rng.chance(0.6) {
            // The root-three rectangle the vesica measures out.
            b.add([CGPoint(x: -r, y: h), CGPoint(x: r, y: h),
                   CGPoint(x: r, y: -h), CGPoint(x: -r, y: -h),
                   CGPoint(x: -r, y: h)], .construction)
        }
        b.advance()

        if rng.chance(0.7) {
            b.circle(centre: .zero, radius: r * 1.5, .accent, weight: 0.8)
        }
        if rng.chance(0.5) {
            b.polygon(radius: h, sides: 6, rotation: .pi / 2, .accent, weight: 0.8)
        }

        return b.build(pacing: 0.85, rotationRate: rng.value(-0.012, 0.012))
    }

    private static func chain(_ rng: inout SeededRandom) -> Drawing {
        let b = DrawingBuilder()
        let n = rng.int(3...6)
        let r = 1.85 / CGFloat(n + 1)
        let h = r * root3 / 2
        let x0 = -CGFloat(n - 1) * r / 2
        let centres = (0..<n).map { CGPoint(x: x0 + CGFloat($0) * r, y: 0) }

        b.line(CGPoint(x: x0 - r * 1.2, y: 0), CGPoint(x: -x0 + r * 1.2, y: 0), .construction)
        b.advance()

        for (i, c) in centres.enumerated() {
            b.circle(centre: c, radius: r, .primary, tone: 0.62, clockwise: i % 2 == 1)
            b.advance()
        }

        for i in 0..<(n - 1) {
            let a = centres[i], c = centres[i + 1]
            b.arc(centre: a, radius: r, from: -.pi / 3, to: .pi / 3, .accent)
            b.arc(centre: c, radius: r, from: tau / 3, to: tau * 2 / 3, .accent)
            let mid = CGPoint(x: (a.x + c.x) / 2, y: 0)
            b.line(CGPoint(x: mid.x, y: -h), CGPoint(x: mid.x, y: h), .construction)
        }
        b.advance()

        if rng.chance(0.6) {
            b.line(CGPoint(x: x0 - r, y: h), CGPoint(x: -x0 + r, y: h), .construction)
            b.line(CGPoint(x: x0 - r, y: -h), CGPoint(x: -x0 + r, y: -h), .construction)
        }

        return b.build(pacing: 0.9, rotationRate: rng.value(-0.006, 0.006))
    }
}
