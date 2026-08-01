import CoreGraphics
import Foundation

// Figures are authored in "unit space": a y-up plane centred on the origin where
// the figure is expected to fit inside the circle of radius 1. The renderer maps
// that circle onto the short edge of whatever display it lands on.

let tau: CGFloat = .pi * 2
let goldenRatio: CGFloat = (1 + CGFloat(5).squareRoot()) / 2
let root3: CGFloat = CGFloat(3).squareRoot()

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

/// Smooth 0→1 ramp, used for eases everywhere so nothing starts or stops abruptly.
func smoothstep(_ t: CGFloat) -> CGFloat {
    let x = clamp(t, 0, 1)
    return x * x * (3 - 2 * x)
}

func easeInOut(_ t: CGFloat) -> CGFloat {
    let x = clamp(t, 0, 1)
    return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
}

extension CGPoint {
    init(angle: CGFloat, radius: CGFloat, around centre: CGPoint = .zero) {
        self.init(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
    }

    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (l: CGPoint, r: CGFloat) -> CGPoint { CGPoint(x: l.x * r, y: l.y * r) }
    static func / (l: CGPoint, r: CGFloat) -> CGPoint { CGPoint(x: l.x / r, y: l.y / r) }

    var length: CGFloat { (x * x + y * y).squareRoot() }
    var angle: CGFloat { atan2(y, x) }

    func distance(to p: CGPoint) -> CGFloat { (self - p).length }

    func rotated(by angle: CGFloat, around centre: CGPoint = .zero) -> CGPoint {
        let d = self - centre
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: centre.x + d.x * c - d.y * s, y: centre.y + d.x * s + d.y * c)
    }

    func scaled(by f: CGFloat, around centre: CGPoint = .zero) -> CGPoint {
        centre + (self - centre) * f
    }
}

enum Geo {
    /// The two points where two circles cross, or an empty array when they miss.
    static func circleIntersections(_ c0: CGPoint, _ r0: CGFloat,
                                    _ c1: CGPoint, _ r1: CGFloat) -> [CGPoint] {
        let d = c0.distance(to: c1)
        guard d > 1e-9, d <= r0 + r1, d >= abs(r0 - r1) else { return [] }
        let a = (r0 * r0 - r1 * r1 + d * d) / (2 * d)
        let hSq = r0 * r0 - a * a
        guard hSq >= 0 else { return [] }
        let h = hSq.squareRoot()
        let base = c0 + (c1 - c0) * (a / d)
        let off = CGPoint(x: -(c1.y - c0.y) * h / d, y: (c1.x - c0.x) * h / d)
        return [base + off, base - off]
    }

    static func lineIntersection(_ a1: CGPoint, _ a2: CGPoint,
                                 _ b1: CGPoint, _ b2: CGPoint) -> CGPoint? {
        let d1 = a2 - a1, d2 = b2 - b1
        let denom = d1.x * d2.y - d1.y * d2.x
        guard abs(denom) > 1e-9 else { return nil }
        let t = ((b1.x - a1.x) * d2.y - (b1.y - a1.y) * d2.x) / denom
        return a1 + d1 * t
    }

    /// Triangular lattice points out to `rings`, tagged with their hex ring index.
    /// Spacing is the centre-to-centre distance, which for overlapping circles of
    /// radius r that pass through each other's centres is exactly r.
    static func hexLattice(rings: Int, spacing: CGFloat) -> [(point: CGPoint, ring: Int)] {
        var out: [(CGPoint, Int)] = []
        for i in -rings...rings {
            for j in -rings...rings {
                let ring = (abs(i) + abs(j) + abs(i + j)) / 2
                if ring > rings { continue }
                let x = (CGFloat(i) + CGFloat(j) / 2) * spacing
                let y = CGFloat(j) * (root3 / 2) * spacing
                out.append((CGPoint(x: x, y: y), ring))
            }
        }
        // Stable, centre-outwards ordering so construction reads as growth.
        return out.sorted {
            $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.angle < $1.0.angle
        }.map { (point: $0.0, ring: $0.1) }
    }

    static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? abs(a) : gcd(b, a % b) }

    /// Splits a polyline into the runs that fall inside a disk, so circles can be
    /// trimmed at a boundary the way a compass drawing would be.
    static func clip(_ points: [CGPoint], toRadius r: CGFloat) -> [[CGPoint]] {
        var runs: [[CGPoint]] = []
        var current: [CGPoint] = []
        for p in points {
            if p.length <= r {
                current.append(p)
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs.filter { $0.count > 1 }
    }
}
