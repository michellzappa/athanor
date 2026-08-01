import SwiftUI
import UIKit

@main
struct AthanorTVApp: App {
    var body: some Scene {
        WindowGroup {
            TVRootView()
                .ignoresSafeArea()
                .background(.black)
        }
    }
}

/// Full-screen figures, and that is the whole app. Select or play/pause on the
/// remote abandons the current figure and starts the next one.
struct TVRootView: View {
    @State private var host = FigureHost()

    var body: some View {
        FigureSurface(host: host)
            .focusable()
            .onTapGesture { host.skip() }
            .onPlayPauseCommand { host.skip() }
            .onMoveCommand { _ in host.skip() }
            // Without this tvOS decides we are idle after a few minutes and
            // covers the app with its own screen saver, which is the one thing
            // this app exists to avoid.
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

final class FigureHost {
    fileprivate let view = AnimatedFigureView(
        director: Director(settings: { SettingsStore.shared.snapshot })
    )

    func skip() { view.skip() }
}

private struct FigureSurface: UIViewRepresentable {
    let host: FigureHost

    func makeUIView(context: Context) -> AnimatedFigureView { host.view }
    func updateUIView(_ uiView: AnimatedFigureView, context: Context) {}
}
