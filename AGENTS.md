# Athanor

Generative sacred geometry. One figure is constructed compass-and-straightedge
style, held, then dissolved, and another begins. Three shells over one core:

| Target             | Platform | Product                                  |
| ------------------ | -------- | ---------------------------------------- |
| `AthanorSaver`     | macOS 14 | `Athanor.saver` screen saver bundle      |
| `AthanorTV`        | tvOS 17  | full-screen app, runs until you stop it  |
| `AthanorWallpaper` | iOS 17   | still generator, saves to Photos         |

## Build

XcodeGen owns `Athanor.xcodeproj`. Never hand-edit it; edit `project.yml` and
regenerate.

```bash
xcodegen generate
xcodebuild -project Athanor.xcodeproj -scheme AthanorSaver -configuration Release -derivedDataPath build build
xcodebuild -project Athanor.xcodeproj -scheme AthanorTV -configuration Release -sdk appletvsimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Athanor.xcodeproj -scheme AthanorWallpaper -configuration Release -sdk iphonesimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

`Scripts/install-saver.sh` builds and drops the saver into
`~/Library/Screen Savers`, killing `legacyScreenSaver` first because the host
process keeps the previous bundle mapped and will otherwise serve a stale copy.

## Layout

- `Shared/Core` — geometry, ink, timeline, settings. Core Graphics and
  Foundation only. No AppKit, no UIKit, no SwiftUI.
- `Shared/Figures` — one file per figure.
- `Shared/Hosts` — `AnimatedFigureView`, the UIKit host, behind
  `#if canImport(UIKit)`.
- `Saver`, `TV`, `Wallpaper` — per-platform shells, nothing else.

The same `Shared/` directory is compiled into all three targets. That is
deliberate: no module boundary means no `public` annotations to maintain on a
codebase this size.

## Adding a figure

1. Write `Shared/Figures/YourFigure.swift` exposing a `static let kind:
   FigureKind`.
2. Add it to `FigureCatalog.all`.

That is all. The macOS options sheet builds its checkbox list from the catalog,
grouped by `FigureCollection`, and the iOS picker reads the same list. Empty
collections are skipped, so `.solids`, `.tilings`, and `.curves` stay invisible
until something lands in them.

## Traps

- **Unit space is y-up.** Figures are authored in a y-up plane centred on the
  origin, sized to fit a circle of radius 1. AppKit gives you that; UIKit does
  not, so `AnimatedFigureView` flips the context before handing it to `Director`.
  Anything else drawing into a UIKit context must do the same.
- **Finished strokes are baked into a bitmap** by `InkRenderer` and only the
  in-progress stroke is re-rendered per frame. That is what keeps a 40,000-point
  figure at 30 fps on a 5K display. Anything that invalidates the bake (a resize)
  has to replay via `Director.replayCommitted()`.
- **The drift transform is applied at blit time**, not at commit time, so the
  baked bitmap stays valid while the figure rotates. Do not bake transformed
  geometry.
- **`ScreenSaverDefaults`, not `UserDefaults`**, inside the saver: the host
  process owns the preference domain. `SettingsStore` picks the right one via
  `#if canImport(ScreenSaver)`.
- **Everything is a polyline.** Circles, arcs and spirals are all sampled down to
  points so partial drawing is one code path. Do not add `CGPath`-based strokes.
- Swift language mode is 5, not 6. Strict concurrency would flag the shared
  singletons and buys nothing here.

## Not built yet

- **Sri Yantra.** Deliberately absent. A faithful one is a numerically solved
  construction (the nine triangles must meet at exact triple points), not a
  formula, and an approximation reads as wrong to anyone who knows the figure.
  `Yantra` is a generative stand-in built from exactly constructible layers.
- The `.solids`, `.tilings` and `.curves` collections are declared and empty.
