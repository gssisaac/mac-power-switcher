import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvas = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to create bitmap\n", stderr)
    exit(1)
}
rep.size = NSSize(width: canvas, height: canvas)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bounds = NSRect(x: 0, y: 0, width: canvas, height: canvas)
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
bounds.fill()

let config = NSImage.SymbolConfiguration(pointSize: 620, weight: .medium)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .systemYellow))
guard let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    fputs("bolt.fill is unavailable\n", stderr)
    exit(1)
}

let size = symbol.size
symbol.draw(
    in: NSRect(
        x: (CGFloat(canvas) - size.width) / 2,
        y: (CGFloat(canvas) - size.height) / 2,
        width: size.width,
        height: size.height
    ),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)

NSGraphicsContext.restoreGraphicsState()

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("MacPowerSwitcher.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let master = rep.cgImage else {
    fputs("Failed to read CGImage\n", stderr)
    exit(1)
}

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in entries {
    let scaled = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    scaled.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSImage(cgImage: master, size: NSSize(width: pixels, height: pixels))
        .draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let png = scaled.representation(using: .png, properties: [:])!
    try png.write(to: iconset.appendingPathComponent(name))
}

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputURL.path, iconset.path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)

guard process.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
