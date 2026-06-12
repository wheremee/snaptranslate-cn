// 占位图标生成脚本：swift Scripts/make_icon.swift <输出目录>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let size = CGFloat(pixels)
    let inset = size * 0.08
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2)
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.25, green: 0.50, blue: 1.0, alpha: 1),
                              ending: NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.95, alpha: 1))!
    gradient.draw(in: path, angle: -60)

    let text = "译" as NSString
    let font = NSFont.systemFont(ofSize: size * 0.45, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = text.size(withAttributes: attributes)
    text.draw(at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2),
              withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, pixels) in sizes {
    let rep = drawIcon(pixels: pixels)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).png")
    try! data.write(to: url)
}
print("✅ 图标 PNG 已生成: \(outputDir)")
