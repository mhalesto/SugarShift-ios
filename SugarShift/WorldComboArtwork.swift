import SpriteKit

enum WorldComboArtwork {
    private static var textures: [String: SKTexture] = [:]

    static func title(_ text: String, width: CGFloat, size: CGFloat, color: UIColor) -> SKNode {
        let root = SKNode()
        // Live attributed text gives the reference's heavy outlined lettering
        // while still supporting localization and actual runtime combo names.
        func label(stroke: UIColor, fill: UIColor, strokeWidth: Double) -> SKLabelNode {
            let label = SKLabelNode()
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont(name: "AvenirNext-HeavyItalic", size: size) ?? UIFont.boldSystemFont(ofSize: size),
                .foregroundColor: fill, .strokeColor: stroke, .strokeWidth: strokeWidth
            ])
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = width
            label.verticalAlignmentMode = .center
            return label
        }
        let shadow = label(stroke: color.darker(by: 0.62), fill: color.darker(by: 0.62), strokeWidth: -14)
        shadow.position = CGPoint(x: 0, y: -3)
        root.addChild(shadow)
        let rim = label(stroke: color.darker(by: 0.45), fill: .white, strokeWidth: -9)
        root.addChild(rim)
        let face = label(stroke: color, fill: UIColor(hex: "#FFFBDB"), strokeWidth: -3)
        root.addChild(face)
        return root
    }

    static func material(_ key: String) -> SKTexture {
        if let texture = textures[key] { return texture }
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).image { context in
            let cg = context.cgContext
            let path = UIBezierPath()
            switch key {
            case "bubble":
                UIColor(hex: "#9AECFF").withAlphaComponent(0.30).setFill()
                let bubble = UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 26, height: 26))
                bubble.fill()
                UIColor.white.withAlphaComponent(0.9).setStroke(); bubble.lineWidth = 1.5; bubble.stroke()
                UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: 8, y: 6, width: 8, height: 4)).fill()
                return
            case "firefly":
                let colors = [UIColor.white.cgColor, UIColor(hex: "#FFF78F").cgColor, UIColor(hex: "#FFD43C").withAlphaComponent(0).cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.2, 1])!
                cg.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                    endCenter: CGPoint(x: 16, y: 16), endRadius: 15, options: [])
                return
            case "cloud":
                UIColor.white.withAlphaComponent(0.55).setFill()
                for rect in [CGRect(x: 1, y: 13, width: 18, height: 13), CGRect(x: 9, y: 7, width: 18, height: 20), CGRect(x: 19, y: 14, width: 12, height: 12)] {
                    UIBezierPath(ovalIn: rect).fill()
                }
                return
            case "snow":
                UIColor.white.setStroke()
                for i in 0..<6 {
                    let angle = CGFloat(i) * .pi / 3
                    let a = CGPoint(x: 16 + cos(angle) * 12, y: 16 + sin(angle) * 12)
                    path.move(to: CGPoint(x: 16, y: 16)); path.addLine(to: a)
                    let joint = CGPoint(x: 16 + cos(angle) * 7, y: 16 + sin(angle) * 7)
                    for side in [CGFloat(-1), CGFloat(1)] {
                        path.move(to: joint)
                        path.addLine(to: CGPoint(x: joint.x + cos(angle + side * .pi / 3) * 5,
                                                y: joint.y + sin(angle + side * .pi / 3) * 5))
                    }
                }
                path.lineWidth = 1.5; path.lineCapStyle = .round; path.stroke()
                return
            case "petal":
                path.move(to: CGPoint(x: 8, y: 27))
                path.addCurve(to: CGPoint(x: 26, y: 4), controlPoint1: CGPoint(x: 0, y: 8), controlPoint2: CGPoint(x: 20, y: 0))
                path.addCurve(to: CGPoint(x: 8, y: 27), controlPoint1: CGPoint(x: 31, y: 19), controlPoint2: CGPoint(x: 16, y: 28))
                path.close()
            case "cosmic", "sparkle":
                path.move(to: CGPoint(x: 16, y: 2)); path.addLine(to: CGPoint(x: 19, y: 12))
                path.addLine(to: CGPoint(x: 30, y: 16)); path.addLine(to: CGPoint(x: 19, y: 20))
                path.addLine(to: CGPoint(x: 16, y: 30)); path.addLine(to: CGPoint(x: 13, y: 20))
                path.addLine(to: CGPoint(x: 2, y: 16)); path.addLine(to: CGPoint(x: 13, y: 12)); path.close()
            case "honey":
                path.move(to: CGPoint(x: 16, y: 2))
                path.addCurve(to: CGPoint(x: 16, y: 29), controlPoint1: CGPoint(x: 33, y: 18), controlPoint2: CGPoint(x: 30, y: 29))
                path.addCurve(to: CGPoint(x: 16, y: 2), controlPoint1: CGPoint(x: 2, y: 29), controlPoint2: CGPoint(x: 2, y: 18)); path.close()
            default:
                path.move(to: CGPoint(x: 13, y: 2)); path.addLine(to: CGPoint(x: 27, y: 11))
                path.addLine(to: CGPoint(x: 22, y: 27)); path.addLine(to: CGPoint(x: 6, y: 30))
                path.addLine(to: CGPoint(x: 3, y: 13)); path.close()
            }
            let palette = key == "iceShard" ? ["#F6FEFF", "#80DBFF", "#C5F2FF"]
                : key == "petal" ? ["#FFF6FC", "#FF97D7", "#F45EBA"]
                : key == "honey" || key == "sand" ? ["#FFF6AD", "#FFD14E", "#CE841F"] : ["#FFFFFF", "#E4EDFF", "#B1C3EE"]
            cg.saveGState(); path.addClip()
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: palette.map { UIColor(hex: $0).cgColor } as CFArray, locations: [0, 0.45, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 32, y: 32), options: [])
            cg.restoreGState()
            UIColor.white.withAlphaComponent(0.85).setStroke(); path.lineWidth = 1.2; path.stroke()
            if key == "iceShard" {
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.65).cgColor)
                cg.move(to: CGPoint(x: 13, y: 2)); cg.addLine(to: CGPoint(x: 15, y: 18))
                cg.addLine(to: CGPoint(x: 6, y: 30)); cg.strokePath()
            }
        }
        let texture = SKTexture(image: image); texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }
}

extension WorldEffectTextures {
    static func ambientTexture(_ style: WorldThemeDefinition.AmbientStyle) -> SKTexture {
        WorldComboArtwork.material(String(describing: style))
    }
}
