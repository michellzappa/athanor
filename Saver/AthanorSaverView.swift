import AppKit
import QuartzCore
import ScreenSaver

/// Principal class of the bundle. Everything interesting lives in Director; this
/// owns only the frame clock and the options sheet.
@objc(ATAthanorView)
final class AthanorView: ScreenSaverView {
    private let director: Director

    override init?(frame: NSRect, isPreview: Bool) {
        director = Director(compact: isPreview, settings: { SettingsStore.shared.snapshot })
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
    }

    required init?(coder: NSCoder) {
        director = Director(compact: false, settings: { SettingsStore.shared.snapshot })
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 30.0
    }

    override var isOpaque: Bool { true }

    override func startAnimation() {
        director.reset()
        super.startAnimation()
    }

    override func animateOneFrame() {
        setNeedsDisplay(bounds)
    }

    override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        director.configure(size: bounds.size, backingScale: window?.backingScaleFactor ?? 2)
        director.draw(in: ctx, bounds: bounds, time: CACurrentMediaTime())
    }

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        ConfigureSheetController.shared.prepared()
    }
}
