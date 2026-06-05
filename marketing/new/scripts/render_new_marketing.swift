#!/usr/bin/env swift
import AppKit

let scriptURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let newDir = scriptURL.deletingLastPathComponent()
let rawIPhoneDir = newDir.appendingPathComponent("raw-iphone")
let rawIPadDir = newDir.appendingPathComponent("raw-ipad")
let outIPhoneDir = newDir.appendingPathComponent("iphone-17-pro-max-immersive")
let outIPadDir = newDir.appendingPathComponent("ipad-13-immersive")

try FileManager.default.createDirectory(at: outIPhoneDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outIPadDir, withIntermediateDirectories: true)

struct Spec {
    let raw: String
    let out: String
    let tag: String
    let title: String
    let subtitle: String
    let level: String
    let burst: String
    let colors: [NSColor]
    let accent: NSColor
    let rotation: CGFloat
}

func color(_ hex: String, _ alpha: CGFloat = 1) -> NSColor {
    var value: UInt64 = 0
    var text = hex
    if text.hasPrefix("#") { text.removeFirst() }
    Scanner(string: text).scanHexInt64(&value)
    return NSColor(
        srgbRed: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: alpha
    )
}

let specs: [Spec] = [
    .init(
        raw: "01-portal.png",
        out: "01-step-into-sugarshift.png",
        tag: "SUGARSHIFT",
        title: "Step Into\nthe Sugar Portal",
        subtitle: "A match-3 board that feels bright, fast, and alive.",
        level: "LEVEL 7 / DONUT BOARD",
        burst: "READY?",
        colors: [color("#FF4FA3"), color("#8A3FFC"), color("#22D3EE")],
        accent: color("#FFD166"),
        rotation: -3
    ),
    .init(
        raw: "02-combo-rush.png",
        out: "02-chain-combos.png",
        tag: "COMBO RUSH",
        title: "Chain Combos\nAcross the Grid",
        subtitle: "Cascades, score pops, and Sugar Rush moments stack together.",
        level: "LEVEL 13 / CROSS BOARD",
        burst: "COMBO x7",
        colors: [color("#FF3D81"), color("#F97316"), color("#7C3AED")],
        accent: color("#67E8F9"),
        rotation: 3
    ),
    .init(
        raw: "03-bomb-storm.png",
        out: "03-bomb-storm.png",
        tag: "BOMB STORM",
        title: "Detonate\nWild Boards",
        subtitle: "Higher levels stack specials, blockers, and explosive turns.",
        level: "LEVEL 43 / BOMB BOARD",
        burst: "BOOM",
        colors: [color("#1D4ED8"), color("#A21CAF"), color("#F59E0B")],
        accent: color("#FB7185"),
        rotation: -2.5
    ),
    .init(
        raw: "04-frost-locks.png",
        out: "04-crack-frost-locks.png",
        tag: "OBSTACLES",
        title: "Crack Frost\nand Locks",
        subtitle: "Break layered blockers before your last move disappears.",
        level: "LEVEL 35 / FROST VAULT",
        burst: "SHATTER",
        colors: [color("#38BDF8"), color("#2563EB"), color("#312E81")],
        accent: color("#BAE6FD"),
        rotation: 2
    ),
    .init(
        raw: "05-shape-worlds.png",
        out: "05-shape-worlds.png",
        tag: "FRESH LEVELS",
        title: "Every Board\nHas a New Shape",
        subtitle: "Donuts, crowns, lightning, hearts, and strange puzzle cuts.",
        level: "LEVEL 50 / SHAPE SHIFT",
        burst: "NEW MAP",
        colors: [color("#14B8A6"), color("#A3E635"), color("#F43F5E")],
        accent: color("#FEF08A"),
        rotation: -3.5
    ),
    .init(
        raw: "06-lightning.png",
        out: "06-lightning-levels.png",
        tag: "FAST MOVES",
        title: "Lightning\nLevels Hit Hard",
        subtitle: "Tight move counts and wild layouts keep every swap tense.",
        level: "LEVEL 45 / LIGHTNING",
        burst: "ZAP",
        colors: [color("#0F172A"), color("#7C3AED"), color("#FDE047")],
        accent: color("#FDE047"),
        rotation: 2.8
    ),
    .init(
        raw: "07-boosters.png",
        out: "07-boosters-save-runs.png",
        tag: "BOOSTERS",
        title: "Save Runs\nWith Power Plays",
        subtitle: "Hammer, shuffle, and swap tools turn danger into momentum.",
        level: "LEVEL 28 / BOOSTER BAR",
        burst: "POWER UP",
        colors: [color("#7C2D12"), color("#EA580C"), color("#581C87")],
        accent: color("#FDBA74"),
        rotation: -2
    ),
    .init(
        raw: "08-crown.png",
        out: "08-claim-the-crown.png",
        tag: "FINAL VAULT",
        title: "Claim the\nSugar Crown",
        subtitle: "Reach level 200 and survive the biggest board in the game.",
        level: "LEVEL 200 / CROWN RUN",
        burst: "CROWN",
        colors: [color("#020617"), color("#4C1D95"), color("#DB2777")],
        accent: color("#FBBF24"),
        rotation: 3.5
    )
]

func paragraph(_ alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    style.lineBreakMode = .byWordWrapping
    return style
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func drawGradient(in rect: CGRect, colors: [NSColor], start: CGPoint, end: CGPoint) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: colors.enumerated().map { CGFloat($0.offset) / CGFloat(max(colors.count - 1, 1)) }
    )!
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func drawRadial(center: CGPoint, radius: CGFloat, color: NSColor) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

func drawOrb(center: CGPoint, radius: CGFloat, base: NSColor, highlight: NSColor) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let shadow = NSShadow()
    shadow.shadowBlurRadius = radius * 0.35
    shadow.shadowColor = base.withAlphaComponent(0.42)
    shadow.shadowOffset = CGSize(width: 0, height: -radius * 0.12)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let orb = NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    base.withAlphaComponent(0.92).setFill()
    orb.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [highlight.withAlphaComponent(0.95).cgColor, base.withAlphaComponent(0.25).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.saveGState()
    context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.clip()
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: center.x - radius * 0.35, y: center.y + radius * 0.35),
        startRadius: radius * 0.05,
        endCenter: center,
        endRadius: radius * 1.25,
        options: []
    )
    context.restoreGState()

    highlight.withAlphaComponent(0.5).setStroke()
    let ring = NSBezierPath(ovalIn: CGRect(x: center.x - radius * 0.55, y: center.y - radius * 0.15, width: radius * 1.1, height: radius * 0.3))
    ring.lineWidth = max(5, radius * 0.035)
    ring.stroke()
}

func drawSparkles(canvas: CGSize, accent: NSColor, count: Int) {
    for i in 0..<count {
        let x = CGFloat((i * 173) % Int(canvas.width))
        let y = CGFloat((i * 257 + 91) % Int(canvas.height))
        let r = CGFloat(5 + (i % 5) * 3)
        accent.withAlphaComponent(0.18 + CGFloat(i % 4) * 0.06).setFill()
        NSBezierPath(ovalIn: CGRect(x: x, y: y, width: r, height: r)).fill()
    }
}

func drawSpeedLines(canvas: CGSize, color: NSColor, tilted: Bool) {
    color.setStroke()
    for i in 0..<12 {
        let path = NSBezierPath()
        path.lineWidth = CGFloat(7 + (i % 3) * 4)
        let y = canvas.height * 0.24 + CGFloat(i) * canvas.height * 0.055
        let startX = CGFloat(i % 2 == 0 ? -140 : 40)
        let endX = canvas.width + CGFloat(i % 3) * 120
        let rise = tilted ? CGFloat(i % 2 == 0 ? 120 : -90) : 0
        path.move(to: CGPoint(x: startX, y: y))
        path.curve(to: CGPoint(x: endX, y: y + rise),
                   controlPoint1: CGPoint(x: canvas.width * 0.28, y: y + 80),
                   controlPoint2: CGPoint(x: canvas.width * 0.72, y: y + rise - 80))
        path.stroke()
    }
}

func drawText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
    (text as NSString).draw(in: rect, withAttributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment, lineSpacing: lineSpacing)
    ])
}

func drawLabel(_ text: String, rect: CGRect, fill: NSColor, stroke: NSColor, fontSize: CGFloat) {
    fillRounded(rect, radius: rect.height / 2, color: fill)
    strokeRounded(rect, radius: rect.height / 2, color: stroke, width: 2.5)
    drawText(text, in: rect.insetBy(dx: 26, dy: (rect.height - fontSize * 1.25) / 2), font: .systemFont(ofSize: fontSize, weight: .heavy), color: .white)
}

func drawBurst(_ text: String, center: CGPoint, color: NSColor, scale: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 28 * scale
    shadow.shadowColor = color.withAlphaComponent(0.7)
    shadow.shadowOffset = CGSize(width: 0, height: 0)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 82 * scale, weight: .black),
        .foregroundColor: NSColor.white,
        .strokeColor: color,
        .strokeWidth: -5.0,
        .paragraphStyle: paragraph(.center)
    ]
    let rect = CGRect(x: center.x - 320 * scale, y: center.y - 58 * scale, width: 640 * scale, height: 124 * scale)
    (text as NSString).draw(in: rect, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
}

func drawImageCard(raw: URL, rect: CGRect, radius: CGFloat, rotation: CGFloat, accent: NSColor, canvas: CGSize) {
    guard let image = NSImage(contentsOf: raw) else {
        print("Missing raw image: \(raw.path)")
        return
    }
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let center = CGPoint(x: rect.midX, y: rect.midY)

    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: rotation * .pi / 180)
    context.translateBy(x: -center.x, y: -center.y)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = min(canvas.width, canvas.height) * 0.055
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
    shadow.shadowOffset = CGSize(width: 0, height: -28)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fillRounded(rect.insetBy(dx: -12, dy: -12), radius: radius + 18, color: NSColor.black.withAlphaComponent(0.28))
    NSGraphicsContext.restoreGraphicsState()

    strokeRounded(rect.insetBy(dx: -18, dy: -18), radius: radius + 24, color: accent.withAlphaComponent(0.65), width: 7)
    strokeRounded(rect.insetBy(dx: -32, dy: -32), radius: radius + 36, color: NSColor.white.withAlphaComponent(0.16), width: 4)

    let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    strokeRounded(rect, radius: radius, color: NSColor.white.withAlphaComponent(0.4), width: 4)
    context.restoreGState()
}

func renderPhone(_ spec: Spec) {
    let canvas = CGSize(width: 1320, height: 2868)
    let image = NSImage(size: canvas, flipped: false) { rect in
        drawGradient(in: rect, colors: spec.colors, start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: canvas.width, y: 0))
        drawRadial(center: CGPoint(x: canvas.width * 0.2, y: canvas.height * 0.86), radius: 720, color: NSColor.white.withAlphaComponent(0.20))
        drawRadial(center: CGPoint(x: canvas.width * 0.86, y: canvas.height * 0.28), radius: 680, color: spec.accent.withAlphaComponent(0.28))
        drawSpeedLines(canvas: canvas, color: NSColor.white.withAlphaComponent(0.08), tilted: true)
        drawSparkles(canvas: canvas, accent: spec.accent, count: 54)

        drawOrb(center: CGPoint(x: 105, y: 2505), radius: 170, base: spec.accent.withAlphaComponent(0.72), highlight: .white)
        drawOrb(center: CGPoint(x: 1190, y: 176), radius: 210, base: spec.colors[1].withAlphaComponent(0.72), highlight: spec.accent)
        drawOrb(center: CGPoint(x: 180, y: 330), radius: 120, base: spec.colors[2].withAlphaComponent(0.72), highlight: .white)

        drawLabel(spec.tag, rect: CGRect(x: 90, y: 2676, width: 360, height: 74), fill: NSColor.black.withAlphaComponent(0.22), stroke: NSColor.white.withAlphaComponent(0.28), fontSize: 27)
        drawText(spec.title, in: CGRect(x: 90, y: 2390, width: 1140, height: 260), font: .systemFont(ofSize: 92, weight: .black), color: .white, lineSpacing: -2)
        drawText(spec.subtitle, in: CGRect(x: 92, y: 2288, width: 1050, height: 96), font: .systemFont(ofSize: 34, weight: .semibold), color: NSColor.white.withAlphaComponent(0.88), lineSpacing: 4)

        let rawURL = rawIPhoneDir.appendingPathComponent(spec.raw)
        let screenW = canvas.width * 0.60
        let screenH = screenW * (2868 / 1320)
        let screenRect = CGRect(x: (canvas.width - screenW) / 2, y: 330, width: screenW, height: screenH)
        drawImageCard(raw: rawURL, rect: screenRect, radius: 72, rotation: spec.rotation, accent: spec.accent, canvas: canvas)

        drawLabel(spec.level, rect: CGRect(x: 104, y: 204, width: 600, height: 72), fill: NSColor.black.withAlphaComponent(0.32), stroke: NSColor.white.withAlphaComponent(0.18), fontSize: 25)
        drawBurst(spec.burst, center: CGPoint(x: canvas.width * 0.72, y: 263), color: spec.accent, scale: 0.82)
        return true
    }
    write(image, to: outIPhoneDir.appendingPathComponent(spec.out))
}

func renderPad(_ spec: Spec) {
    let canvas = CGSize(width: 2064, height: 2752)
    let image = NSImage(size: canvas, flipped: false) { rect in
        drawGradient(in: rect, colors: spec.colors, start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: canvas.width, y: 0))
        drawRadial(center: CGPoint(x: canvas.width * 0.78, y: canvas.height * 0.78), radius: 960, color: NSColor.white.withAlphaComponent(0.16))
        drawRadial(center: CGPoint(x: canvas.width * 0.22, y: canvas.height * 0.16), radius: 820, color: spec.accent.withAlphaComponent(0.24))
        drawSpeedLines(canvas: canvas, color: NSColor.white.withAlphaComponent(0.07), tilted: true)
        drawSparkles(canvas: canvas, accent: spec.accent, count: 76)

        drawOrb(center: CGPoint(x: 190, y: 2320), radius: 220, base: spec.accent.withAlphaComponent(0.72), highlight: .white)
        drawOrb(center: CGPoint(x: 1870, y: 320), radius: 270, base: spec.colors[1].withAlphaComponent(0.76), highlight: spec.accent)
        drawOrb(center: CGPoint(x: 1540, y: 2395), radius: 140, base: spec.colors[2].withAlphaComponent(0.68), highlight: .white)

        drawLabel(spec.tag, rect: CGRect(x: 130, y: 2544, width: 410, height: 82), fill: NSColor.black.withAlphaComponent(0.22), stroke: NSColor.white.withAlphaComponent(0.28), fontSize: 30)
        drawText(spec.title, in: CGRect(x: 130, y: 2256, width: 820, height: 260), font: .systemFont(ofSize: 88, weight: .black), color: .white, lineSpacing: -1)
        drawText(spec.subtitle, in: CGRect(x: 132, y: 2106, width: 740, height: 126), font: .systemFont(ofSize: 34, weight: .semibold), color: NSColor.white.withAlphaComponent(0.88), lineSpacing: 5)
        drawLabel(spec.level, rect: CGRect(x: 130, y: 1968, width: 620, height: 76), fill: NSColor.black.withAlphaComponent(0.32), stroke: NSColor.white.withAlphaComponent(0.18), fontSize: 26)

        let rawURL = rawIPadDir.appendingPathComponent(spec.raw)
        let screenW = canvas.width * 0.56
        let screenH = screenW * (2752 / 2064)
        let screenRect = CGRect(x: 790, y: 392, width: screenW, height: screenH)
        drawImageCard(raw: rawURL, rect: screenRect, radius: 58, rotation: spec.rotation * 0.72, accent: spec.accent, canvas: canvas)

        drawBurst(spec.burst, center: CGPoint(x: 520, y: 410), color: spec.accent, scale: 1.0)
        return true
    }
    write(image, to: outIPadDir.appendingPathComponent(spec.out))
}

func write(_ image: NSImage, to url: URL) {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [.compressionFactor: 0.9])
    else {
        print("Could not encode \(url.path)")
        return
    }
    do {
        try data.write(to: url)
        print("wrote \(url.path)")
    } catch {
        print("Could not write \(url.path): \(error)")
    }
}

for spec in specs {
    renderPhone(spec)
    if FileManager.default.fileExists(atPath: rawIPadDir.appendingPathComponent(spec.raw).path) {
        renderPad(spec)
    }
}
