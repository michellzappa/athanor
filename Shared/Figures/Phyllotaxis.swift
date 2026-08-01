import CoreGraphics
import Foundation

/// Fermat's spiral at the golden angle. Seeds land one at a time and the
/// parastichies — the Fibonacci-numbered spiral arms — are traced over them once
/// the head is full.
enum Phyllotaxis {
    static let kind = FigureKind(
        id: "phyllotaxis",
        title: "Phyllotaxis",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        let n = rng.int(240...420)
        // Sitting a hair off the golden angle is what opens the arms up.
        let divergence = tau * (1 - 1 / goldenRatio) + rng.value(-0.0016, 0.0016)
        let c = 0.94 / CGFloat(n).squareRoot()
        let seedR = c * rng.value(0.34, 0.44)

        func seed(_ k: Int) -> CGPoint {
            CGPoint(angle: CGFloat(k) * divergence, radius: c * CGFloat(k).squareRoot())
        }

        b.circle(centre: .zero, radius: 0.97, .construction, weight: 0.8)
        b.advance()

        let batch = max(12, n / 16)
        for k in 0..<n {
            b.dot(seed(k), radius: seedR)
            if k % batch == batch - 1 { b.advance() }
        }
        b.advance()

        // Parastichies: joining every f-th seed traces one family of arms.
        let families = rng.sample([8, 13, 21, 34], count: rng.int(1...2)).sorted()
        for (index, f) in families.enumerated() {
            for offset in 0..<f {
                var arm: [CGPoint] = []
                var k = offset
                while k < n {
                    arm.append(seed(k))
                    k += f
                }
                if arm.count > 2 { b.add(arm, index == 0 ? .accent : .primary, weight: 0.7) }
            }
            b.advance()
        }

        b.circle(centre: .zero, radius: 0.99, .accent, weight: 0.7)
        b.advance()
        b.dot(.zero, radius: seedR * 1.4)

        return b.build(pacing: 1.15, rotationRate: rng.value(-0.03, 0.03))
    }
}
