import AppKit

// Isolate the supplied rounded tile. Preserve its original pixels and proportions.
// Coordinates are measured from the 1254 × 1254 source, with a top-left origin.
let source = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: source) else { fatalError("Cannot read source") }
let canvas = 1074
let tile = NSRect(x: 10, y: 0, width: 1054, height: 1074)
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot allocate canvas") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .none
NSBezierPath(roundedRect: tile, xRadius: 250, yRadius: 250).addClip()
image.draw(in: NSRect(x: -90, y: -70, width: 1254, height: 1254),
           from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
