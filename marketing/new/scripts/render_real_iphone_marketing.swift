#!/usr/bin/env swift
import AppKit

let scriptURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let newDir = scriptURL.deletingLastPathComponent()
let rawDir = newDir.appendingPathComponent("raw-real-iphone")
let outputFolder = ProcessInfo.processInfo.environment["SUGARSHIFT_MARKETING_OUT"] ?? "iphone-17-pro-max-immersive"
let outDir = newDir.appendingPathComponent(outputFolder)

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

struct Spec {
    let raw: String
    let out: String
    let tag: String
    let title: String
    let subtitle: String
    let bottomLabel: String
    let burst: String
    let colors: [NSColor]
    let accent: NSColor
    let rotation: CGFloat
    let phoneScale: CGFloat
    let phoneY: CGFloat
    let confetti: Bool
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
        raw: "11-level8-sweet-lightning.png",
        out: "01-level8-sweet-lightning.png",
        tag: "LEVEL 8 ACTION",
        title: "Sweet\nLightning Clears",
        subtitle: "Blast a full column, crack frost, and keep the combo moving.",
        bottomLabel: "LIGHTNING POWER-UP",
        burst: "SWEET",
        colors: [color("#63DAD4"), color("#B8EEE8"), color("#F6508A")],
        accent: color("#FFBE1B"),
        rotation: -1.5,
        phoneScale: 0.72,
        phoneY: 210,
        confetti: true
    ),
    .init(
        raw: "12-level8-color-blast.png",
        out: "02-level8-color-blast.png",
        tag: "COLOR BLAST",
        title: "Color Blast\nCombos",
        subtitle: "Bigger clears, brighter rewards, and new board pressure.",
        bottomLabel: "LEVEL 8 / FROST TILES",
        burst: "COLOR BLAST",
        colors: [color("#5BD6D0"), color("#9DEBE4"), color("#FFBE1B")],
        accent: color("#FFBE1B"),
        rotation: 1.6,
        phoneScale: 0.72,
        phoneY: 210,
        confetti: true
    ),
    .init(
        raw: "01-huge-smash.png",
        out: "03-huge-smash-combos.png",
        tag: "REAL GAMEPLAY",
        title: "Huge Smash\nCombos",
        subtitle: "Match fruit, trigger cascades, and watch the board celebrate.",
        bottomLabel: "COMBOS IN ACTION",
        burst: "HUGE SMASH",
        colors: [color("#66DED7"), color("#9BE8E1"), color("#F6508A")],
        accent: color("#FFBE1B"),
        rotation: -1.8,
        phoneScale: 0.71,
        phoneY: 220,
        confetti: true
    ),
    .init(
        raw: "06-home-play.png",
        out: "04-sweet-match-magic.png",
        tag: "TAP TO PLAY",
        title: "Sweet Match\nMagic",
        subtitle: "Open SugarShift and jump straight into bright fruit puzzles.",
        bottomLabel: "PLAY / MATCH / WIN",
        burst: "PLAY",
        colors: [color("#F8DCEB"), color("#E6DDF7"), color("#B9EFD4")],
        accent: color("#F6508A"),
        rotation: -1.0,
        phoneScale: 0.69,
        phoneY: 245,
        confetti: false
    ),
    .init(
        raw: "07-candy-map-wide.png",
        out: "05-candy-road-map.png",
        tag: "CANDY ROAD",
        title: "Follow the\nLevel Map",
        subtitle: "Unlock new stops, collect rewards, and keep moving forward.",
        bottomLabel: "MAP / DAILY / SHOP",
        burst: "NEXT",
        colors: [color("#F9DCEB"), color("#DFF6E9"), color("#F6D1EA")],
        accent: color("#F6508A"),
        rotation: 1.1,
        phoneScale: 0.69,
        phoneY: 245,
        confetti: false
    ),
    .init(
        raw: "04-plan-moves.png",
        out: "06-score-moves-stars.png",
        tag: "MOVE STRATEGY",
        title: "Chase Stars\nBefore Moves Run Out",
        subtitle: "Score targets, remaining moves, lives, and coins stay in view.",
        bottomLabel: "SCORE / MOVES / STARS",
        burst: "PLAN",
        colors: [color("#5AD3CD"), color("#B6ECE6"), color("#7BC4F3")],
        accent: color("#F6508A"),
        rotation: 1.3,
        phoneScale: 0.70,
        phoneY: 230,
        confetti: false
    ),
    .init(
        raw: "05-tasty-clear.png",
        out: "07-tasty-clears.png",
        tag: "REWARD MOMENTS",
        title: "Tasty Clears\nFeel Big",
        subtitle: "Bright effects, confetti, and score bursts make wins satisfying.",
        bottomLabel: "CELEBRATE EVERY CLEAR",
        burst: "TASTY",
        colors: [color("#61DAD4"), color("#A6E9E2"), color("#8A6DFF")],
        accent: color("#FFBE1B"),
        rotation: -1.4,
        phoneScale: 0.71,
        phoneY: 220,
        confetti: true
    ),
    .init(
        raw: "10-title-clean.png",
        out: "08-sugarshift-brand.png",
        tag: "ARCADE PUZZLE",
        title: "One More\nSweet Move",
        subtitle: "Simple matching, loud rewards, and quick sessions anytime.",
        bottomLabel: "SWEET MATCH MAGIC",
        burst: "SUGARSHIFT",
        colors: [color("#F7DCEB"), color("#E4DEF8"), color("#B8EED5")],
        accent: color("#8A6DFF"),
        rotation: 1.0,
        phoneScale: 0.69,
        phoneY: 245,
        confetti: false
    )
]

let canvas = CGSize(width: 1320, height: 2868)

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

func drawGradient(_ colors: [NSColor]) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: [0, 0.58, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: canvas.height),
        end: CGPoint(x: canvas.width, y: 0),
        options: []
    )
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

func drawText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
    (text as NSString).draw(in: rect, withAttributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment, lineSpacing: lineSpacing)
    ])
}

func drawHeroText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, lineSpacing: CGFloat = 0) {
    let baseAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraph(.left, lineSpacing: lineSpacing)
    ]
    let offsets: [CGPoint] = [
        CGPoint(x: -3, y: -3),
        CGPoint(x: 3, y: -3),
        CGPoint(x: -3, y: 3),
        CGPoint(x: 3, y: 3),
        CGPoint(x: 0, y: -5)
    ]
    for offset in offsets {
        var shadowAttrs = baseAttrs
        shadowAttrs[.foregroundColor] = NSColor.black.withAlphaComponent(0.34)
        (text as NSString).draw(in: rect.offsetBy(dx: offset.x, dy: offset.y), withAttributes: shadowAttrs)
    }
    var fillAttrs = baseAttrs
    fillAttrs[.foregroundColor] = color
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 12
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = CGSize(width: 0, height: -3)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    (text as NSString).draw(in: rect, withAttributes: fillAttrs)
    NSGraphicsContext.restoreGraphicsState()
}

func drawCopyPanel() {
    let panel = CGRect(x: 54, y: 2342, width: 1160, height: 438)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 34
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = CGSize(width: 0, height: -8)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fillRounded(panel, radius: 48, color: color("#081A22", 0.58))
    NSGraphicsContext.restoreGraphicsState()
    strokeRounded(panel, radius: 48, color: NSColor.white.withAlphaComponent(0.24), width: 3)

    fillRounded(CGRect(x: 74, y: 2358, width: 1120, height: 86), radius: 34, color: NSColor.white.withAlphaComponent(0.08))
}

func drawOutlinedText(_ text: String, center: CGPoint, color: NSColor, size: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30
    shadow.shadowColor = color.withAlphaComponent(0.55)
    shadow.shadowOffset = .zero
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: .black),
        .foregroundColor: NSColor.white,
        .strokeColor: color,
        .strokeWidth: -5.5,
        .paragraphStyle: paragraph(.center)
    ]
    let rect = CGRect(x: center.x - 330, y: center.y - size * 0.55, width: 660, height: size * 1.25)
    (text as NSString).draw(in: rect, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
}

func drawPill(_ text: String, rect: CGRect, fill: NSColor, stroke: NSColor, fontSize: CGFloat) {
    fillRounded(rect, radius: rect.height / 2, color: fill)
    strokeRounded(rect, radius: rect.height / 2, color: stroke, width: 2.5)
    drawText(text, in: rect.insetBy(dx: 28, dy: (rect.height - fontSize * 1.2) / 2), font: .systemFont(ofSize: fontSize, weight: .black), color: .white)
}

func drawOrb(center: CGPoint, radius: CGFloat, base: NSColor, highlight: NSColor) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let shadow = NSShadow()
    shadow.shadowBlurRadius = radius * 0.35
    shadow.shadowColor = base.withAlphaComponent(0.32)
    shadow.shadowOffset = CGSize(width: 0, height: -radius * 0.08)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    base.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [highlight.withAlphaComponent(0.9).cgColor, base.withAlphaComponent(0.12).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.saveGState()
    context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.clip()
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: center.x - radius * 0.28, y: center.y + radius * 0.32),
        startRadius: radius * 0.04,
        endCenter: center,
        endRadius: radius * 1.15,
        options: []
    )
    context.restoreGState()

    highlight.withAlphaComponent(0.48).setStroke()
    let ring = NSBezierPath(ovalIn: CGRect(x: center.x - radius * 0.58, y: center.y - radius * 0.12, width: radius * 1.16, height: radius * 0.25))
    ring.lineWidth = max(5, radius * 0.035)
    ring.stroke()
}

func drawMotionLines(_ color: NSColor) {
    color.setStroke()
    for i in 0..<13 {
        let path = NSBezierPath()
        path.lineWidth = CGFloat(5 + (i % 3) * 4)
        let y = canvas.height * 0.18 + CGFloat(i) * 145
        path.move(to: CGPoint(x: -180, y: y))
        path.curve(
            to: CGPoint(x: canvas.width + 180, y: y + CGFloat(i % 2 == 0 ? 85 : -75)),
            controlPoint1: CGPoint(x: canvas.width * 0.28, y: y + 70),
            controlPoint2: CGPoint(x: canvas.width * 0.72, y: y - 70)
        )
        path.stroke()
    }
}

func drawConfetti(accent: NSColor, dense: Bool) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let count = dense ? 110 : 64
    let palette = [color("#FFBE1B"), color("#F6508A"), color("#8A6DFF"), color("#35BDE3"), color("#FFFFFF")]
    for i in 0..<count {
        let x = CGFloat((i * 181 + 43) % Int(canvas.width + 220)) - 110
        let y = CGFloat((i * 269 + 131) % Int(canvas.height))
        let w = CGFloat(10 + (i % 4) * 7)
        let h = CGFloat(5 + (i % 3) * 5)
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: CGFloat((i * 23) % 180) * .pi / 180)
        palette[i % palette.count].withAlphaComponent(i % 5 == 0 ? 0.45 : 0.78).setFill()
        NSBezierPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), xRadius: 2, yRadius: 2).fill()
        context.restoreGState()
    }
    drawRadial(center: CGPoint(x: canvas.width * 0.72, y: canvas.height * 0.18), radius: 420, color: accent.withAlphaComponent(0.26))
}

func drawPhone(image: NSImage, spec: Spec) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let phoneW = canvas.width * spec.phoneScale
    let phoneH = phoneW * (image.size.height / image.size.width)
    let rect = CGRect(x: (canvas.width - phoneW) / 2, y: spec.phoneY, width: phoneW, height: phoneH)
    let center = CGPoint(x: rect.midX, y: rect.midY)

    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: spec.rotation * .pi / 180)
    context.translateBy(x: -center.x, y: -center.y)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 70
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.shadowOffset = CGSize(width: 0, height: -24)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fillRounded(rect.insetBy(dx: -16, dy: -16), radius: 82, color: NSColor.black.withAlphaComponent(0.28))
    NSGraphicsContext.restoreGraphicsState()

    strokeRounded(rect.insetBy(dx: -28, dy: -28), radius: 92, color: spec.accent.withAlphaComponent(0.68), width: 7)
    strokeRounded(rect.insetBy(dx: -42, dy: -42), radius: 104, color: NSColor.white.withAlphaComponent(0.22), width: 4)

    let clip = NSBezierPath(roundedRect: rect, xRadius: 72, yRadius: 72)
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    image.draw(in: rect, from: CGRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    strokeRounded(rect, radius: 72, color: NSColor.white.withAlphaComponent(0.42), width: 3)
    context.restoreGState()
}

func render(_ spec: Spec) {
    let rawURL = rawDir.appendingPathComponent(spec.raw)
    guard let source = NSImage(contentsOf: rawURL) else {
        print("Missing \(rawURL.path)")
        return
    }

    let output = NSImage(size: canvas, flipped: false) { rect in
        drawGradient(spec.colors)
        source.draw(in: rect.insetBy(dx: -130, dy: -90), from: CGRect(origin: .zero, size: source.size), operation: .sourceOver, fraction: 0.12)
        fillRounded(rect, radius: 0, color: NSColor.white.withAlphaComponent(0.06))
        drawRadial(center: CGPoint(x: 80, y: 2570), radius: 560, color: spec.accent.withAlphaComponent(0.35))
        drawRadial(center: CGPoint(x: 1200, y: 260), radius: 520, color: spec.colors.last!.withAlphaComponent(0.34))
        drawMotionLines(NSColor.white.withAlphaComponent(0.10))
        drawOrb(center: CGPoint(x: 125, y: 2460), radius: 165, base: spec.accent.withAlphaComponent(0.86), highlight: .white)
        drawOrb(center: CGPoint(x: 1130, y: 245), radius: 185, base: spec.colors.last!.withAlphaComponent(0.82), highlight: spec.accent)
        drawOrb(center: CGPoint(x: 1090, y: 2505), radius: 120, base: color("#35BDE3", 0.74), highlight: .white)
        if spec.confetti { drawConfetti(accent: spec.accent, dense: true) }

        drawCopyPanel()
        drawPill(spec.tag, rect: CGRect(x: 90, y: 2680, width: 390, height: 70), fill: NSColor.white.withAlphaComponent(0.16), stroke: NSColor.white.withAlphaComponent(0.28), fontSize: 25)
        drawHeroText(spec.title, in: CGRect(x: 90, y: 2484, width: 1084, height: 186), font: .systemFont(ofSize: 80, weight: .black), color: .white, lineSpacing: -2)
        drawHeroText(spec.subtitle, in: CGRect(x: 94, y: 2386, width: 1066, height: 88), font: .systemFont(ofSize: 30, weight: .heavy), color: NSColor.white.withAlphaComponent(0.98), lineSpacing: 3)

        drawPhone(image: source, spec: spec)

        drawPill(spec.bottomLabel, rect: CGRect(x: 86, y: 94, width: 560, height: 70), fill: NSColor.black.withAlphaComponent(0.32), stroke: NSColor.white.withAlphaComponent(0.2), fontSize: 24)
        drawOutlinedText(spec.burst, center: CGPoint(x: 980, y: 130), color: spec.accent, size: 62)
        return true
    }

    guard
        let tiff = output.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [.compressionFactor: 0.92])
    else {
        print("Could not encode \(spec.out)")
        return
    }

    let destination = outDir.appendingPathComponent(spec.out)
    do {
        try data.write(to: destination)
        print("wrote \(destination.path)")
    } catch {
        print("Could not write \(destination.path): \(error)")
    }
}

for spec in specs {
    render(spec)
}
