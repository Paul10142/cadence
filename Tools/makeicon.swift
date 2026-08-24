// Renders the Thyme Custom app icon (a simple stopwatch) into an .iconset.
import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./ThymeCustom.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawStopwatch(size: CGFloat, ctx: CGContext) {
    let s = size
    ctx.setAllowsAntialiasing(true)

    // Rounded-square background, macOS-style.
    let inset = s * 0.06
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.225, cornerHeight: s * 0.225, transform: nil)
    let colors = [NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.32, alpha: 1).cgColor,
                  NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.16, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                              locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    let cx = s / 2, cy = s * 0.465, r = s * 0.275
    let stroke = max(1, s * 0.045)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(stroke)

    // Crown.
    ctx.setFillColor(NSColor.white.cgColor)
    let crown = CGRect(x: cx - s * 0.055, y: cy + r + s * 0.02,
                       width: s * 0.11, height: s * 0.075)
    ctx.addPath(CGPath(roundedRect: crown, cornerWidth: s * 0.022, cornerHeight: s * 0.022, transform: nil))
    ctx.fillPath()

    // Side buttons.
    for angle in [CGFloat.pi * 0.72, CGFloat.pi * 0.28] {
        ctx.move(to: CGPoint(x: cx + cos(angle) * r * 0.98, y: cy + sin(angle) * r * 0.98))
        ctx.addLine(to: CGPoint(x: cx + cos(angle) * (r + s * 0.06),
                                y: cy + sin(angle) * (r + s * 0.06)))
    }
    ctx.strokePath()

    // Dial.
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    // Hand, pointing to roughly 1 o'clock.
    ctx.setLineWidth(stroke * 0.85)
    ctx.move(to: CGPoint(x: cx, y: cy))
    ctx.addLine(to: CGPoint(x: cx + r * 0.42, y: cy + r * 0.52))
    ctx.strokePath()

    // Hub.
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: cx - stroke * 0.7, y: cy - stroke * 0.7,
                               width: stroke * 1.4, height: stroke * 1.4))
}

func write(size: Int, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    drawStopwatch(size: CGFloat(size), ctx: gc.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

for (base, name) in [(16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
                     (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
                     (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
                     (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
                     (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")] {
    write(size: base, name: name)
}
print("iconset written to \(outDir)")
