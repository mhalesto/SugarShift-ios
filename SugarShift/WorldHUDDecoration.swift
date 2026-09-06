import SpriteKit

/// Decoration is cached raster art made from scalable native paths; the world
/// name and all game values remain SpriteKit labels above it.
enum WorldHUDDecoration {
    private static var cache: [String: SKTexture] = [:]

    private static func draw(_ key: String, size: CGSize, _ paint: (CGContext) -> Void) -> SKSpriteNode {
        let key = "\(key):\(size)"
        if let texture = cache[key] { return SKSpriteNode(texture: texture, size: size) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { paint($0.cgContext) }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return SKSpriteNode(texture: texture, size: size)
    }

    static func snowCap(size: CGSize) -> SKSpriteNode {
        draw("snowCap", size: size) { cg in
            let w = size.width, h = size.height
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 1, y: h * 0.30))
            path.addCurve(to: CGPoint(x: w * 0.14, y: h * 0.07), controlPoint1: CGPoint(x: 4, y: 0), controlPoint2: CGPoint(x: w * 0.07, y: h * 0.01))
            for i in 1...14 {
                let x = w * CGFloat(i) / 14
                path.addQuadCurve(to: CGPoint(x: x, y: h * (i.isMultiple(of: 3) ? 0.12 : 0.07)),
                                 controlPoint: CGPoint(x: x - w / 28, y: -h * 0.04))
            }
            path.addLine(to: CGPoint(x: w - 1, y: h * 0.38))
            for i in stride(from: 14, through: 0, by: -1) {
                let x = w * CGFloat(i) / 14
                let depth = h * ([0.58, 0.32, 0.85, 0.40, 0.30][i % 5])
                path.addQuadCurve(to: CGPoint(x: x - w / 50, y: depth),
                                 controlPoint: CGPoint(x: x + w / 30, y: h * 0.24))
                path.addQuadCurve(to: CGPoint(x: max(1, x - w / 25), y: h * 0.34),
                                 controlPoint: CGPoint(x: x - w / 30, y: depth + 2))
            }
            path.close()
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor(hex: "#479BCB").withAlphaComponent(0.35).cgColor)
            UIColor(hex: "#D4F4FF").setFill(); path.fill()
            cg.restoreGState()
            cg.saveGState(); path.addClip()
            let colors = ["#FFFFFF", "#EFFCFF", "#A9EAFF", "#54C8F0"].map { UIColor(hex: $0).cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.35, 0.6, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
            UIColor.white.withAlphaComponent(0.7).setFill()
            for i in 0..<50 {
                let x = CGFloat((i * 47 + 11) % 991) / 991 * w
                let y = CGFloat((i * 19) % 23) / 100 * h
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 1, height: 0.8)).fill()
            }
            cg.restoreGState()
            UIColor.white.withAlphaComponent(0.85).setStroke(); path.lineWidth = 0.7; path.stroke()
        }
    }

    static func sign(theme: WorldThemeDefinition, size: CGSize) -> SKNode {
        let root = SKNode()
        let cosmic = theme.id == "galaxy", ice = theme.id == "ice"
        let face = draw("sign:\(theme.id)", size: size) { cg in
            let w = size.width, h = size.height
            for row in 0..<3 {
                let y = CGFloat(row) * h * 0.27 + h * 0.07
                let rect = CGRect(x: row == 1 ? 1 : 4, y: y, width: w - (row == 1 ? 2 : 8), height: h * 0.28)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
                cg.saveGState(); path.addClip()
                let colors = (cosmic ? ["#401783", "#140F39"] : ice ? ["#859DC6", "#476C9E"] : ["#CA9270", "#905133"]).map { UIColor(hex: $0).cgColor }
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: y), end: CGPoint(x: 0, y: rect.maxY), options: [])
                cg.setStrokeColor(UIColor(hex: cosmic ? "#B582FF" : "#603B30").withAlphaComponent(0.35).cgColor)
                cg.setLineWidth(0.5)
                for line in 0..<4 {
                    let grainY = y + CGFloat(line + 1) * rect.height / 5
                    cg.move(to: CGPoint(x: 8, y: grainY))
                    cg.addCurve(to: CGPoint(x: w - 7, y: grainY + 1), control1: CGPoint(x: w * 0.3, y: grainY - 2), control2: CGPoint(x: w * 0.6, y: grainY + 2))
                    cg.strokePath()
                }
                cg.restoreGState()
                UIColor(hex: cosmic ? "#C899FF" : "#E0B394").setStroke(); path.lineWidth = 0.8; path.stroke()
                for x in [CGFloat(8), w - 8] {
                    UIColor(hex: "#613A31").setFill()
                    UIBezierPath(ovalIn: CGRect(x: x, y: y + 4, width: 2, height: 2)).fill()
                }
            }
        }
        root.addChild(face)
        if ice {
            let cap = snowCap(size: CGSize(width: size.width, height: size.height * 0.25))
            cap.position.y = size.height * 0.43
            root.addChild(cap)
        }
        let label = GameSurface.label(theme.displayName, size: size.height * 0.29, color: UIColor(hex: ice ? "#D2F8FF" : "#FFF8E6"))
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = size.width * 0.82
        label.position.y = 0
        root.addChild(label)
        return root
    }
}
