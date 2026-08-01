import SwiftUI
import UIKit

@main
struct AthanorWallpaperApp: App {
    var body: some Scene {
        WindowGroup {
            WallpaperView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Renders a figure at the device's exact pixel size and puts it in Photos.
/// iOS has no way for an app to set a wallpaper itself, so the last step is
/// yours: Photos, share sheet, Use as Wallpaper.
struct WallpaperView: View {
    @State private var recipe = StillRenderer.Recipe.random(settings: SettingsStore.shared.snapshot)
    @State private var image: UIImage?
    @State private var rendering = false
    @State private var figureID: String?
    @State private var paletteID = "auto"
    @State private var saved = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if rendering {
                    ProgressView().controlSize(.large).tint(.white)
                }

                VStack {
                    Spacer()
                    controls
                }
            }
            // geo.size is the whole screen because the reader ignores the safe
            // area, which is what a wallpaper has to fill.
            .task(id: recipe.seed) {
                await render(size: geo.size, scale: displayScale)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Menu {
                    Button("Any figure") { figureID = nil; regenerate() }
                    Divider()
                    ForEach(FigureCatalog.all, id: \.id) { kind in
                        Button(kind.title) { figureID = kind.id; regenerate() }
                    }
                } label: {
                    chip(figureID.flatMap { FigureCatalog.kind(id: $0)?.title } ?? "Any figure")
                }

                Menu {
                    Button("Any ink") { paletteID = "auto"; regenerate() }
                    Divider()
                    ForEach(Palette.all, id: \.id) { palette in
                        Button(palette.title) { paletteID = palette.id; regenerate() }
                    }
                } label: {
                    chip(Palette.named(paletteID)?.title ?? "Any ink")
                }
            }

            HStack(spacing: 12) {
                Button(action: regenerate) {
                    Label("Again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                Button(action: save) {
                    Label(saved ? "Saved" : "Save", systemImage: saved ? "checkmark" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(image == nil || rendering)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.16))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 44)
        .background(.black.opacity(0.35))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.14), in: Capsule())
            .foregroundStyle(.white)
    }

    private func regenerate() {
        saved = false
        var settings = SettingsStore.shared.snapshot
        settings.tint = paletteID
        recipe = StillRenderer.Recipe.random(figureID: figureID, settings: settings)
    }

    private func render(size: CGSize, scale: CGFloat) async {
        guard size.width > 0 else { return }
        rendering = true
        let target = recipe
        let cgImage = await Task.detached(priority: .userInitiated) {
            StillRenderer.render(target, size: size, scale: scale, inset: 0.36)
        }.value
        if let cgImage {
            withAnimation(.easeInOut(duration: 0.35)) {
                image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            }
        }
        rendering = false
    }

    private func save() {
        guard let image else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        saved = true
    }
}
