import UIKit

enum Theme {
    static let colors: [String] = [
        "#F97316", // orange
        "#22D3EE", // cyan
        "#10B981", // emerald
        "#A78BFA", // violet
        "#F59E0B", // amber
        "#EF4444"  // red
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
