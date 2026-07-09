#!/usr/bin/env swift
// App Store screenshot renderer — NO device mockups.
// Apple rejected 1.0 (9) under 2.3.10 because the framed phone/tablet mockups
// read as non-iOS devices. This renders the raw simulator captures as large
// unframed "screenshot cards": copy panel on top, the real app filling the
// rest of the canvas.
//
// Outputs:
//   iphone-6.5-appstore-fullbleed/  (1284 x 2778, from raw-real-iphone)
//   ipad-13-fullbleed/              (2064 x 2752, from raw-ipad)
import AppKit

let scriptURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let newDir = scriptURL.deletingLastPathComponent()

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

func darker(_ c: NSColor, _ factor: CGFloat) -> NSColor {
    let rgb = c.usingColorSpace(.sRGB)!
    return NSColor(
        srgbRed: rgb.redComponent * factor,
        green: rgb.greenComponent * factor,
        blue: rgb.blueComponent * factor,
        alpha: rgb.alphaComponent
    )
}

struct Spec {
    let raw: String
    let out: String
    let tag: String
    let title: String
    let subtitle: String
    let colors: [NSColor]
    let accent: NSColor
    let panel: NSColor
    let confetti: Bool
}

struct SetConfig {
    let rawDir: URL
    let outDir: URL
    let canvas: CGSize
    let titleSize: CGFloat
    let subtitleSize: CGFloat
    let specs: [Spec]
}

let iphoneSpecs: [Spec] = [
    .init(
        raw: "14-fish-hero.png",
        out: "01-fish-hero.png",
        tag: "MEET THE FISH",
        title: "Match a Square.\nHatch a Fish.",
        subtitle: "2×2 matches spawn seekers that hunt your goal tiles.",
        colors: [color("#0F766E"), color("#22D3EE"), color("#A5F3FC")],
        accent: color("#FFBE1B"),
        panel: color("#0891B2"),
        confetti: true
    ),
    .init(
        raw: "15-daily-board.png",
        out: "02-daily-board.png",
        tag: "DAILY BOARD",
        title: "One Board.\nThe Whole World.",
        subtitle: "Everyone plays the same puzzle today — share your result.",
        colors: [color("#065F46"), color("#34D399"), color("#D1FAE5")],
        accent: color("#FDE68A"),
        panel: color("#2FBE71"),
        confetti: false
    ),
    .init(
        raw: "03-clean-board.png",
        out: "03-fair-play.png",
        tag: "FAIR PLAY",
        title: "Every Level Beatable.\nNo Paywalls.",
        subtitle: "200 simulated, hand-tuned boards. An undo button. Zero forced ads.",
        colors: [color("#F8DCEB"), color("#E6DDF7"), color("#B9EFD4")],
        accent: color("#F6508A"),
        panel: color("#8A6DFF"),
        confetti: false
    ),
    .init(
        raw: "11-level8-sweet-lightning.png",
        out: "04-level8-sweet-lightning.png",
        tag: "LEVEL 8 ACTION",
        title: "Sweet\nLightning Clears",
        subtitle: "Blast a full column, crack frost, and keep the combo moving.",
        colors: [color("#63DAD4"), color("#B8EEE8"), color("#F6508A")],
        accent: color("#FFBE1B"),
        panel: color("#F6508A"),
        confetti: true
    ),
    .init(
        raw: "01-huge-smash.png",
        out: "05-huge-smash-combos.png",
        tag: "REAL GAMEPLAY",
        title: "Huge Smash\nCombos",
        subtitle: "Match fruit, trigger cascades, and watch the board celebrate.",
        colors: [color("#66DED7"), color("#9BE8E1"), color("#F6508A")],
        accent: color("#FFBE1B"),
        panel: color("#F6508A"),
        confetti: true
    ),
    .init(
        raw: "07-candy-map-wide.png",
        out: "06-candy-road-map.png",
        tag: "CANDY ROAD",
        title: "Follow the\nLevel Map",
        subtitle: "Unlock new stops, collect rewards, and keep moving forward.",
        colors: [color("#F9DCEB"), color("#DFF6E9"), color("#F6D1EA")],
        accent: color("#F6508A"),
        panel: color("#8A6DFF"),
        confetti: false
    ),
    .init(
        raw: "04-plan-moves.png",
        out: "07-mastery-not-grind.png",
        tag: "MASTERY, NOT GRIND",
        title: "Chase Stars\nBefore Moves Run Out",
        subtitle: "Crown challenges, 12-swap sprints, and no-booster medal runs.",
        colors: [color("#5AD3CD"), color("#B6ECE6"), color("#7BC4F3")],
        accent: color("#F6508A"),
        panel: color("#F6508A"),
        confetti: false
    ),
    .init(
        raw: "10-title-clean.png",
        out: "08-sugarshift-brand.png",
        tag: "ARCADE PUZZLE",
        title: "One More\nSweet Move",
        subtitle: "Simple matching, loud rewards, and quick sessions anytime.",
        colors: [color("#F7DCEB"), color("#E4DEF8"), color("#B8EED5")],
        accent: color("#8A6DFF"),
        panel: color("#2FBE71"),
        confetti: false
    )
]

let ipadSpecs: [Spec] = [
    .init(
        raw: "01-portal.png",
        out: "01-step-into-sugarshift.png",
        tag: "SUGARSHIFT",
        title: "Step Into\nthe Sugar Portal",
        subtitle: "A match-3 board that feels bright, fast, and alive.",
        colors: [color("#FF4FA3"), color("#8A3FFC"), color("#22D3EE")],
        accent: color("#FFD166"),
        panel: color("#FFAA00"),
        confetti: false
    ),
    .init(
        raw: "09-fish-hero.png",
        out: "02-fish-hero.png",
        tag: "MEET THE FISH",
        title: "Match a Square.\nHatch a Fish.",
        subtitle: "2×2 matches spawn seekers that hunt your goal tiles.",
        colors: [color("#0F766E"), color("#22D3EE"), color("#A5F3FC")],
        accent: color("#FFD166"),
        panel: color("#0891B2"),
        confetti: true
    ),
    .init(
        raw: "10-daily-board.png",
        out: "03-daily-board.png",
        tag: "DAILY BOARD",
        title: "One Board.\nThe Whole World.",
        subtitle: "Everyone plays the same seeded puzzle today — share your result.",
        colors: [color("#065F46"), color("#34D399"), color("#D1FAE5")],
        accent: color("#FDE68A"),
        panel: color("#2FBE71"),
        confetti: false
    ),
    .init(
        raw: "02-combo-rush.png",
        out: "04-chain-combos.png",
        tag: "COMBO RUSH",
        title: "Chain Combos\nAcross the Grid",
        subtitle: "Cascades, score pops, and Sugar Rush moments stack together.",
        colors: [color("#FF3D81"), color("#F97316"), color("#7C3AED")],
        accent: color("#67E8F9"),
        panel: color("#22C7E6"),
        confetti: true
    ),
    .init(
        raw: "03-bomb-storm.png",
        out: "05-bomb-storm.png",
        tag: "BOMB STORM",
        title: "Detonate\nWild Boards",
        subtitle: "Higher levels stack specials, blockers, and explosive turns.",
        colors: [color("#1D4ED8"), color("#A21CAF"), color("#F59E0B")],
        accent: color("#FB7185"),
        panel: color("#34C76C"),
        confetti: true
    ),
    .init(
        raw: "04-frost-locks.png",
        out: "06-crack-frost-locks.png",
        tag: "OBSTACLES",
        title: "Crack Frost\nand Locks",
        subtitle: "Break layered blockers before your last move disappears.",
        colors: [color("#38BDF8"), color("#2563EB"), color("#312E81")],
        accent: color("#BAE6FD"),
        panel: color("#F6508A"),
        confetti: false
    ),
    .init(
        raw: "05-shape-worlds.png",
        out: "07-shape-worlds.png",
        tag: "FRESH LEVELS",
        title: "Every Board\nHas a New Shape",
        subtitle: "Donuts, crowns, lightning, hearts, and strange puzzle cuts.",
        colors: [color("#14B8A6"), color("#A3E635"), color("#F43F5E")],
        accent: color("#FEF08A"),
        panel: color("#8A6DFF"),
        confetti: false
    ),
    .init(
        raw: "08-crown.png",
        out: "08-claim-the-crown.png",
        tag: "FINAL VAULT",
        title: "Claim the\nSugar Crown",
        subtitle: "Reach level 200 and survive the biggest board in the game.",
        colors: [color("#020617"), color("#4C1D95"), color("#DB2777")],
        accent: color("#FBBF24"),
        panel: color("#FBBF24"),
        confetti: true
    )
]

let sets: [SetConfig] = [
    .init(
        rawDir: newDir.appendingPathComponent("raw-real-iphone"),
        outDir: newDir.appendingPathComponent("iphone-6.5-appstore-fullbleed"),
        canvas: CGSize(width: 1284, height: 2778),
        titleSize: 84,
        subtitleSize: 30,
        specs: iphoneSpecs
    ),
    .init(
        rawDir: newDir.appendingPathComponent("raw-real-iphone"),
        outDir: newDir.appendingPathComponent("iphone-6.9-appstore-fullbleed"),
        canvas: CGSize(width: 1320, height: 2868),
        titleSize: 86,
        subtitleSize: 31,
        specs: iphoneSpecs
    ),
    .init(
        rawDir: newDir.appendingPathComponent("raw-ipad"),
        outDir: newDir.appendingPathComponent("ipad-13-fullbleed"),
        canvas: CGSize(width: 2064, height: 2752),
        titleSize: 92,
        subtitleSize: 34,
        specs: ipadSpecs
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

func drawGradient(canvas: CGSize, colors: [NSColor]) {
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

func drawMotionLines(canvas: CGSize, color: NSColor) {
    color.setStroke()
    for i in 0..<13 {
        let path = NSBezierPath()
        path.lineWidth = CGFloat(5 + (i % 3) * 4)
        let y = canvas.height * 0.18 + CGFloat(i) * (canvas.height / 19)
        path.move(to: CGPoint(x: -180, y: y))
        path.curve(
            to: CGPoint(x: canvas.width + 180, y: y + CGFloat(i % 2 == 0 ? 85 : -75)),
            controlPoint1: CGPoint(x: canvas.width * 0.28, y: y + 70),
            controlPoint2: CGPoint(x: canvas.width * 0.72, y: y - 70)
        )
        path.stroke()
    }
}

func drawConfetti(canvas: CGSize, accent: NSColor) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let palette = [color("#FFBE1B"), color("#F6508A"), color("#8A6DFF"), color("#35BDE3"), color("#FFFFFF")]
    for i in 0..<90 {
        let x = CGFloat((i * 181 + 43) % Int(canvas.width + 220)) - 110
        let y = CGFloat((i * 269 + 131) % Int(canvas.height))
        let w = CGFloat(10 + (i % 4) * 7)
        let h = CGFloat(5 + (i % 3) * 5)
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: CGFloat((i * 23) % 180) * .pi / 180)
        palette[i % palette.count].withAlphaComponent(i % 5 == 0 ? 0.4 : 0.7).setFill()
        NSBezierPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), xRadius: 2, yRadius: 2).fill()
        context.restoreGState()
    }
    drawRadial(center: CGPoint(x: canvas.width * 0.72, y: canvas.height * 0.18), radius: 420, color: accent.withAlphaComponent(0.26))
}

func drawHeroText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, lineSpacing: CGFloat = 0, stroke: NSColor? = nil) {
    let baseAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraph(.left, lineSpacing: lineSpacing)
    ]
    if let stroke {
        // Candy-style: offset darker copy below, then stroked outline pass, then clean fill.
        var dropAttrs = baseAttrs
        dropAttrs[.foregroundColor] = darker(stroke, 0.85)
        (text as NSString).draw(in: rect.offsetBy(dx: 0, dy: -7), withAttributes: dropAttrs)
        var strokeAttrs = baseAttrs
        strokeAttrs[.foregroundColor] = stroke
        strokeAttrs[.strokeColor] = stroke
        strokeAttrs[.strokeWidth] = 11.0
        (text as NSString).draw(in: rect, withAttributes: strokeAttrs)
        var fillAttrs = baseAttrs
        fillAttrs[.foregroundColor] = color
        (text as NSString).draw(in: rect, withAttributes: fillAttrs)
        return
    }
    var shadowAttrs = baseAttrs
    shadowAttrs[.foregroundColor] = NSColor.black.withAlphaComponent(0.34)
    (text as NSString).draw(in: rect.offsetBy(dx: 0, dy: -4), withAttributes: shadowAttrs)
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

func drawPill(_ text: String, x: CGFloat, topY: CGFloat, canvas: CGSize, fontSize: CGFloat) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: .black)
    let textSize = (text as NSString).size(withAttributes: [.font: font])
    let height = fontSize * 2.4
    let rect = CGRect(x: x, y: canvas.height - topY - height, width: textSize.width + fontSize * 2.4, height: height)
    fillRounded(rect, radius: rect.height / 2, color: NSColor.white.withAlphaComponent(0.22))
    strokeRounded(rect, radius: rect.height / 2, color: NSColor.white.withAlphaComponent(0.55), width: 2.5)
    let textRect = CGRect(
        x: rect.minX + fontSize * 1.2,
        y: rect.minY + (height - textSize.height) / 2 - 1,
        width: textSize.width + 8,
        height: textSize.height + 4
    )
    (text as NSString).draw(in: textRect, withAttributes: [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph(.left)
    ])
}

func drawCandyPanel(_ panel: CGRect, base: NSColor) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let path = NSBezierPath(roundedRect: panel, xRadius: 48, yRadius: 48)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 34
    shadow.shadowColor = darker(base, 0.45).withAlphaComponent(0.55)
    shadow.shadowOffset = CGSize(width: 0, height: -10)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    base.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Vertical sheen: lighter top -> base -> darker bottom, then soft diagonal stripes.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.30).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
            darker(base, 0.78).withAlphaComponent(0.55).cgColor
        ] as CFArray,
        locations: [0, 0.45, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: panel.midX, y: panel.maxY),
        end: CGPoint(x: panel.midX, y: panel.minY),
        options: []
    )
    context.saveGState()
    context.translateBy(x: panel.midX, y: panel.midY)
    context.rotate(by: -24 * .pi / 180)
    NSColor.white.withAlphaComponent(0.07).setFill()
    var x = -panel.width
    while x < panel.width {
        context.fill(CGRect(x: x, y: -panel.height, width: 80, height: panel.height * 2))
        x += 220
    }
    context.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    strokeRounded(panel, radius: 48, color: NSColor.white.withAlphaComponent(0.85), width: 5)
}

func render(spec: Spec, config: SetConfig) {
    let canvas = config.canvas
    let rawURL = config.rawDir.appendingPathComponent(spec.raw)
    guard let source = NSImage(contentsOf: rawURL) else {
        print("Missing \(rawURL.path)")
        return
    }

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width),
        pixelsHigh: Int(canvas.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Could not create bitmap for \(spec.out)")
        return
    }
    rep.size = canvas

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    // Background
    drawGradient(canvas: canvas, colors: spec.colors)
    drawMotionLines(canvas: canvas, color: NSColor.white.withAlphaComponent(0.10))
    drawRadial(center: CGPoint(x: 80, y: canvas.height * 0.9), radius: 560, color: spec.accent.withAlphaComponent(0.35))
    drawRadial(center: CGPoint(x: canvas.width - 110, y: canvas.height * 0.12), radius: 520, color: spec.colors.last!.withAlphaComponent(0.34))
    if spec.confetti { drawConfetti(canvas: canvas, accent: spec.accent) }

    // Copy panel (top)
    let margin: CGFloat = 44
    let panelHeight: CGFloat = config.titleSize * 2.6 + config.subtitleSize * 3.2 + 110
    let panel = CGRect(
        x: margin,
        y: canvas.height - margin - panelHeight,
        width: canvas.width - margin * 2,
        height: panelHeight
    )
    drawCandyPanel(panel, base: spec.panel)

    let inset: CGFloat = 40
    var cursorTop = margin + 30
    drawPill(spec.tag, x: margin + inset, topY: cursorTop, canvas: canvas, fontSize: config.subtitleSize * 0.82)
    cursorTop += config.subtitleSize * 0.82 * 2.4 + 18

    let titleHeight = config.titleSize * 2.45
    drawHeroText(
        spec.title,
        in: CGRect(x: margin + inset, y: canvas.height - cursorTop - titleHeight, width: panel.width - inset * 2, height: titleHeight),
        font: .systemFont(ofSize: config.titleSize, weight: .black),
        color: .white,
        lineSpacing: -2,
        stroke: darker(spec.panel, 0.52)
    )
    cursorTop += titleHeight + 8

    let subtitleHeight = config.subtitleSize * 2.8
    drawHeroText(
        spec.subtitle,
        in: CGRect(x: margin + inset + 4, y: canvas.height - cursorTop - subtitleHeight, width: panel.width - inset * 2, height: subtitleHeight),
        font: .systemFont(ofSize: config.subtitleSize, weight: .heavy),
        color: NSColor.white.withAlphaComponent(0.98),
        lineSpacing: 3
    )

    // Screenshot card — the real app, unframed, filling the rest of the canvas
    let gap: CGFloat = 30
    let bottomMargin: CGFloat = 48
    let shotTop = margin + panelHeight + gap
    let shotHeight = canvas.height - shotTop - bottomMargin
    let aspect = source.size.width / source.size.height
    let shotWidth = min(shotHeight * aspect, canvas.width - 80)
    let shotRect = CGRect(
        x: (canvas.width - shotWidth) / 2,
        y: bottomMargin,
        width: shotWidth,
        height: shotHeight
    )

    let shotShadow = NSShadow()
    shotShadow.shadowBlurRadius = 60
    shotShadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
    shotShadow.shadowOffset = CGSize(width: 0, height: -20)
    NSGraphicsContext.saveGraphicsState()
    shotShadow.set()
    fillRounded(shotRect, radius: 28, color: NSColor.black.withAlphaComponent(0.25))
    NSGraphicsContext.restoreGraphicsState()

    let clip = NSBezierPath(roundedRect: shotRect, xRadius: 28, yRadius: 28)
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    source.draw(in: shotRect, from: CGRect(origin: .zero, size: source.size), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    strokeRounded(shotRect, radius: 28, color: NSColor.white.withAlphaComponent(0.5), width: 3)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [.compressionFactor: 0.92]) else {
        print("Could not encode \(spec.out)")
        return
    }
    let destination = config.outDir.appendingPathComponent(spec.out)
    do {
        try data.write(to: destination)
        print("wrote \(destination.path)")
    } catch {
        print("Could not write \(destination.path): \(error)")
    }
}

for config in sets {
    try FileManager.default.createDirectory(at: config.outDir, withIntermediateDirectories: true)
    for spec in config.specs {
        render(spec: spec, config: config)
    }
}
