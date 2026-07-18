import AppKit
import CoreGraphics

// Renders the BatteryBar app icon (battery outline + bluetooth glyph) to a 1024px PNG.
// Usage: swift tools/make_icon.swift <output.png>

let size = 1024
let W = CGFloat(size)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

// 1. Rounded-rect (squircle-ish) background with a blue gradient.
let margin: CGFloat = 88
let bgRect = CGRect(x: margin, y: margin, width: W - 2 * margin, height: W - 2 * margin)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 196, cornerHeight: 196, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let grad = CGGradient(
    colorsSpace: cs,
    colors: [color(0.20, 0.58, 1.0), color(0.0, 0.29, 0.86)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: W), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// 2. Battery body + terminal geometry.
let bodyRect = CGRect(x: 258, y: 372, width: 460, height: 280)
let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 60, cornerHeight: 60, transform: nil)
let termRect = CGRect(x: 720, y: 462, width: 36, height: 100)
let termPath = CGPath(roundedRect: termRect, cornerWidth: 18, cornerHeight: 18, transform: nil)

// 3. Green "charge" fill inside the body.
let innerRect = bodyRect.insetBy(dx: 42, dy: 42)
let fillPath = CGPath(roundedRect: innerRect, cornerWidth: 30, cornerHeight: 30, transform: nil)
ctx.addPath(fillPath)
ctx.setFillColor(color(0.20, 0.80, 0.36))
ctx.fillPath()

// 4. White battery outline + solid terminal.
ctx.setStrokeColor(color(1, 1, 1))
ctx.setLineWidth(32)
ctx.addPath(bodyPath)
ctx.strokePath()
ctx.addPath(termPath)
ctx.setFillColor(color(1, 1, 1))
ctx.fillPath()

// 5. Bluetooth glyph, centered on the battery.
func drawBluetooth(cx: CGFloat, cy: CGFloat, height h: CGFloat) {
    // Classic single-stroke bluetooth polyline in a 12x24 box (y measured downward).
    let boxH: CGFloat = 24, boxW: CGFloat = 12
    let scale = h / boxH
    let w = boxW * scale
    func p(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
        CGPoint(x: cx - w / 2 + px * scale, y: cy + h / 2 - py * scale)  // flip y to y-up
    }
    let pts = [p(0, 7), p(12, 17), p(6, 22), p(6, 2), p(12, 7), p(0, 17)]
    ctx.saveGState()
    ctx.setStrokeColor(color(1, 1, 1))
    ctx.setLineWidth(h * 0.115)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.move(to: pts[0])
    for pt in pts.dropFirst() { ctx.addLine(to: pt) }
    ctx.strokePath()
    ctx.restoreGState()
}
drawBluetooth(cx: 488, cy: 512, height: 156)

// 6. Write PNG.
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
