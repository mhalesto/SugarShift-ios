import UIKit

/// Generates the SugarShift app icon at 1024×1024 procedurally.
///
/// In DEBUG builds, `dumpIfNeeded()` writes the PNG to the app's Documents
/// directory on first run and prints the path. Drag the file from there into
/// `Assets.xcassets/AppIcon.appiconset` (replace the universal/dark/tinted
/// slots), then comment out / remove the call.
enum IconRenderer {

    static func renderIcon(size: CGFloat = 1024) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // ── Dreamy pastel diagonal gradient
            let space = CGColorSpaceCreateDeviceRGB()
            let bgColors = [
                UIColor(hex: "#FBCFE8").cgColor, // pink
                UIColor(hex: "#DDD6FE").cgColor, // lavender
                UIColor(hex: "#A7F3D0").cgColor, // mint
                UIColor(hex: "#FED7AA").cgColor  // peach
            ] as CFArray
            let bgGrad = CGGradient(colorsSpace: space, colors: bgColors,
                                     locations: [0.0, 0.4, 0.7, 1.0])!
            cg.drawLinearGradient(bgGrad,
                                  start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: size, y: size),
                                  options: [])

            // ── Soft white halo behind the central monogram
            let haloCenter = CGPoint(x: size / 2, y: size / 2)
            let haloColors = [
                UIColor.white.withAlphaComponent(0.7).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray
            let haloGrad = CGGradient(colorsSpace: space, colors: haloColors,
                                       locations: [0.0, 1.0])!
            cg.drawRadialGradient(haloGrad,
                                  startCenter: haloCenter, startRadius: 0,
                                  endCenter: haloCenter, endRadius: size * 0.42,
                                  options: [])

            // ── Bokeh dots (soft, low alpha) for dreamy texture
            let bokehColors: [UIColor] = [
                UIColor(hex: "#FFFFFF").withAlphaComponent(0.55),
                UIColor(hex: "#FBCFE8").withAlphaComponent(0.55),
                UIColor(hex: "#A7F3D0").withAlphaComponent(0.45),
                UIColor(hex: "#FED7AA").withAlphaComponent(0.45)
            ]
            let bokehSpots: [(CGFloat, CGFloat, CGFloat, UIColor)] = [
                (size * 0.18, size * 0.22, 110, bokehColors[0]),
                (size * 0.82, size * 0.18, 130, bokehColors[1]),
                (size * 0.85, size * 0.78, 150, bokehColors[2]),
                (size * 0.15, size * 0.80, 95,  bokehColors[3]),
                (size * 0.55, size * 0.88, 80,  bokehColors[1])
            ]
            for (x, y, r, c) in bokehSpots {
                let center = CGPoint(x: x, y: y)
                let cs = [c.cgColor, c.withAlphaComponent(0).cgColor] as CFArray
                let g = CGGradient(colorsSpace: space, colors: cs, locations: [0.0, 1.0])!
                cg.drawRadialGradient(g,
                                      startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: r,
                                      options: [])
            }

            // ── Monogram: stylized "S" + "S" (or single big S with sparkle)
            // Using SF-style heavy text for crispness at any rendering size
            let mono = "S"
            let para = NSMutableParagraphStyle()
            para.alignment = .center

            // Shadow underneath
            let shadowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.62, weight: .black),
                .foregroundColor: UIColor(white: 0, alpha: 0.18),
                .paragraphStyle: para
            ]
            let shadowRect = CGRect(x: 18, y: size * 0.13, width: size, height: size * 0.74)
            (mono as NSString).draw(in: shadowRect, withAttributes: shadowAttrs)

            // Main pink "S"
            let pinkAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.62, weight: .black),
                .foregroundColor: UIColor(hex: "#EC4899"),
                .paragraphStyle: para
            ]
            let mainRect = CGRect(x: 0, y: size * 0.10, width: size, height: size * 0.74)
            (mono as NSString).draw(in: mainRect, withAttributes: pinkAttrs)

            // Highlight stroke on top half — subtle gradient sheen
            cg.saveGState()
            cg.addRect(CGRect(x: 0, y: 0, width: size, height: size * 0.5))
            cg.clip()
            let sheenAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.62, weight: .black),
                .foregroundColor: UIColor.white.withAlphaComponent(0.35),
                .paragraphStyle: para
            ]
            (mono as NSString).draw(in: mainRect, withAttributes: sheenAttrs)
            cg.restoreGState()

            // ── Sparkle accent
            let sparkleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.18, weight: .black),
                .foregroundColor: UIColor.white,
                .paragraphStyle: para
            ]
            let sparkleSize = size * 0.18
            ("✦" as NSString).draw(
                in: CGRect(x: size * 0.62, y: size * 0.18,
                           width: sparkleSize, height: sparkleSize),
                withAttributes: sparkleAttrs)

            // ── Tiny fruit cluster bottom-center (peek of identity)
            let fruitAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.12),
                .paragraphStyle: para
            ]
            let fruitW = size * 0.5
            ("🍒  🍇  🍌" as NSString).draw(
                in: CGRect(x: (size - fruitW) / 2, y: size * 0.78,
                           width: fruitW, height: size * 0.15),
                withAttributes: fruitAttrs)
        }
    }

    /// In DEBUG builds, write a fresh icon PNG to the app's Documents folder once.
    /// Watch the console for the path; drag the file into Assets.xcassets and
    /// then remove this call from `AppDelegate.didFinishLaunching`.
    static func dumpIfNeeded() {
        #if DEBUG
        guard let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent("SugarShift-AppIcon-1024.png")
        // Re-render every launch so iterations are quick
        let img = renderIcon(size: 1024)
        if let data = img.pngData() {
            try? data.write(to: url, options: .atomic)
            print("📦 SugarShift icon written: \(url.path)")
        }
        #endif
    }
}
