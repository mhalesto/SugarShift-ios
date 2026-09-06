import UIKit
import SpriteKit

enum Theme {
    static let colors: [String] = [
        "#F97316", // orange
        "#22D3EE", // cyan
        "#10B981", // emerald
        "#A78BFA", // violet
        "#F59E0B", // amber
        "#EF4444", // heart (legacy red token)
        "#EC4899"  // strawberry
    ]

    static let fruits: [String] = ["🍊", "🍇", "🫐", "🍏", "🍌", "🍒", "🍓", "🥭"]

    static func fruitIndex(forColor color: String) -> Int {
        let lc = color.lowercased()
        if let i = colors.firstIndex(where: { $0.lowercased() == lc }) {
            return i % fruits.count
        }
        var h: Int = 0
        for u in lc.unicodeScalars {
            h = (h &* 31) &+ Int(u.value)
        }
        return abs(h) % fruits.count
    }

    static func emoji(forColor color: String) -> String {
        fruits[fruitIndex(forColor: color)]
    }

    /// Human-readable fruit names parallel to `fruits`, used for VoiceOver
    /// tile labels so the board is perceivable with the screen reader on.
    static let fruitNames: [String] = [
        "orange", "grape", "blueberry", "leaf",
        "banana", "heart", "strawberry", "mango"
    ]

    static func fruitName(forColor color: String) -> String {
        fruitNames[fruitIndex(forColor: color)]
    }

    // Cache of high-res emoji rasterizations. SKLabelNode emoji rendering is
    // unreliable on some simulator builds; bake to a texture once and reuse.
    private static var textureCache: [String: SKTexture] = [:]

    /// Emoji → bundled fruit imageset name. We pre-rendered each fruit on macOS
    /// (where AppleColorEmoji works reliably) and shipped them as image assets
    /// so iOS doesn't depend on its emoji font being available at runtime.
    private static let imageNameByEmoji: [String: String] = [
        "🍊": "fruit-orange",
        "🍇": "fruit-grape",
        "🫐": "fruit-blueberry",
        "🍏": "fruit-apple",
        "🍌": "fruit-banana",
        "🍒": "fruit-cherry",
        "🍓": "fruit-strawberry",
        "🥭": "fruit-mango"
    ]

    static func emojiTexture(_ emoji: String) -> SKTexture {
        let key = "fruit:\(emoji)"
        if let hit = textureCache[key] { return hit }
        if let name = imageNameByEmoji[emoji], let img = UIImage(named: name) {
            let tex = SKTexture(image: img)
            tex.filteringMode = .linear
            textureCache[key] = tex
            return tex
        }
        // Fallback to a glossy gem if the bundled asset is missing.
        let idx = fruits.firstIndex(of: emoji) ?? 0
        return gemTexture(forColor: colors[idx % colors.count])
    }

    static func emojiTexture(forColor color: String) -> SKTexture {
        GameArt.fruit(.fromLegacyToken(color))
    }

    /// Draws a glossy candy/gem at high res for use as an SKSpriteNode texture.
    /// Each color gets a unique highlight + rim treatment so they read as
    /// distinct game pieces.
    static func gemTexture(forColor color: String) -> SKTexture {
        let key = "gem:\(color)"
        if let hit = textureCache[key] { return hit }

        let side: CGFloat = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let inset: CGFloat = 26
            let rect = CGRect(x: inset, y: inset,
                              width: side - inset * 2,
                              height: side - inset * 2)
            let base = UIColor(hex: color)

            // Soft drop shadow
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 8),
                         blur: 16,
                         color: UIColor(white: 0, alpha: 0.45).cgColor)
            cg.setFillColor(base.cgColor)
            cg.fillEllipse(in: rect)
            cg.restoreGState()

            // Radial gradient body — lighter center → base edge for sphere feel
            cg.saveGState()
            let path = UIBezierPath(ovalIn: rect)
            path.addClip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let lighter = base.lighter(by: 0.25)
            let darker  = base.darker(by: 0.18)
            let grad = CGGradient(colorsSpace: cs,
                                   colors: [lighter.cgColor, base.cgColor, darker.cgColor] as CFArray,
                                   locations: [0.0, 0.55, 1.0])!
            cg.drawRadialGradient(grad,
                                  startCenter: CGPoint(x: rect.midX - rect.width * 0.18,
                                                       y: rect.midY - rect.height * 0.20),
                                  startRadius: 0,
                                  endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                  endRadius: rect.width * 0.65,
                                  options: [])
            cg.restoreGState()

            // White top-left highlight (specular)
            cg.saveGState()
            let hi = CGRect(x: rect.minX + rect.width * 0.18,
                            y: rect.minY + rect.height * 0.14,
                            width: rect.width * 0.36,
                            height: rect.height * 0.22)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: hi)
            cg.restoreGState()

            // Tiny dot accent for extra shine
            cg.saveGState()
            let dot = CGRect(x: rect.minX + rect.width * 0.62,
                             y: rect.minY + rect.height * 0.20,
                             width: rect.width * 0.10,
                             height: rect.height * 0.10)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            cg.fillEllipse(in: dot)
            cg.restoreGState()

            // Inner rim stroke (thin darker ring)
            cg.saveGState()
            cg.setStrokeColor(UIColor(white: 0, alpha: 0.18).cgColor)
            cg.setLineWidth(3)
            cg.strokeEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
            cg.restoreGState()
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        textureCache[key] = tex
        return tex
    }
}

extension UIColor {
    func lighter(by f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r + f), green: min(1, g + f),
                       blue: min(1, b + f), alpha: a)
    }
    func darker(by f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(0, r - f), green: max(0, g - f),
                       blue: max(0, b - f), alpha: a)
    }
}

struct BoardSkin {
    let id: String
    let name: String
    let boardBg: UIColor
    let boardBorder: UIColor
    let tileBg: UIColor
    let tileBorder: UIColor
    let tileTarget: UIColor
    let tileHighlight: UIColor

    static let midnight = BoardSkin(
        id: "midnight",
        name: "Midnight",
        boardBg: UIColor(hex: "#111827"),
        boardBorder: UIColor(white: 1, alpha: 0.08),
        tileBg: UIColor(hex: "#141b29"),
        tileBorder: UIColor(white: 1, alpha: 0.06),
        tileTarget: UIColor(hex: "#1b2334"),
        tileHighlight: UIColor(white: 1, alpha: 0.5)
    )
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: CGFloat
        switch s.count {
        case 6:
            r = CGFloat((v & 0xFF0000) >> 16) / 255
            g = CGFloat((v & 0x00FF00) >> 8) / 255
            b = CGFloat(v & 0x0000FF) / 255
            a = 1
        case 8:
            r = CGFloat((v & 0xFF000000) >> 24) / 255
            g = CGFloat((v & 0x00FF0000) >> 16) / 255
            b = CGFloat((v & 0x0000FF00) >> 8) / 255
            a = CGFloat(v & 0x000000FF) / 255
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
