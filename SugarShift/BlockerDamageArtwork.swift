import SpriteKit

/// Persistent damage detail is a cached transparent texture, not another emitter
/// or action on every cell. It reflects the blocker's remaining mechanical layers.
enum BlockerDamageArtwork {
    private static var textures: [String: SKTexture] = [:]

    static func apply(to container: SKNode, blocker: Blocker, size: CGFloat,
                      theme: WorldThemeDefinition?) {
        guard let art = container.childNode(withName: "blockerArt"),
              blocker.type != .solidX else { return }
        let worldID = theme?.id ?? "candy"
        let asset = theme?.blockerAsset(blocker) ?? BoardRenderer.blockerAsset(blocker)
        let material = WorldAnimationProfile.material(worldID: worldID, asset: asset, blocker: blocker.type)
        let severity = max(0, 3 - min(3, blocker.hits))
        guard severity > 0 else { return }
        if [.honey, .jelly].contains(material) {
            art.alpha *= severity == 2 ? 0.78 : 0.90
        }
        let supported: [AnimationMaterial] = [.ice, .crystal, .amber, .lava, .stone, .sandstone,
            .pottery, .wood, .chocolate, .vine, .seaweed, .metal, .honey, .jelly]
        guard supported.contains(material) else { return }
        let key = "\(material.rawValue):\(severity)"
        let texture: SKTexture
        if let cached = textures[key] { texture = cached }
        else {
            texture = makeTexture(material: material, severity: severity)
            textures[key] = texture
        }
        let overlay = SKSpriteNode(texture: texture)
        overlay.name = "blockerDamageDetail"
        overlay.size = CGSize(width: size * 0.83, height: size * 0.83)
        overlay.zPosition = 1
        overlay.alpha = Persistence.highContrast ? 0.90 : 0.62
        art.addChild(overlay)
    }

    private static func makeTexture(material: AnimationMaterial, severity: Int) -> SKTexture {
        let side: CGFloat = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let profile = WorldAnimationProfile.profile(for: material)
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let color = UIColor(hex: profile.secondary)
            if [.honey, .jelly].contains(material) {
                color.withAlphaComponent(0.85).setStroke()
                for index in 0..<severity + 1 {
                    let line = UIBezierPath()
                    let y = 27 + CGFloat(index) * 17
                    line.move(to: CGPoint(x: 12, y: y))
                    line.addCurve(to: CGPoint(x: 85, y: y - 3),
                        controlPoint1: CGPoint(x: 34, y: y + 18), controlPoint2: CGPoint(x: 68, y: y - 15))
                    line.lineWidth = 1.7; line.stroke()
                }
                return
            }
            if [.vine, .seaweed, .wood].contains(material) {
                color.setStroke()
                for index in 0..<severity + 1 {
                    let strand = UIBezierPath()
                    let y = CGFloat(25 + index * 24)
                    strand.move(to: CGPoint(x: 12, y: y))
                    strand.addQuadCurve(to: CGPoint(x: 42, y: y - 4), controlPoint: CGPoint(x: 29, y: y + 9))
                    strand.move(to: CGPoint(x: 56, y: y + 5))
                    strand.addQuadCurve(to: CGPoint(x: 86, y: y), controlPoint: CGPoint(x: 72, y: y - 10))
                    strand.lineWidth = 2; strand.lineCapStyle = .round; strand.stroke()
                }
                return
            }
            let crack = UIBezierPath()
            for index in 0..<severity + 1 {
                let angle = CGFloat(index) * 2.12 + 0.25
                let center = CGPoint(x: 48, y: 45)
                crack.move(to: center)
                crack.addLine(to: CGPoint(x: center.x + cos(angle) * 15, y: center.y + sin(angle) * 15))
                crack.addLine(to: CGPoint(x: center.x + cos(angle + 0.18) * 27, y: center.y + sin(angle + 0.18) * 27))
                crack.addLine(to: CGPoint(x: center.x + cos(angle) * 43, y: center.y + sin(angle) * 43))
                if severity > 1 {
                    crack.move(to: CGPoint(x: center.x + cos(angle) * 15, y: center.y + sin(angle) * 15))
                    crack.addLine(to: CGPoint(x: center.x + cos(angle - 0.55) * 30, y: center.y + sin(angle - 0.55) * 30))
                }
            }
            UIColor(hex: material == .lava ? "#ED3E0C" : "#233852").withAlphaComponent(0.7).setStroke()
            crack.lineWidth = material == .lava ? 5 : 3.5
            crack.lineCapStyle = .round; crack.stroke()
            color.setStroke(); crack.lineWidth = material == .lava ? 2.8 : 1.4; crack.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}
