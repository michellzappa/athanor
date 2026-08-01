import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders the app marks out of the same primitives the figures use, so the icon
// is literally something Athanor draws rather than a picture of it. The mark is
// a Seed of Life: seven circles, one boundary. It survives being 40 points wide,
// which Metatron's Cube would not.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
               ? CommandLine.arguments[1]
               : FileManager.default.currentDirectoryPath)

let palette = Palette.gold
/// Line width as a fraction of the short edge stays constant at every size,
/// because InkRenderer's base width is already proportional to it.
let inkWeight: CGFloat = 22
let inset: CGFloat = 0.56

// MARK: - The mark

/// Parallax layers for tvOS. `flat` is every layer at once, for everywhere else.
enum Layer: CaseIterable {
    case back, middle, front

    static let flat: [Layer] = allCases
}

func strokes(_ layers: [Layer]) -> [Stroke] {
    let b = DrawingBuilder()
    let r: CGFloat = 0.33

    if layers.contains(.back) {
        b.circle(centre: .zero, radius: 2 * r, .accent, weight: 0.85, tone: 0.42)
    }
    if layers.contains(.middle) {
        for i in 0..<6 {
            b.circle(centre: CGPoint(angle: .pi / 2 + tau * CGFloat(i) / 6, radius: r),
                     radius: r, .primary, tone: 0.58, clockwise: i % 2 == 1)
        }
    }
    if layers.contains(.front) {
        // No bindu: all six circles already pass through the origin, and the
        // additive glow stacking there is bright enough on its own.
        b.circle(centre: .zero, radius: r, .primary, tone: 0.9)
    }
    return b.build().strokes
}

// MARK: - Rendering

func ink(_ layers: [Layer], size: CGSize) -> CGImage? {
    let renderer = InkRenderer()
    renderer.configure(size: size, backingScale: 1, inset: inset)
    renderer.clearCanvas()
    for stroke in strokes(layers) {
        renderer.commit(stroke, palette: palette, weight: inkWeight, glow: 0.5)
    }
    return renderer.canvasImage
}

/// App Store icons must not ship an alpha channel, so opaque output gets its own
/// context rather than a composite over a transparent one.
func opaque(_ layers: [Layer], size: CGSize) -> CGImage? {
    guard let art = ink(layers, size: size),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    let rect = CGRect(origin: .zero, size: size)
    ctx.setFillColor(palette.background)
    ctx.fill(rect)
    ctx.setBlendMode(.plusLighter)
    ctx.draw(art, in: rect)
    return ctx.makeImage()
}

func write(_ image: CGImage?, to path: String) {
    guard let image else { print("!! could not render \(path)"); return }
    let url = root.appendingPathComponent(path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)
    else { print("!! could not open \(path)"); return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("   \(path)  \(image.width)x\(image.height)")
}

func write(json: String, to path: String) {
    let url = root.appendingPathComponent(path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try? json.data(using: .utf8)?.write(to: url)
}

let info = #""info" : { "author" : "athanor", "version" : 1 }"#

// MARK: - Master and iOS

print("master")
write(opaque(Layer.flat, size: CGSize(width: 1024, height: 1024)), to: "Assets/icon-1024.png")

print("iOS")
let iOSIcon = "Wallpaper/Assets.xcassets/AppIcon.appiconset"
write(opaque(Layer.flat, size: CGSize(width: 1024, height: 1024)), to: "\(iOSIcon)/icon-1024.png")
write(json: """
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  \(info)
}
""", to: "\(iOSIcon)/Contents.json")
write(json: "{\n  \(info)\n}", to: "Wallpaper/Assets.xcassets/Contents.json")

// MARK: - tvOS

// tvOS icons are layered so the system can parallax them under focus. Back holds
// the ground and the boundary circle, front holds the seed circle, and the six
// ring circles ride in between.
print("tvOS")
let brand = "TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
write(json: "{\n  \(info)\n}", to: "TV/Assets.xcassets/Contents.json")
write(json: """
{
  "assets" : [
    {
      "filename" : "App Icon.imagestack",
      "idiom" : "tv",
      "role" : "primary-app-icon",
      "size" : "400x240"
    },
    {
      "filename" : "App Icon - App Store.imagestack",
      "idiom" : "tv",
      "role" : "primary-app-icon",
      "size" : "1280x768"
    },
    {
      "filename" : "Top Shelf Image.imageset",
      "idiom" : "tv",
      "role" : "top-shelf-image",
      "size" : "1920x720"
    },
    {
      "filename" : "Top Shelf Image Wide.imageset",
      "idiom" : "tv",
      "role" : "top-shelf-image-wide",
      "size" : "2320x720"
    }
  ],
  \(info)
}
""", to: "\(brand)/Contents.json")

/// One `.imagestack`: three layers, front listed first.
func imageStack(_ name: String, base: CGSize, scales: [Int]) {
    let stack = "\(brand)/\(name).imagestack"
    write(json: """
    {
      "layers" : [
        { "filename" : "Front.imagestacklayer" },
        { "filename" : "Middle.imagestacklayer" },
        { "filename" : "Back.imagestacklayer" }
      ],
      \(info)
    }
    """, to: "\(stack)/Contents.json")

    for (layer, label) in [(Layer.front, "Front"), (Layer.middle, "Middle"), (Layer.back, "Back")] {
        let dir = "\(stack)/\(label).imagestacklayer"
        write(json: "{\n  \(info)\n}", to: "\(dir)/Contents.json")

        var entries: [String] = []
        for scale in scales {
            let size = CGSize(width: base.width * CGFloat(scale), height: base.height * CGFloat(scale))
            let file = "\(label.lowercased())@\(scale)x.png"
            // Only the back layer is opaque; the others must let it through.
            write(layer == .back ? opaque([.back], size: size) : ink([layer], size: size),
                  to: "\(dir)/Content.imageset/\(file)")
            entries.append("""
                { "filename" : "\(file)", "idiom" : "tv", "scale" : "\(scale)x" }
            """)
        }
        write(json: """
        {
          "images" : [
        \(entries.joined(separator: ",\n"))
          ],
          \(info)
        }
        """, to: "\(dir)/Content.imageset/Contents.json")
    }
}

imageStack("App Icon", base: CGSize(width: 400, height: 240), scales: [1, 2])
imageStack("App Icon - App Store", base: CGSize(width: 1280, height: 768), scales: [1])

func topShelf(_ name: String, base: CGSize) {
    let dir = "\(brand)/\(name).imageset"
    var entries: [String] = []
    for scale in [1, 2] {
        let size = CGSize(width: base.width * CGFloat(scale), height: base.height * CGFloat(scale))
        let file = "\(name.replacingOccurrences(of: " ", with: "-").lowercased())@\(scale)x.png"
        write(opaque(Layer.flat, size: size), to: "\(dir)/\(file)")
        entries.append("""
            { "filename" : "\(file)", "idiom" : "tv", "scale" : "\(scale)x" }
        """)
    }
    write(json: """
    {
      "images" : [
    \(entries.joined(separator: ",\n"))
      ],
      \(info)
    }
    """, to: "\(dir)/Contents.json")
}

topShelf("Top Shelf Image", base: CGSize(width: 1920, height: 720))
topShelf("Top Shelf Image Wide", base: CGSize(width: 2320, height: 720))

print("done")
