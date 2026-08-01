#if canImport(UIKit)
import QuartzCore
import UIKit

/// UIKit host for the shared Director. UIKit hands out a y-down context, so the
/// first thing this does is flip it: below that line every platform draws into
/// the same y-up space the figures are authored in.
final class AnimatedFigureView: UIView {
    private let director: Director
    private var link: CADisplayLink?

    init(director: Director) {
        self.director = director
        super.init(frame: .zero)
        isOpaque = true
        backgroundColor = .black
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func skip() { director.skip() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        window == nil ? stop() : start()
    }

    private func start() {
        guard link == nil else { return }
        director.reset()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick() {
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2
        director.configure(size: bounds.size, backingScale: scale)
        director.draw(in: ctx, bounds: CGRect(origin: .zero, size: bounds.size),
                      time: CACurrentMediaTime())
    }
}
#endif
