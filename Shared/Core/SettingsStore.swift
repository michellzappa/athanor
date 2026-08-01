import CoreGraphics
import Foundation

#if canImport(ScreenSaver)
import ScreenSaver
#endif

/// Shared container for the iOS app and its widget. Must keep the `group.`
/// prefix, and must be registered to the signing team with both bundle ids
/// added to it, or device builds fail to provision.
enum AppGroup {
    static let identifier = "group.com.centaur-labs.athanor"
}

/// One persisted store for every platform. Inside a `.saver` bundle the defaults
/// have to go through ScreenSaverDefaults, because the screen saver host process
/// owns the domain. On iOS they go through the app group, so what you choose in
/// the app is what the widget draws.
final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let figures = "enabledFigures"
        static let pace = "pace"
        static let lineWeight = "lineWeight"
        static let glow = "glow"
        static let showConstruction = "showConstruction"
        static let tint = "tint"
    }

    private let defaults: UserDefaults

    private init() {
        #if canImport(ScreenSaver)
        let module = Bundle(for: SettingsStore.self).bundleIdentifier ?? "com.centaur-labs.athanor"
        defaults = ScreenSaverDefaults(forModuleWithName: module) ?? .standard
        #else
        // Falls back to standard defaults when the entitlement is missing, so an
        // unprovisioned build still runs instead of dying at launch.
        defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        #endif
        defaults.register(defaults: [
            Key.figures: FigureCatalog.all.map(\.id),
            Key.pace: 1.0,
            Key.lineWeight: 1.0,
            Key.glow: 1.0,
            Key.showConstruction: true,
            Key.tint: "auto",
        ])
    }

    /// Filtered against the catalog, so an id left over from an older build can
    /// never empty the rotation.
    var enabledFigureIDs: Set<String> {
        get {
            let stored = Set(defaults.stringArray(forKey: Key.figures) ?? [])
            let known = stored.intersection(FigureCatalog.allIDs)
            return known.isEmpty ? FigureCatalog.allIDs : known
        }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.figures) }
    }

    /// 0.5 draws at half speed, 2.0 at double.
    var pace: CGFloat {
        get { clamp(CGFloat(defaults.double(forKey: Key.pace)), 0.4, 2.5) }
        set { defaults.set(Double(newValue), forKey: Key.pace) }
    }

    var lineWeight: CGFloat {
        get { clamp(CGFloat(defaults.double(forKey: Key.lineWeight)), 0.4, 2.5) }
        set { defaults.set(Double(newValue), forKey: Key.lineWeight) }
    }

    var glow: CGFloat {
        get { clamp(CGFloat(defaults.double(forKey: Key.glow)), 0, 2.0) }
        set { defaults.set(Double(newValue), forKey: Key.glow) }
    }

    var showConstruction: Bool {
        get { defaults.bool(forKey: Key.showConstruction) }
        set { defaults.set(newValue, forKey: Key.showConstruction) }
    }

    var tint: String {
        get { defaults.string(forKey: Key.tint) ?? "auto" }
        set { defaults.set(newValue, forKey: Key.tint) }
    }

    var snapshot: RenderSettings {
        RenderSettings(enabledFigureIDs: enabledFigureIDs,
                       pace: pace,
                       lineWeight: lineWeight,
                       glow: glow,
                       showConstruction: showConstruction,
                       tint: tint)
    }

    func synchronize() { defaults.synchronize() }
}
