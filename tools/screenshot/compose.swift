import AppKit

// Composes real screen captures of the app onto an App Store sized canvas.
// Only the app's own popover and its own menu bar item are used — no other part
// of the desktop is included.

let CANVAS = NSSize(width: 2880, height: 1800)
let BAR_H: CGFloat = 76
let ZOOM: CGFloat = 2.5          // captured retina pixels are scaled up for legibility

func load(_ path: String) -> NSImage? {
    guard let img = NSImage(contentsOfFile: path) else { print("missing \(path)"); return nil }
    // Use the true pixel dimensions, not the point size NSImage infers.
    if let rep = img.representations.first {
        img.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
    return img
}

func roundedMask(_ image: NSImage, radius: CGFloat) -> NSImage {
    let size = image.size
    let out = NSImage(size: size)
    out.lockFocus()
    let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size),
                            xRadius: radius, yRadius: radius)
    path.addClip()
    image.draw(in: NSRect(origin: .zero, size: size))
    out.unlockFocus()
    return out
}

func compose(popoverPath: String, statusPath: String, headline: String?,
             subline: String?, to path: String) {
    guard let popoverRaw = load(popoverPath), let status = load(statusPath) else { return }
    let popover = roundedMask(popoverRaw, radius: 24)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(CANVAS.width), pixelsHigh: Int(CANVAS.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Background
    NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.26, alpha: 1),
               ending:   NSColor(calibratedRed: 0.33, green: 0.17, blue: 0.40, alpha: 1))?
        .draw(in: NSRect(origin: .zero, size: CANVAS), angle: -60)

    // Menu bar strip carrying the app's real status item. Its fill is sampled from
    // the capture itself, so the strip and the captured item are the same colour.
    let barRect = NSRect(x: 0, y: CANVAS.height - BAR_H, width: CANVAS.width, height: BAR_H)
    var barColor = NSColor(white: 0.08, alpha: 1)
    if let srep = status.representations.first as? NSBitmapImageRep,
       let corner = srep.colorAt(x: 1, y: 1) {
        barColor = corner.usingColorSpace(.deviceRGB) ?? barColor
    }
    barColor.setFill()
    barRect.fill()

    let sw = status.size.width * 1.4, sh = status.size.height * 1.4
    let statusRect = NSRect(x: CANVAS.width - sw - 120,
                            y: barRect.minY + (BAR_H - sh) / 2, width: sw, height: sh)
    status.draw(in: statusRect)

    // Popover, anchored under the status item as it appears in use
    let pw = popover.size.width * ZOOM, ph = popover.size.height * ZOOM
    let frame = NSRect(x: CANVAS.width - pw - 190, y: barRect.minY - ph - 70,
                       width: pw, height: ph)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 70
    shadow.shadowOffset = NSSize(width: 0, height: -22)
    shadow.shadowColor = NSColor(white: 0, alpha: 0.55)
    shadow.set()
    popover.draw(in: frame)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Marketing copy on the empty left half
    if let headline = headline {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 14
        let title = NSAttributedString(string: headline, attributes: [
            .font: NSFont.systemFont(ofSize: 108, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para,
        ])
        let textWidth: CGFloat = 1180
        let headlineTop: CGFloat = 1290
        let th = ceil(title.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                         options: .usesLineFragmentOrigin).height)
        title.draw(in: NSRect(x: 170, y: headlineTop - th, width: textWidth, height: th))

        if let subline = subline {
            let sub = NSAttributedString(string: subline, attributes: [
                .font: NSFont.systemFont(ofSize: 52, weight: .regular),
                .foregroundColor: NSColor(white: 1, alpha: 0.72),
                .paragraphStyle: para,
            ])
            let sh2 = ceil(sub.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                            options: .usesLineFragmentOrigin).height)
            sub.draw(in: NSRect(x: 174, y: headlineTop - th - 80 - sh2, width: textWidth, height: sh2))
        }
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
compose(popoverPath: "\(dir)/popover-en.png", statusPath: "\(dir)/statusitem-en.png",
        headline: "Your accessories,\nbefore they die.",
        subline: "Magic Keyboard, Mouse and Trackpad\nbattery levels in the menu bar.",
        to: "\(dir)/store-1.png")
compose(popoverPath: "\(dir)/popover-en.png", statusPath: "\(dir)/statusitem-en.png",
        headline: nil, subline: nil, to: "\(dir)/store-2.png")
