#!/usr/bin/env swift

import AppKit
import Foundation

private let canvasSize: CGFloat = 1024

private struct IconColor {
    static let paper = color(hex: 0xFFFFFF)
    static let ink = color(hex: 0x111111)
    static let softInk = color(hex: 0x2A2A2A)
    static let shadow = color(hex: 0x000000).withAlphaComponent(0.12)

    private static func color(hex: UInt32) -> NSColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

private func drawIcon(into context: CGContext) {
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    NSGraphicsContext.current?.imageInterpolation = .high

    drawBaseTile()
    drawBackBubble()
    drawFrontBubble()
}

private func drawBaseTile() {
    let tileRect = NSRect(x: 80, y: 82, width: 864, height: 864)
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 188, yRadius: 188)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = IconColor.shadow
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    IconColor.paper.setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    IconColor.paper.setFill()
    tilePath.fill()

    tilePath.lineWidth = 18
    IconColor.ink.setStroke()
    tilePath.stroke()
}

private func drawBackBubble() {
    let body = NSRect(x: 214, y: 524, width: 356, height: 248)
    let path = speechBubblePath(
        body: body,
        cornerRadius: 52,
        tailBaseStartX: 104,
        tailBaseEndX: 180,
        tailTipX: 126,
        tailTipY: -74
    )

    drawBubble(
        path: path,
        fill: IconColor.paper,
        stroke: IconColor.ink,
        strokeWidth: 14
    )

    drawCenteredText(
        "A",
        in: NSRect(x: body.minX + 58, y: body.minY + 50, width: body.width - 116, height: body.height - 72),
        fontSize: 158,
        weight: .medium,
        color: IconColor.ink
    )
}

private func drawFrontBubble() {
    let body = NSRect(x: 458, y: 374, width: 374, height: 250)
    let path = speechBubblePath(
        body: body,
        cornerRadius: 54,
        tailBaseStartX: 184,
        tailBaseEndX: 282,
        tailTipX: 250,
        tailTipY: -78
    )

    drawBubble(
        path: path,
        fill: IconColor.ink,
        stroke: IconColor.ink,
        strokeWidth: 14
    )

    drawCenteredText(
        "\u{6587}",
        in: NSRect(x: body.minX + 72, y: body.minY + 46, width: body.width - 144, height: body.height - 62),
        fontSize: 152,
        weight: .regular,
        color: IconColor.paper
    )
}

private func speechBubblePath(
    body: NSRect,
    cornerRadius: CGFloat,
    tailBaseStartX: CGFloat,
    tailBaseEndX: CGFloat,
    tailTipX: CGFloat,
    tailTipY: CGFloat
) -> NSBezierPath {
    let path = NSBezierPath()
    let minX = body.minX
    let minY = body.minY
    let maxX = body.maxX
    let maxY = body.maxY
    let radius = min(cornerRadius, min(body.width, body.height) / 2)
    let curve = radius * 0.5522847498
    let tailStart = body.minX + tailBaseStartX
    let tailEnd = body.minX + tailBaseEndX
    let tailTip = NSPoint(x: body.minX + tailTipX, y: body.minY + tailTipY)

    path.move(to: NSPoint(x: minX + radius, y: minY))
    path.line(to: NSPoint(x: tailStart, y: minY))
    path.curve(
        to: tailTip,
        controlPoint1: NSPoint(x: tailStart + 12, y: minY - 20),
        controlPoint2: NSPoint(x: tailTip.x - 28, y: tailTip.y + 2)
    )
    path.curve(
        to: NSPoint(x: tailEnd, y: minY),
        controlPoint1: NSPoint(x: tailTip.x + 30, y: tailTip.y - 2),
        controlPoint2: NSPoint(x: tailEnd - 16, y: minY - 18)
    )
    path.line(to: NSPoint(x: maxX - radius, y: minY))
    path.curve(
        to: NSPoint(x: maxX, y: minY + radius),
        controlPoint1: NSPoint(x: maxX - radius + curve, y: minY),
        controlPoint2: NSPoint(x: maxX, y: minY + radius - curve)
    )
    path.line(to: NSPoint(x: maxX, y: maxY - radius))
    path.curve(
        to: NSPoint(x: maxX - radius, y: maxY),
        controlPoint1: NSPoint(x: maxX, y: maxY - radius + curve),
        controlPoint2: NSPoint(x: maxX - radius + curve, y: maxY)
    )
    path.line(to: NSPoint(x: minX + radius, y: maxY))
    path.curve(
        to: NSPoint(x: minX, y: maxY - radius),
        controlPoint1: NSPoint(x: minX + radius - curve, y: maxY),
        controlPoint2: NSPoint(x: minX, y: maxY - radius + curve)
    )
    path.line(to: NSPoint(x: minX, y: minY + radius))
    path.curve(
        to: NSPoint(x: minX + radius, y: minY),
        controlPoint1: NSPoint(x: minX, y: minY + radius - curve),
        controlPoint2: NSPoint(x: minX + radius - curve, y: minY)
    )
    path.close()
    return path
}

private func drawBubble(
    path: NSBezierPath,
    fill: NSColor,
    stroke: NSColor,
    strokeWidth: CGFloat
) {
    fill.setFill()
    path.fill()

    path.lineWidth = strokeWidth
    stroke.setStroke()
    path.stroke()
}

private func drawCenteredText(
    _ text: String,
    in rect: NSRect,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]

    let attributed = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributed.size()
    let drawRect = NSRect(
        x: rect.minX,
        y: rect.midY - (textSize.height / 2) - 4,
        width: rect.width,
        height: textSize.height + 10
    )
    attributed.draw(in: drawRect)
}

private func renderIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = bitmapRep(width: pixels, height: pixels)!
    let graphicsContext = NSGraphicsContext(bitmapImageRep: rep)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    context.scaleBy(x: CGFloat(pixels) / canvasSize, y: CGFloat(pixels) / canvasSize)
    drawIcon(into: context)
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

private func bitmapRep(width: Int, height: Int) -> NSBitmapImageRep? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 32
    )
    rep?.size = NSSize(width: width, height: height)
    return rep
}

private func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
        throw IconGenerationError.pngEncodingFailed(url.path)
    }
    try data.write(to: url, options: .atomic)
}

private func runIconutil(iconsetURL: URL, outputURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw IconGenerationError.iconutilFailed(process.terminationStatus)
    }
}

private enum IconGenerationError: Error, CustomStringConvertible {
    case pngEncodingFailed(String)
    case iconutilFailed(Int32)

    var description: String {
        switch self {
        case .pngEncodingFailed(let path):
            return "Unable to encode PNG at \(path)"
        case .iconutilFailed(let status):
            return "iconutil failed with status \(status)"
        }
    }
}

let outputDirectory = CommandLine.arguments.dropFirst().first.map(URL.init(fileURLWithPath:))
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist")
let iconsetURL = outputDirectory.appendingPathComponent("AppIcon.iconset")
let previewURL = outputDirectory.appendingPathComponent("AppIcon.png")
let icnsURL = outputDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconImages: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for image in iconImages {
    let rep = renderIcon(pixels: image.pixels)
    try writePNG(rep, to: iconsetURL.appendingPathComponent(image.name))
}

try writePNG(renderIcon(pixels: 1024), to: previewURL)
try? FileManager.default.removeItem(at: icnsURL)
try runIconutil(iconsetURL: iconsetURL, outputURL: icnsURL)

print("Generated \(icnsURL.path)")
