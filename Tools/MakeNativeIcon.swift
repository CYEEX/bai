import AppKit

// Extend only the tile background into a square, unmasked icon layer.
// The original lettering and angle artwork remain in the same pixel positions.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let source = root.appendingPathComponent("Resources/BrandIcon.png")
let target = root.appendingPathComponent("Resources/AppIcon.icon", isDirectory: true)
let assets = target.appendingPathComponent("Assets", isDirectory: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
let input = NSBitmapImageRep(data: try Data(contentsOf: source))!
let square = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1074, pixelsHigh: 1074,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let top = input.colorAt(x: 537, y: 5)!.usingColorSpace(.deviceRGB)!
let bottom = input.colorAt(x: 537, y: 1068)!.usingColorSpace(.deviceRGB)!
for y in 0..<1074 {
    let background = top.blended(withFraction: CGFloat(y) / 1073, of: bottom)!
    for x in 0..<1074 {
        let qx = abs(Double(x) + 0.5 - 537) - 277
        let qy = abs(Double(y) + 0.5 - 537) - 287
        let edgeDistance = hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - 250
        let original = input.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        let weight = CGFloat(min(1, max(0, (-edgeDistance - 2) / 2))) * original.alphaComponent
        let color = background.blended(withFraction: weight, of: original.withAlphaComponent(1))!
        square.setColor(color.withAlphaComponent(1), atX: x, y: y)
    }
}
let image = NSImage(size: NSSize(width: 1074, height: 1074))
image.addRepresentation(square)
let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
try output.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("Artwork.png"))
let document: [String: Any] = [
    "fill": ["solid": "srgb:0.99,0.95,0.89,1.0"],
    "groups": [[
        "name": "Artwork",
        "layers": [["name": "掰", "image-name": "Artwork.png", "glass": false]],
        "shadow": ["kind": "none", "opacity": 0],
        "specular": false,
        "blur-material": 0,
        "translucency": ["enabled": false, "value": 0]
    ]],
    "supported-platforms": ["squares": ["macOS"]]
]
try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
    .write(to: target.appendingPathComponent("icon.json"))
