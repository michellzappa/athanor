import CoreGraphics
import Foundation

/// Star polygons {n/k}. Each one is a single unbroken path that closes exactly
/// when k is coprime with n, so the whole star draws itself in one continuous
/// line without the pen ever lifting.
enum StarPolygon {
    static let kind = FigureKind(
        id: "star-polygon",
        title: "Star Polygons",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        // 6 is skipped: {6/2} is two triangles, not one closed path.
        let n = rng.pick([5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19])
        let R: CGFloat = 0.92
        let rotation = CGFloat.pi / 2

        func vertex(_ i: Int, radius: CGFloat = R, spin: CGFloat = 0) -> CGPoint {
            CGPoint(angle: rotation + spin + tau * CGFloat(i % n) / CGFloat(n), radius: radius)
        }

        let steps = (2...max(2, (n - 1) / 2)).filter { Geo.gcd(n, $0) == 1 }
        guard !steps.isEmpty else {
            b.polygon(radius: R, sides: n, rotation: rotation, .primary)
            return b.build()
        }
        let chosen = rng.sample(steps, count: rng.int(1...min(3, steps.count))).sorted()

        b.circle(centre: .zero, radius: R, .construction)
        b.advance()
        for i in 0..<n { b.line(.zero, vertex(i), .construction, weight: 0.7) }
        b.advance()
        for i in 0..<n { b.dot(vertex(i), radius: 0.012) }
        b.advance()

        var innermost = R
        for k in chosen {
            var path: [CGPoint] = []
            for i in 0...n { path.append(vertex(i * k)) }
            b.add(path, .primary)
            b.advance()

            if let cross = Geo.lineIntersection(vertex(0), vertex(k), vertex(1), vertex(1 + k)) {
                let inner = cross.length
                if inner > 0.02, inner < innermost {
                    innermost = inner
                    b.circle(centre: .zero, radius: inner, .construction, weight: 0.8)
                    b.advance()
                }
            }
        }

        // A second, smaller star seated in the first, offset by half a step.
        if rng.chance(0.55), innermost < R * 0.85, let k = rng.maybePick(chosen) {
            let spin = CGFloat.pi / CGFloat(n)
            var path: [CGPoint] = []
            for i in 0...n { path.append(vertex(i * k, radius: innermost, spin: spin)) }
            b.add(path, .accent, weight: 0.85)
            b.advance()
        }

        if rng.chance(0.6) {
            b.polygon(radius: R, sides: n, rotation: rotation, .accent, weight: 0.8)
        }
        b.circle(centre: .zero, radius: R * 1.045, .accent, weight: 0.7)

        return b.build(pacing: 0.9, rotationRate: rng.value(-0.02, 0.02))
    }
}
