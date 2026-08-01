import CoreGraphics
import Foundation

/// Draws strokes as luminous ink and keeps the finished ones in an offscreen
/// bitmap. Only the stroke currently being drawn is re-rendered each frame, so a
/// figure with forty thousand sampled points still costs a blit plus one path.
final class InkRenderer {
    private(set) var size: CGSize = .zero
    private var backingScale: CGFloat = 1
    private var canvas: CGContext?
    private var cachedImage: CGImage?

    /// Unit space (radius 1) maps to this many points.
    private(set) var unitScale: CGFloat = 1
    private(set) var centre: CGPoint = .zero

    /// Base stroke width in points before role and user weighting.
    private(set) var baseWidth: CGFloat = 1

    func configure(size: CGSize, backingScale: CGFloat, inset: CGFloat) {
        let changed = size != self.size || backingScale != self.backingScale
        self.size = size
        self.backingScale = max(1, backingScale)
        let minEdge = min(size.width, size.height)
        unitScale = minEdge * inset
        centre = CGPoint(x: size.width / 2, y: size.height / 2)
        baseWidth = max(0.6, minEdge / 1100)
        if changed { rebuildCanvas() }
    }

    private func rebuildCanvas() {
        cachedImage = nil
        let w = Int((size.width * backingScale).rounded())
        let h = Int((size.height * backingScale).rounded())
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            canvas = nil
            return
        }
        let ctx = CGContext(data: nil, width: w, height: h,
                            bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.scaleBy(x: backingScale, y: backingScale)
        ctx?.setLineCap(.round)
        ctx?.setLineJoin(.round)
        canvas = ctx
    }

    func clearCanvas() {
        cachedImage = nil
        // The context is scaled to points, so the view-sized rect covers it all.
        canvas?.clear(CGRect(origin: .zero, size: size))
    }

    var canvasImage: CGImage? {
        if cachedImage == nil { cachedImage = canvas?.makeImage() }
        return cachedImage
    }

    /// Flattens the accumulated ink onto its palette's ground. Used for stills.
    func composite(background: CGColor) -> CGImage? {
        guard let image = canvasImage, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let out = CGContext(data: nil, width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        out.setFillColor(background)
        out.fill(rect)
        out.setBlendMode(.plusLighter)
        out.draw(image, in: rect)
        return out.makeImage()
    }

    func map(_ p: CGPoint) -> CGPoint {
        CGPoint(x: centre.x + p.x * unitScale, y: centre.y + p.y * unitScale)
    }

    func width(for stroke: Stroke, weight: CGFloat) -> CGFloat {
        baseWidth * stroke.role.weight * stroke.weight * weight
    }

    /// Bakes a completed stroke into the offscreen bitmap.
    func commit(_ stroke: Stroke, palette: Palette, weight: CGFloat, glow: CGFloat) {
        guard let canvas else { return }
        render(stroke.points, in: canvas,
               colour: palette.ink(tone: stroke.tone),
               width: width(for: stroke, weight: weight),
               glow: stroke.glow * glow,
               alpha: stroke.alpha)
        cachedImage = nil
    }

    /// Draws a partially complete stroke live, with a bright point at the tip so
    /// the eye follows the compass.
    func drawLive(_ stroke: Stroke, fraction: CGFloat, in ctx: CGContext,
                  palette: Palette, weight: CGFloat, glow: CGFloat) {
        let pts = stroke.prefix(fraction: fraction)
        guard pts.count > 1 else { return }
        let w = width(for: stroke, weight: weight)
        render(pts, in: ctx, colour: palette.ink(tone: stroke.tone),
               width: w, glow: stroke.glow * glow, alpha: stroke.alpha)
        guard stroke.role != .mark, let tip = pts.last else { return }
        let p = map(tip)
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)
        ctx.setFillColor(palette.accent.copy(alpha: 0.5 * min(1, glow)) ?? palette.accent)
        ctx.fillEllipse(in: CGRect(x: p.x - w * 2.4, y: p.y - w * 2.4, width: w * 4.8, height: w * 4.8))
        ctx.setFillColor(palette.accent.copy(alpha: 0.95) ?? palette.accent)
        ctx.fillEllipse(in: CGRect(x: p.x - w * 0.8, y: p.y - w * 0.8, width: w * 1.6, height: w * 1.6))
        ctx.restoreGState()
    }

    /// Every visible stroke goes through here: a wide dim pass, a mid pass, then
    /// the core line, all additive so crossings bloom where the ink overlaps.
    private func render(_ points: [CGPoint], in ctx: CGContext, colour: CGColor,
                        width: CGFloat, glow: CGFloat, alpha: CGFloat) {
        guard points.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: map(points[0]))
        for p in points.dropFirst() { path.addLine(to: map(p)) }

        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setBlendMode(.plusLighter)
        if glow > 0.01 {
            let passes: [(CGFloat, CGFloat)] = [(6.0, 0.045), (2.6, 0.085)]
            for (scale, a) in passes {
                ctx.setStrokeColor(colour.copy(alpha: a * glow * alpha) ?? colour)
                ctx.setLineWidth(width * scale)
                ctx.addPath(path)
                ctx.strokePath()
            }
        }
        ctx.setStrokeColor(colour.copy(alpha: alpha) ?? colour)
        ctx.setLineWidth(width)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }
}
