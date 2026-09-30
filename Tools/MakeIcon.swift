import AppKit

// Reproducible native drawing; no downloaded artwork or generated bitmap dependency.
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.62, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 65, y: 65, width: 894, height: 894), xRadius: 200, yRadius: 200).fill()
    NSColor.white.withAlphaComponent(0.98).setFill()
    NSBezierPath(roundedRect: NSRect(x: 180, y: 390, width: 440, height: 385), xRadius: 85, yRadius: 85).fill()
    let tail = NSBezierPath(); tail.move(to: NSPoint(x: 230, y: 420)); tail.line(to: NSPoint(x: 230, y: 305)); tail.line(to: NSPoint(x: 370, y: 420)); tail.close(); tail.fill()
    NSColor(calibratedRed: 0.39, green: 0.83, blue: 0.89, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 460, y: 205, width: 380, height: 350), xRadius: 75, yRadius: 75).fill()
    let font = NSFont.systemFont(ofSize: 265, weight: .medium)
    let ink = NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.62, alpha: 1)
    ("A" as NSString).draw(at: NSPoint(x: 302, y: 428), withAttributes: [.font: font, .foregroundColor: ink])
    ("文" as NSString).draw(at: NSPoint(x: 535, y: 255), withAttributes: [.font: NSFont.systemFont(ofSize: 215, weight: .medium), .foregroundColor: ink])
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name)) }
}
