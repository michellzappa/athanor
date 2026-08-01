import CoreGraphics
import Foundation

enum StrokeRole {
    /// Compass arcs and guides. Faint, drawn fast, hidden entirely if the user
    /// turns construction lines off.
    case construction
    case primary
    case accent
    /// Dots, bindus, node markers. Drawn near-instantly.
    case mark

    /// How fast this role draws, in unit-lengths per unit of timeline position.
    var drawSpeed: CGFloat {
        switch self {
        case .construction: return 2.2
        case .primary: return 1.0
        case .accent: return 1.3
        case .mark: return 6.0
        }
    }

    var weight: CGFloat {
        switch self {
        case .construction: return 0.55
        case .primary: return 1.0
        case .accent: return 1.25
        case .mark: return 1.6
        }
    }

    var glow: CGFloat {
        switch self {
        case .construction: return 0.25
        case .primary: return 1.0
        case .accent: return 1.4
        case .mark: return 1.6
        }
    }

    /// Where this role sits on the palette ramp by default. Figures override it
    /// per stroke to grade a family — Metatron's chords darkest at the shortest
    /// span, brightest at the longest.
    var tone: CGFloat {
        switch self {
        case .construction: return 0.0
        case .primary: return 0.55
        case .accent: return 1.0
        case .mark: return 0.95
        }
    }
}

/// A polyline in unit space. Everything — circles, arcs, spirals — is sampled
/// down to one of these so that partial drawing is a single code path.
struct Stroke {
    let points: [CGPoint]
    let role: StrokeRole
    let group: Int
    let weight: CGFloat
    /// Position on the palette ramp, 0 faintest to 1 brightest.
    let tone: CGFloat
    /// Cumulative arc length at each point; last element is the total.
    let cumulative: [CGFloat]

    var length: CGFloat { cumulative.last ?? 0 }

    /// Alpha and glow both ride the tone, so a graded family separates by
    /// weight of ink as well as by hue.
    var alpha: CGFloat { 0.55 + 0.45 * clamp(tone, 0, 1) }
    var glow: CGFloat { role.glow * (0.45 + 0.75 * clamp(tone, 0, 1)) }

    init(points: [CGPoint], role: StrokeRole, group: Int,
         weight: CGFloat = 1, tone: CGFloat? = nil) {
        self.points = points
        self.role = role
        self.group = group
        self.weight = weight
        self.tone = tone ?? role.tone
        var acc: [CGFloat] = [0]
        acc.reserveCapacity(points.count)
        var total: CGFloat = 0
        for i in 1..<max(points.count, 1) {
            total += points[i].distance(to: points[i - 1])
            acc.append(total)
        }
        cumulative = acc
    }

    /// The leading portion of the stroke, with the final point interpolated so
    /// the tip advances smoothly instead of snapping between samples.
    func prefix(fraction: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        if fraction >= 1 { return points }
        if fraction <= 0 { return [] }
        let target = length * fraction
        var out: [CGPoint] = [points[0]]
        for i in 1..<points.count {
            if cumulative[i] < target {
                out.append(points[i])
            } else {
                let span = cumulative[i] - cumulative[i - 1]
                let t = span > 1e-9 ? (target - cumulative[i - 1]) / span : 0
                out.append(points[i - 1] + (points[i] - points[i - 1]) * t)
                break
            }
        }
        return out
    }
}

struct Drawing {
    var strokes: [Stroke]
    /// Multiplies the base construction duration; dense figures earn more time.
    var pacing: CGFloat = 1
    /// Radians per second of drift once the figure is complete.
    var rotationRate: CGFloat = 0
}

/// Collects strokes in construction order. `advance()` closes the current group;
/// strokes sharing a group are drawn simultaneously, groups run in sequence.
final class DrawingBuilder {
    private(set) var strokes: [Stroke] = []
    private var group = 0

    func advance() { group += 1 }

    @discardableResult
    func add(_ points: [CGPoint], _ role: StrokeRole = .primary, weight: CGFloat = 1,
             tone: CGFloat? = nil, group override: Int? = nil) -> DrawingBuilder {
        guard points.count > 1 else { return self }
        strokes.append(Stroke(points: points, role: role, group: override ?? group,
                              weight: weight, tone: tone))
        return self
    }

    func line(_ a: CGPoint, _ b: CGPoint, _ role: StrokeRole = .primary, weight: CGFloat = 1,
              tone: CGFloat? = nil, group override: Int? = nil) {
        add([a, b], role, weight: weight, tone: tone, group: override)
    }

    func arc(centre: CGPoint, radius: CGFloat, from: CGFloat, to: CGFloat,
             _ role: StrokeRole = .primary, weight: CGFloat = 1,
             tone: CGFloat? = nil, group override: Int? = nil) {
        add(Self.arcPoints(centre: centre, radius: radius, from: from, to: to),
            role, weight: weight, tone: tone, group: override)
    }

    /// With no explicit `phase` the pen starts where the circle faces the
    /// origin, so a ring of circles never opens from the same clock position.
    /// `clockwise` mirrors the sweep; alternating it across a ring reads as
    /// breathing rather than as a machine.
    func circle(centre: CGPoint, radius: CGFloat, _ role: StrokeRole = .primary,
                weight: CGFloat = 1, tone: CGFloat? = nil,
                phase: CGFloat? = nil, clockwise: Bool = false, group override: Int? = nil) {
        let start = phase ?? Self.startAngle(for: centre)
        add(Self.arcPoints(centre: centre, radius: radius,
                           from: start, to: start + (clockwise ? -tau : tau)),
            role, weight: weight, tone: tone, group: override)
    }

    func polygon(centre: CGPoint = .zero, radius: CGFloat, sides: Int, rotation: CGFloat = 0,
                 _ role: StrokeRole = .primary, weight: CGFloat = 1,
                 tone: CGFloat? = nil, group override: Int? = nil) {
        guard sides >= 3 else { return }
        var pts = (0...sides).map {
            CGPoint(angle: rotation + tau * CGFloat($0) / CGFloat(sides), radius: radius, around: centre)
        }
        pts[sides] = pts[0]
        add(pts, role, weight: weight, tone: tone, group: override)
    }

    func dot(_ centre: CGPoint, radius: CGFloat, _ role: StrokeRole = .mark,
             tone: CGFloat? = nil, group override: Int? = nil) {
        add(Self.arcPoints(centre: centre, radius: radius, from: 0, to: tau, minSamples: 14),
            role, weight: 1, tone: tone, group: override)
    }

    /// Samples an arbitrary parametric curve over t in 0...1.
    func curve(samples: Int, _ role: StrokeRole = .primary, weight: CGFloat = 1,
               tone: CGFloat? = nil, group override: Int? = nil, _ f: (CGFloat) -> CGPoint) {
        guard samples > 1 else { return }
        let pts = (0...samples).map { f(CGFloat($0) / CGFloat(samples)) }
        add(pts, role, weight: weight, tone: tone, group: override)
    }

    /// A lens/petal outline: up one side and back down the other.
    func petal(angle: CGFloat, inner: CGFloat, outer: CGFloat, spread: CGFloat,
               _ role: StrokeRole = .primary, weight: CGFloat = 1,
               tone: CGFloat? = nil, group override: Int? = nil) {
        let steps = 26
        var pts: [CGPoint] = []
        for side in [CGFloat(1), CGFloat(-1)] {
            let range = side > 0 ? Array(0...steps) : Array((0...steps).reversed())
            for i in range {
                let t = CGFloat(i) / CGFloat(steps)
                let a = angle + side * spread * sin(.pi * t)
                pts.append(CGPoint(angle: a, radius: lerp(inner, outer, t)))
            }
        }
        pts.append(pts[0])
        add(pts, role, weight: weight, tone: tone, group: override)
    }

    func build(pacing: CGFloat = 1, rotationRate: CGFloat = 0) -> Drawing {
        Drawing(strokes: strokes, pacing: pacing, rotationRate: rotationRate)
    }

    /// Where a compass would touch down: the point on the circle nearest the
    /// figure's centre. Degenerate at the origin, where the top is used instead.
    static func startAngle(for centre: CGPoint, facing target: CGPoint = .zero) -> CGFloat {
        let d = target - centre
        return d.length < 1e-6 ? .pi / 2 : d.angle
    }

    static func arcPoints(centre: CGPoint, radius: CGFloat, from: CGFloat, to: CGFloat,
                          minSamples: Int = 24) -> [CGPoint] {
        let sweep = to - from
        let samples = max(minSamples, Int(abs(sweep) / tau * 200))
        return (0...samples).map {
            CGPoint(angle: from + sweep * CGFloat($0) / CGFloat(samples), radius: radius, around: centre)
        }
    }
}
