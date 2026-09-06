import SpriteKit

/// Small cached surfaces with the soft, molded edges of the gameplay reference.
/// All text, objective art, progress and interaction are separate live nodes.
enum GameplayHUDArt {
    private static var textures: [String: SKTexture] = [:]

    private static func sprite(_ key: String, size: CGSize, draw: (CGContext) -> Void) -> SKSpriteNode {
        let cacheKey = "\(key):\(size.width):\(size.height)"
        if let texture = textures[cacheKey] { return SKSpriteNode(texture: texture, size: size) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
        let texture = SKTexture(image: image)
        textures[cacheKey] = texture
        return SKSpriteNode(texture: texture, size: size)
    }

    private static func gradient(_ cg: CGContext, path: UIBezierPath, colors: [String], height: CGFloat) {
        cg.saveGState()
        path.addClip()
        let colors = colors.map { UIColor(hex: $0).cgColor }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        cg.restoreGState()
    }

    static func card(size: CGSize, ice: Bool, inset: Bool = false, theme: WorldThemeDefinition? = nil) -> SKSpriteNode {
        sprite("card:\(theme?.id ?? String(ice)):\(inset)", size: size) { cg in
            let s = size.height / (inset ? 82 : 140)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 3 * s, dy: 3 * s)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: (inset ? 17 : 23) * s)
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 2 * s), blur: 3 * s,
                         color: UIColor(hex: ice ? "#348CCD" : "#BD796C").withAlphaComponent(0.36).cgColor)
            UIColor(hex: ice ? "#AFDFFF" : "#EDBCAF").setFill()
            path.fill()
            cg.restoreGState()
            let palette = theme?.cardPalette
            let colors = inset ? (ice ? ["#FFFFFF", "#EAF8FF"] : ["#FFFFFF", "#FFF6F5"])
                : palette.map { [$0.top, $0.middle, $0.bottom] }
                    ?? (ice ? ["#F2FDFF", "#D3F3FF", "#A9DFFF"] : ["#FFF5E9", "#FFE1D5", "#F9D2C7"])
            gradient(cg, path: path, colors: colors, height: size.height)
            UIColor.white.withAlphaComponent(0.95).setStroke()
            path.lineWidth = 1.4 * s
            path.stroke()
            let inner = UIBezierPath(roundedRect: rect.insetBy(dx: 1.5 * s, dy: 1.5 * s), cornerRadius: (inset ? 16 : 22) * s)
            UIColor(hex: ice ? "#8CD2F7" : "#F2BFAF").withAlphaComponent(0.48).setStroke()
            inner.lineWidth = 0.8 * s
            inner.stroke()
        }
    }

    static func icing(size: CGSize, ice: Bool, color: String? = nil) -> SKSpriteNode {
        sprite("icing:\(ice):\(color ?? "pink")", size: size) { cg in
            let w = size.width, h = size.height
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 1, y: h * 0.84))
            path.addCurve(to: CGPoint(x: w * 0.18, y: 2), controlPoint1: CGPoint(x: 0, y: h * 0.24), controlPoint2: CGPoint(x: w * 0.04, y: 0))
            path.addCurve(to: CGPoint(x: w - 2, y: 2), controlPoint1: CGPoint(x: w * 0.45, y: -1), controlPoint2: CGPoint(x: w * 0.79, y: 7))
            path.addCurve(to: CGPoint(x: w * 0.81, y: h * 0.2), controlPoint1: CGPoint(x: w, y: h * 0.3), controlPoint2: CGPoint(x: w * 0.93, y: h * 0.25))
            path.addCurve(to: CGPoint(x: w * 0.38, y: h * 0.12), controlPoint1: CGPoint(x: w * 0.66, y: h * 0.22), controlPoint2: CGPoint(x: w * 0.59, y: h * 0.02))
            path.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.32), controlPoint1: CGPoint(x: w * 0.28, y: h * 0.17), controlPoint2: CGPoint(x: w * 0.29, y: h * 0.35))
            path.addCurve(to: CGPoint(x: w * 0.062, y: h * 0.89), controlPoint1: CGPoint(x: w * 0.05, y: h * 0.31), controlPoint2: CGPoint(x: w * 0.078, y: h * 0.74))
            path.addCurve(to: CGPoint(x: 1, y: h * 0.84), controlPoint1: CGPoint(x: w * 0.048, y: h * 1.05), controlPoint2: CGPoint(x: 0, y: h))
            path.close()
            gradient(cg, path: path, colors: ice ? ["#FFFFFF", "#DBF9FF", "#46CDFB"] : ["#FFDCDF", color ?? "#FF4D99", color ?? "#FF81BA"], height: h)
            UIColor(hex: ice ? "#F2FEFF" : "#FFB3D6").setStroke()
            path.lineWidth = 1.1
            path.stroke()
        }
    }

    static func progress(size: CGSize) -> SKSpriteNode {
        sprite("progress", size: size) { cg in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.6, dy: 0.6)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: size.height / 2)
            gradient(cg, path: path, colors: ["#008CF1", "#7AF3FF", "#00C1FF", "#008AF4"], height: size.height)
            UIColor(hex: "#0076D9").setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    static func star(size: CGFloat, earned: Bool) -> SKSpriteNode {
        sprite("star:\(earned)", size: CGSize(width: size, height: size)) { cg in
            let center = CGPoint(x: size / 2, y: size / 2)
            let points = (0..<10).map { index -> CGPoint in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
                let radius = size * (index.isMultiple(of: 2) ? 0.41 : 0.215)
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }
            let path = UIBezierPath()
            // Round every tip and valley rather than using a sharp polygon.
            for i in points.indices {
                let previous = points[(i + 9) % 10], point = points[i], next = points[(i + 1) % 10]
                let a = CGPoint(x: point.x * 0.87 + previous.x * 0.13, y: point.y * 0.87 + previous.y * 0.13)
                let b = CGPoint(x: point.x * 0.87 + next.x * 0.13, y: point.y * 0.87 + next.y * 0.13)
                if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
                path.addQuadCurve(to: b, controlPoint: point)
            }
            path.close()
            path.lineJoinStyle = .round
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: size * 0.035), blur: size * 0.04, color: UIColor(hex: "#99634D").withAlphaComponent(0.5).cgColor)
            UIColor(hex: "#FFF4DE").setStroke()
            path.lineWidth = size * 0.11
            path.stroke()
            cg.restoreGState()
            UIColor(hex: earned ? "#CB7B12" : "#797386").setStroke()
            path.lineWidth = size * 0.045
            path.stroke()
            gradient(cg, path: path, colors: earned ? ["#FFF9A0", "#FFE457", "#FFB91C"] : ["#FFFFFF", "#D4D7E2", "#AEB5CB"], height: size)
            cg.saveGState()
            cg.translateBy(x: center.x, y: center.y)
            cg.scaleBy(x: 0.81, y: 0.81)
            cg.translateBy(x: -center.x, y: -center.y)
            UIColor(hex: earned ? "#FFF596" : "#EFF7FF").setStroke()
            path.lineWidth = size * 0.035
            path.stroke()
            cg.restoreGState()
        }
    }

    static func orb(diameter: CGFloat, color: String) -> SKSpriteNode {
        sprite("orb:\(color)", size: CGSize(width: diameter, height: diameter)) { cg in
            let bounds = CGRect(x: 2, y: 2, width: diameter - 4, height: diameter - 4)
            let path = UIBezierPath(ovalIn: bounds)
            let tint = UIColor(hex: color)
            cg.saveGState()
            path.addClip()
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [tint.lighter(by: 0.5).cgColor, tint.cgColor, tint.darker(by: 0.4).cgColor] as CFArray, locations: [0, 0.55, 1])!
            cg.drawRadialGradient(gradient, startCenter: CGPoint(x: diameter * 0.32, y: diameter * 0.22), startRadius: 0,
                                  endCenter: CGPoint(x: diameter * 0.45, y: diameter * 0.42), endRadius: diameter * 0.65, options: .drawsAfterEndLocation)
            cg.restoreGState()
            UIColor.white.withAlphaComponent(0.93).setStroke()
            path.lineWidth = 1.3
            path.stroke()
            let gleam = UIBezierPath(ovalIn: CGRect(x: diameter * 0.19, y: diameter * 0.1, width: diameter * 0.13, height: diameter * 0.25))
            UIColor.white.withAlphaComponent(0.7).setFill()
            gleam.fill()
        }
    }

    static func tile(size: CGFloat) -> SKSpriteNode {
        sprite("tile", size: CGSize(width: size, height: size)) { cg in
            let path = UIBezierPath(roundedRect: CGRect(x: 0.6, y: 0.6, width: size - 1.2, height: size - 1.2), cornerRadius: size * 0.16)
            gradient(cg, path: path, colors: ["#071728", "#122E48", "#102339"], height: size)
            UIColor(hex: "#496078").withAlphaComponent(0.48).setStroke()
            path.lineWidth = 0.7
            path.stroke()
        }
    }
}

/// Spread the milestones like the reference while interpolating between the
/// actual score thresholds. Changing presentation never changes star rewards.
enum HUDScoreProgress {
    static let starStops: [CGFloat] = [0.45, 0.68, 0.93]
    static func fraction(score: Int, thresholds: (one: Int, two: Int, three: Int)) -> CGFloat {
        let scores = [0, thresholds.one, thresholds.two, thresholds.three]
        let positions: [CGFloat] = [0] + starStops
        for i in 1..<scores.count where score < scores[i] {
            let part = CGFloat(max(0, score - scores[i - 1])) / CGFloat(max(1, scores[i] - scores[i - 1]))
            return positions[i - 1] + part * (positions[i] - positions[i - 1])
        }
        let extra = CGFloat(max(0, score - thresholds.three)) / CGFloat(max(1, thresholds.three / 4))
        return min(1, starStops[2] + extra * (1 - starStops[2]))
    }
}
