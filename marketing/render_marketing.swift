#!/usr/bin/env swift
//
// Composes branded App Store marketing screenshots for SugarShift.
// Each output: 1320×2868 (iPhone 17 Pro Max App Store size)
//   - Slow gradient background (per-screen palette)
//   - Decorative bubble shapes
//   - "Pill" tag eyebrow
//   - Bold headline + supporting copy
//   - Centered phone screenshot floating
//
//   Usage:
//     swift marketing/render_marketing.swift
//
import AppKit

let scriptURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let inDir = scriptURL.appendingPathComponent("raw").path
let outDir = scriptURL.path

func raw(_ preferred: String, fallback: String? = nil) -> String {
    let preferredPath = "\(inDir)/\(preferred)"
    if FileManager.default.fileExists(atPath: preferredPath) { return preferred }
    if let fallback {
        let fallbackPath = "\(inDir)/\(fallback)"
        if FileManager.default.fileExists(atPath: fallbackPath) {
            print("Missing \(preferred); using \(fallback) until the level 100 screenshot is recaptured.")
            return fallback
        }
    }
    return preferred
}

struct ScreenSpec {
    let raw: String           // filename in raw/
    let out: String           // output filename
    let tag: String
    let title: String
    let subtitle: String
    let topColor: NSColor
    let midColor: NSColor
    let bottomColor: NSColor
    let pillColor: NSColor
}

func c(_ hex: String, alpha: CGFloat = 1.0) -> NSColor {
    var v: UInt64 = 0
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    Scanner(string: s).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >>  8) & 0xFF) / 255,
                   blue:  CGFloat( v        & 0xFF) / 255,
                   alpha: alpha)
}

let specs: [ScreenSpec] = [
    .init(raw: "01-splash.png",
          out: "marketing-01-splash.png",
          tag: "WELCOME",
          title: "Sweet Match\nMagic",
          subtitle: "A dreamy match-3 puzzle\nwith a 200-level campaign.",
          topColor:    c("#FBCFE8"),
          midColor:    c("#DDD6FE"),
          bottomColor: c("#A7F3D0"),
          pillColor:   c("#F472B6")),

    .init(raw: "02-game-level1.png",
          out: "marketing-02-tap-and-match.png",
          tag: "TAP & MATCH",
          title: "Match 3\nor More",
          subtitle: "Swap glossy candies to clear\nthe board and chase combos.",
          topColor:    c("#5EEAD4"),
          midColor:    c("#22D3EE"),
          bottomColor: c("#3B82F6"),
          pillColor:   c("#0EA5E9")),

    .init(raw: "03-game-level5-ice.png",
          out: "marketing-03-frost-and-locks.png",
          tag: "OBSTACLES",
          title: "Crack the\nFrost",
          subtitle: "Ice and locks block your way.\nCascade through them.",
          topColor:    c("#BAE6FD"),
          midColor:    c("#7DD3FC"),
          bottomColor: c("#0E7490"),
          pillColor:   c("#0284C7")),

    .init(raw: "04-game-level7-donut.png",
          out: "marketing-04-shapes.png",
          tag: "EVERY LEVEL UNIQUE",
          title: "200 Levels.\nFresh Boards.",
          subtitle: "Donuts, diamonds, hourglasses.\nEvery level looks new.",
          topColor:    c("#FB923C"),
          midColor:    c("#F97316"),
          bottomColor: c("#9A3412"),
          pillColor:   c("#EA580C")),

    .init(raw: "05-game-level13-cross.png",
          out: "marketing-05-combos.png",
          tag: "BIG COMBOS",
          title: "Stack Combos\nfor Mega Score",
          subtitle: "Chain cascades. Watch confetti\nfly when you hit Sugar Rush.",
          topColor:    c("#F9A8D4"),
          midColor:    c("#EC4899"),
          bottomColor: c("#831843"),
          pillColor:   c("#DB2777")),

    .init(raw: raw("06-game-level200-finale.png", fallback: "06-game-level100-finale.png"),
          out: "marketing-06-finale.png",
          tag: "THE SUGAR CROWN",
          title: "Reach\nLevel 200",
          subtitle: "Bomb storms, locks, and ice\nstand between you and victory.",
          topColor:    c("#A5B4FC"),
          midColor:    c("#6366F1"),
          bottomColor: c("#312E81"),
          pillColor:   c("#4F46E5"))
]

let canvasW: CGFloat = 1320
let canvasH: CGFloat = 2868

// Emoji-free "•" shape we use as bubble decoration
func drawBubble(at center: CGPoint, radius: CGFloat, color: NSColor, in ctx: CGContext) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(g,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius,
                           options: [])
}

func render(_ spec: ScreenSpec) {
    let image = NSImage(size: CGSize(width: canvasW, height: canvasH), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let cs = CGColorSpaceCreateDeviceRGB()

        // ── 1. Diagonal gradient background
        let bg = CGGradient(colorsSpace: cs,
                            colors: [spec.topColor.cgColor,
                                     spec.midColor.cgColor,
                                     spec.bottomColor.cgColor] as CFArray,
                            locations: [0.0, 0.5, 1.0])!
        ctx.drawLinearGradient(bg,
                               start: CGPoint(x: 0, y: canvasH),
                               end: CGPoint(x: canvasW, y: 0),
                               options: [])

        // ── 2. Decorative bubbles
        drawBubble(at: CGPoint(x: canvasW * 0.78, y: canvasH * 0.78),
                   radius: 720, color: NSColor.white.withAlphaComponent(0.18),
                   in: ctx)
        drawBubble(at: CGPoint(x: canvasW * 0.18, y: canvasH * 0.32),
                   radius: 520, color: NSColor.white.withAlphaComponent(0.10),
                   in: ctx)
        drawBubble(at: CGPoint(x: canvasW * 0.92, y: canvasH * 0.18),
                   radius: 280, color: spec.topColor.withAlphaComponent(0.4),
                   in: ctx)
        drawBubble(at: CGPoint(x: canvasW * 0.05, y: canvasH * 0.85),
                   radius: 360, color: spec.bottomColor.withAlphaComponent(0.4),
                   in: ctx)

        // ── 3. Tag eyebrow pill (top-left, near canvas top)
        let pillX: CGFloat = 100
        let pillBottomY: CGFloat = 2700        // pill rect bottom
        let pillH: CGFloat = 64
        let tagAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: NSColor.white,
            .kern: 2.5
        ]
        let tagSize = (spec.tag as NSString).size(withAttributes: tagAttrs)
        let pillW = tagSize.width + 60
        let pillRect = CGRect(x: pillX, y: pillBottomY, width: pillW, height: pillH)
        let pillPath = NSBezierPath(roundedRect: pillRect,
                                    xRadius: pillH / 2, yRadius: pillH / 2)
        pillPath.lineWidth = 3
        NSColor.white.withAlphaComponent(0.95).setStroke()
        pillPath.stroke()
        (spec.tag as NSString).draw(at: CGPoint(x: pillX + 30,
                                                y: pillBottomY + (pillH - tagSize.height) / 2),
                                    withAttributes: tagAttrs)

        // ── 4. Headline (under the pill, 2 lines)
        let headlineAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 110, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: { let p = NSMutableParagraphStyle()
                                p.lineSpacing = -8
                                p.lineBreakMode = .byWordWrapping
                                return p }()
        ]
        let titleRect = CGRect(x: 100, y: 2360,
                               width: canvasW - 200, height: 290)
        (spec.title as NSString).draw(in: titleRect, withAttributes: headlineAttrs)

        // ── 5. Subtitle
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 40, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
            .paragraphStyle: { let p = NSMutableParagraphStyle()
                                p.lineSpacing = 6
                                return p }()
        ]
        let subRect = CGRect(x: 100, y: 2120,
                             width: canvasW - 200, height: 180)
        (spec.subtitle as NSString).draw(in: subRect, withAttributes: subAttrs)

        // ── 6. Phone screenshot — smaller, floats in lower half, slight overflow at bottom
        let rawPath = "\(inDir)/\(spec.raw)"
        guard let raw = NSImage(contentsOfFile: rawPath) else {
            print("Missing raw: \(rawPath)")
            return false
        }

        let screenshotW: CGFloat = canvasW * 0.66
        let aspect = raw.size.height / raw.size.width
        let screenshotH = screenshotW * aspect
        let phoneX = (canvasW - screenshotW) / 2
        let phoneY: CGFloat = -180             // slight overflow off bottom edge

        // Drop shadow under phone
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -30),
                      blur: 60,
                      color: NSColor.black.withAlphaComponent(0.45).cgColor)
        // Rounded mask
        let cornerR: CGFloat = 84
        let phoneRect = CGRect(x: phoneX, y: phoneY,
                               width: screenshotW, height: screenshotH)
        let mask = NSBezierPath(roundedRect: phoneRect,
                                xRadius: cornerR, yRadius: cornerR)
        NSColor.black.setFill()
        mask.fill()
        ctx.restoreGState()

        ctx.saveGState()
        mask.addClip()
        raw.draw(in: phoneRect,
                 from: CGRect(origin: .zero, size: raw.size),
                 operation: .copy,
                 fraction: 1.0)
        ctx.restoreGState()

        return true
    }

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Encode failed for \(spec.out)")
        return
    }
    let url = URL(fileURLWithPath: "\(outDir)/\(spec.out)")
    try? png.write(to: url)
    print("✓ \(spec.out)")
}

for spec in specs { render(spec) }
print("All marketing images rendered to \(outDir)")
