import SwiftUI

/// The widget is the surface that needs no upkeep: a fresh figure lands every
/// hour without anyone doing anything. This screen exists to get people there.
struct WidgetHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let symbol: String
    }

    private let steps: [Step] = [
        Step(title: "Home Screen",
             detail: "Touch and hold the wallpaper, tap Edit, then Add Widget, and search for Athanor.",
             symbol: "square.grid.2x2"),
        Step(title: "Lock Screen",
             detail: "Touch and hold the Lock Screen, tap Customise, then tap the area under the clock.",
             symbol: "lock"),
        Step(title: "StandBy",
             detail: "Any Home Screen widget also shows up in StandBy when the phone is charging on its side.",
             symbol: "powerplug"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: step.symbol)
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title).font(.headline)
                                Text(step.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Where it can go")
                } footer: {
                    Text("A new figure is drawn every hour. Touch and hold a placed "
                         + "widget and choose Edit Widget to pin it to one figure or one ink.")
                }
            }
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
