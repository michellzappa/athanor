import AppKit
import Foundation

/// The options sheet, built in code so there is no nib to keep in sync. The
/// figure list is generated from FigureCatalog, so a new figure needs no work
/// here at all.
final class ConfigureSheetController: NSObject {
    static let shared = ConfigureSheetController()

    private var figureBoxes: [String: NSButton] = [:]
    private var paceSlider = NSSlider()
    private var weightSlider = NSSlider()
    private var glowSlider = NSSlider()
    private var constructionBox = NSButton()
    private var tintPopup = NSPopUpButton()
    private lazy var window: NSWindow = makeWindow()

    func prepared() -> NSWindow {
        let w = window
        loadValues()
        return w
    }

    // MARK: - Building

    private func makeWindow() -> NSWindow {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(title("Athanor", size: 15, bold: true))
        stack.addArrangedSubview(title("A figure is constructed, held, then dissolved. "
                                       + "Pick which ones take a turn.", size: 11, dim: true))

        for entry in FigureCatalog.byCollection {
            stack.addArrangedSubview(separator())
            stack.addArrangedSubview(title(entry.collection.title.uppercased(), size: 10,
                                           bold: true, dim: true))
            for kind in entry.kinds {
                let box = NSButton(checkboxWithTitle: kind.title, target: nil, action: nil)
                figureBoxes[kind.id] = box
                stack.addArrangedSubview(box)
            }
        }

        stack.addArrangedSubview(separator())
        paceSlider = slider(min: 0.4, max: 2.5)
        weightSlider = slider(min: 0.4, max: 2.5)
        glowSlider = slider(min: 0, max: 2)
        stack.addArrangedSubview(row("Pace", paceSlider))
        stack.addArrangedSubview(row("Line weight", weightSlider))
        stack.addArrangedSubview(row("Glow", glowSlider))

        tintPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        tintPopup.addItem(withTitle: "Automatic")
        tintPopup.lastItem?.representedObject = "auto"
        for palette in Palette.all {
            tintPopup.addItem(withTitle: palette.title)
            tintPopup.lastItem?.representedObject = palette.id
        }
        stack.addArrangedSubview(row("Ink", tintPopup))

        constructionBox = NSButton(checkboxWithTitle: "Show construction lines",
                                   target: nil, action: nil)
        stack.addArrangedSubview(constructionBox)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        let done = NSButton(title: "Done", target: self, action: #selector(done))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(), cancel, done])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(buttons)

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        let window = NSWindow(contentRect: content.frame,
                              styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.title = "Athanor"
        window.contentView = content
        return window
    }

    private func title(_ text: String, size: CGFloat, bold: Bool = false,
                       dim: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? .systemFont(ofSize: size, weight: .semibold) : .systemFont(ofSize: size)
        label.textColor = dim ? .secondaryLabelColor : .labelColor
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 376
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func slider(min lo: Double, max hi: Double) -> NSSlider {
        let s = NSSlider(value: 1, minValue: lo, maxValue: hi, target: nil, action: nil)
        s.isContinuous = true
        return s
    }

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let text = title(label, size: 12)
        text.alignment = .right
        text.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let stack = NSStackView(views: [text, control])
        stack.orientation = .horizontal
        stack.spacing = 12
        text.widthAnchor.constraint(equalToConstant: 92).isActive = true
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        return stack
    }

    // MARK: - Values

    private func loadValues() {
        let prefs = SettingsStore.shared
        let enabled = prefs.enabledFigureIDs
        for (id, box) in figureBoxes { box.state = enabled.contains(id) ? .on : .off }
        paceSlider.doubleValue = Double(prefs.pace)
        weightSlider.doubleValue = Double(prefs.lineWeight)
        glowSlider.doubleValue = Double(prefs.glow)
        constructionBox.state = prefs.showConstruction ? .on : .off
        let tint = prefs.tint
        let index = tintPopup.itemArray.firstIndex { ($0.representedObject as? String) == tint }
        tintPopup.selectItem(at: index ?? 0)
    }

    @objc private func done() {
        let prefs = SettingsStore.shared
        let picked = Set(figureBoxes.filter { $0.value.state == .on }.map(\.key))
        // Everything off would leave nothing to draw; treat it as everything on.
        prefs.enabledFigureIDs = picked.isEmpty ? Set(FigureCatalog.all.map(\.id)) : picked
        prefs.pace = CGFloat(paceSlider.doubleValue)
        prefs.lineWeight = CGFloat(weightSlider.doubleValue)
        prefs.glow = CGFloat(glowSlider.doubleValue)
        prefs.showConstruction = constructionBox.state == .on
        prefs.tint = (tintPopup.selectedItem?.representedObject as? String) ?? "auto"
        prefs.synchronize()
        close()
    }

    @objc private func cancel() {
        close()
    }

    private func close() {
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
    }
}
