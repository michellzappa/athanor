import AppIntents
import Foundation

let anyFigureTitle = "Any figure"
let anyInkTitle = "Any ink"

/// Options come from the catalog rather than a hand-kept enum, so a new figure
/// shows up in the widget's editor the moment it is registered.
struct FigureOptions: DynamicOptionsProvider {
    func results() async throws -> [String] {
        [anyFigureTitle] + FigureCatalog.all.map(\.title)
    }
}

struct InkOptions: DynamicOptionsProvider {
    func results() async throws -> [String] {
        [anyInkTitle] + Palette.all.map(\.title)
    }
}

/// What you get when you long press the widget and choose Edit Widget.
struct ConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Athanor"
    static let description = IntentDescription("Choose which figure the widget draws, and in which ink.")

    // Optional rather than defaulted: pairing a default with an options provider
    // is an iOS 26 initialiser, and unset already means the same thing here.
    @Parameter(title: "Figure", optionsProvider: FigureOptions())
    var figure: String?

    @Parameter(title: "Ink", optionsProvider: InkOptions())
    var ink: String?

    /// nil means let the seed choose from whatever the app has in rotation.
    var figureID: String? {
        FigureCatalog.all.first { $0.title == figure }?.id
    }

    /// The app's own choices are the baseline, through the shared app group.
    /// This widget's figure and ink pin over the top of them when set, so two
    /// widgets on the same screen can hold different figures.
    var settings: RenderSettings {
        var settings = SettingsStore.shared.snapshot
        if let id = Palette.all.first(where: { $0.title == ink })?.id {
            settings.tint = id
        }
        return settings
    }
}
