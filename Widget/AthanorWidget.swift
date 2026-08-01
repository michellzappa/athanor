import SwiftUI
import UIKit
import WidgetKit

struct FigureEntry: TimelineEntry {
    let date: Date
    let recipe: StillRenderer.Recipe
}

/// One figure per hour. The seed is derived from the hour itself, so the same
/// hour always yields the same figure no matter how often WidgetKit reloads,
/// and the widget never flickers between two drawings inside one slot.
struct FigureProvider: AppIntentTimelineProvider {
    private static let hoursAhead = 6

    func placeholder(in context: Context) -> FigureEntry {
        FigureEntry(date: Date(),
                    recipe: StillRenderer.Recipe(figureID: FlowerOfLife.kind.id,
                                                 seed: 7, settings: .default))
    }

    func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> FigureEntry {
        entry(at: Date(), configuration)
    }

    func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<FigureEntry> {
        let now = Date()
        let entries = (0..<Self.hoursAhead).map {
            entry(at: now.addingTimeInterval(Double($0) * 3600), configuration)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(at date: Date, _ configuration: ConfigurationIntent) -> FigureEntry {
        let hour = UInt64(max(0, date.timeIntervalSince1970) / 3600)
        return FigureEntry(date: date,
                           recipe: StillRenderer.Recipe(figureID: configuration.figureID,
                                                        seed: hour &* 0x9E3779B97F4A7C15 &+ 1,
                                                        settings: configuration.settings))
    }
}

/// Widgets get a tight memory budget, so the entry carries only the recipe and
/// the drawing happens once per rendered view, cached by seed and size.
enum WidgetInk {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(recipe: StillRenderer.Recipe, size: CGSize, ground: Bool) -> UIImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let scale: CGFloat = 3
        let key = "\(recipe.seed)|\(recipe.figureID ?? "any")|\(Int(size.width))x\(Int(size.height))|\(ground)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let cg = StillRenderer.render(recipe, size: size, scale: scale,
                                            inset: 0.44, ground: ground) else { return nil }
        let image = UIImage(cgImage: cg, scale: scale, orientation: .up)
        cache.setObject(image, forKey: key)
        return image
    }
}

struct AthanorWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FigureEntry

    /// Lock Screen families render monochrome and vibrant, so they get the ink
    /// on transparency and let the system tint it.
    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular
    }

    var body: some View {
        GeometryReader { geo in
            if let image = WidgetInk.image(recipe: entry.recipe, size: geo.size,
                                           ground: !isAccessory) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .widgetAccentable(isAccessory)
            }
        }
        .containerBackground(for: .widget) {
            if isAccessory {
                Color.clear
            } else {
                Color(cgColor: entry.recipe.palette.background)
            }
        }
    }
}

struct AthanorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.centaur-labs.athanor.figure",
                               intent: ConfigurationIntent.self,
                               provider: FigureProvider()) { entry in
            AthanorWidgetView(entry: entry)
        }
        .configurationDisplayName("Athanor")
        .description("A figure drawn fresh every hour.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct AthanorWidgetBundle: WidgetBundle {
    var body: some Widget {
        AthanorWidget()
    }
}
