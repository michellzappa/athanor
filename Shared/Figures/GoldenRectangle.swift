import CoreGraphics
import Foundation

/// The golden rectangle cut down into squares, each carrying its quarter arc,
/// with the true logarithmic spiral laid over the arcs that approximate it. The
/// eye of the spiral is where the two rectangle diagonals cross.
enum GoldenRectangle {
    static let kind = FigureKind(
        id: "golden-rectangle",
        title: "Golden Section",
        collection: .core
    ) { rng in
        let b = DrawingBuilder()
        let w: CGFloat = 1.55
        let h = w / goldenRatio
        let x0 = -w / 2, y0 = -h / 2
        var x = x0, y = y0, ww = w, hh = h
        let steps = rng.int(8...11)
        let flip: CGFloat = rng.chance(0.5) ? 1 : -1

        func place(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * flip, y: p.y) }

        let corners = [CGPoint(x: x0, y: y0), CGPoint(x: x0 + w, y: y0),
                       CGPoint(x: x0 + w, y: y0 + h), CGPoint(x: x0, y: y0 + h)]
        b.add((corners + [corners[0]]).map(place), .primary)
        b.advance()

        // Diagonal of the whole rectangle, and of what remains once the first
        // square is gone. They are perpendicular and meet at the eye.
        let d1 = (CGPoint(x: x0, y: y0 + h), CGPoint(x: x0 + w, y: y0))
        let d2 = (CGPoint(x: x0 + h, y: y0), CGPoint(x: x0 + w, y: y0 + h))
        b.line(place(d1.0), place(d1.1), .construction, weight: 0.8)
        b.line(place(d2.0), place(d2.1), .construction, weight: 0.8)
        b.advance()
        let eye = Geo.lineIntersection(d1.0, d1.1, d2.0, d2.1).map(place)

        var spiralStart: CGPoint?

        for i in 0..<steps {
            let s = min(ww, hh)
            guard s > 0.004 else { break }
            var sq = CGRect(x: x, y: y, width: s, height: s)
            let centre: CGPoint
            let cut: (CGPoint, CGPoint)

            switch i % 4 {
            case 0:                                   // square taken off the left
                centre = CGPoint(x: sq.maxX, y: sq.minY)
                cut = (CGPoint(x: sq.maxX, y: sq.minY), CGPoint(x: sq.maxX, y: sq.maxY))
                x += s; ww -= s
            case 1:                                   // off the top
                sq = CGRect(x: x, y: y + hh - s, width: s, height: s)
                centre = CGPoint(x: sq.minX, y: sq.minY)
                cut = (CGPoint(x: sq.minX, y: sq.minY), CGPoint(x: sq.maxX, y: sq.minY))
                hh -= s
            case 2:                                   // off the right
                sq = CGRect(x: x + ww - s, y: y, width: s, height: s)
                centre = CGPoint(x: sq.minX, y: sq.maxY)
                cut = (CGPoint(x: sq.minX, y: sq.minY), CGPoint(x: sq.minX, y: sq.maxY))
                ww -= s
            default:                                  // off the bottom
                centre = CGPoint(x: sq.maxX, y: sq.maxY)
                cut = (CGPoint(x: sq.minX, y: sq.maxY), CGPoint(x: sq.maxX, y: sq.maxY))
                y += s; hh -= s
            }

            b.line(place(cut.0), place(cut.1), .construction, weight: 0.8)
            let from = CGFloat.pi - CGFloat(i) * .pi / 2
            let arc = DrawingBuilder.arcPoints(centre: centre, radius: s,
                                               from: from, to: from - .pi / 2, minSamples: 32)
            b.add(arc.map(place), .primary)
            if i == 0 { spiralStart = place(arc[0]) }
            b.advance()
        }

        if let eye, let start = spiralStart {
            b.dot(eye, radius: 0.013)
            b.advance()
            let r0 = start.distance(to: eye)
            let a0 = (start - eye).angle
            let growth = log(goldenRatio) / (CGFloat.pi / 2)
            b.curve(samples: 460, .accent) { t in
                let theta = a0 - flip * t * tau * 3.4
                return eye + CGPoint(angle: theta, radius: r0 * exp(growth * flip * (theta - a0)))
            }
        }

        return b.build(pacing: 0.95, rotationRate: rng.value(-0.008, 0.008))
    }
}
