import SpriteKit

/// Small articulated releases assembled from the existing item artwork.
enum WorldObjectReleaseAnimator {
    static func openShell(from source: SKNode?, at point: CGPoint, tile: CGFloat, in parent: SKNode) {
        guard !SignatureMotion.isReduced, let art = source as? SKSpriteNode,
              let texture = art.texture, parent.children.count < 210 else { return }
        art.alpha = 0
        let root = SKNode(); root.position = point; root.zPosition = 3
        parent.addChild(root)
        let bottom = SKSpriteNode(texture: SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: 0.50), in: texture))
        bottom.size = CGSize(width: art.size.width, height: art.size.height * 0.50)
        bottom.position.y = -art.size.height * 0.25
        root.addChild(bottom)
        let lid = SKSpriteNode(texture: SKTexture(rect: CGRect(x: 0, y: 0.50, width: 1, height: 0.50), in: texture))
        lid.size = bottom.size; lid.anchorPoint = CGPoint(x: 0.50, y: 0)
        lid.zPosition = 2; root.addChild(lid)
        lid.run(.sequence([
            .group([.scaleY(to: 0.85, duration: 0.035), .rotate(toAngle: -0.04, duration: 0.035)]),
            .group([.scaleY(to: 0.42, duration: 0.13), .rotate(toAngle: 0.20, duration: 0.13),
                    .moveBy(x: 0, y: tile * 0.20, duration: 0.13)]),
            .wait(forDuration: 0.10), .fadeOut(withDuration: 0.19)]))
        bottom.run(.sequence([.wait(forDuration: 0.16),
            .group([.moveBy(x: 0, y: -tile * 0.10, duration: 0.27), .fadeOut(withDuration: 0.27)])]))
        let pearl = GameArt.boardSprite("objective_pearl", fitting: CGSize(width: tile * 0.36, height: tile * 0.36))
        pearl.alpha = 0; pearl.zPosition = 4; pearl.setScale(0.55); root.addChild(pearl)
        pearl.run(.sequence([.wait(forDuration: 0.07), .fadeIn(withDuration: 0.035),
            .group([.moveBy(x: tile * 0.12, y: tile * 0.65, duration: 0.28),
                    .scale(to: 1, duration: 0.11),
                    .sequence([.wait(forDuration: 0.13), .fadeOut(withDuration: 0.15)])])]))
        SignatureMotion.remove(root, after: 0.52)
    }

    static func honeySpiral(at point: CGPoint, tile: CGFloat, color: UIColor, in parent: SKNode) {
        guard !SignatureMotion.isReduced, parent.children.count < 210 else { return }
        let path = CGMutablePath()
        for step in 0...36 {
            let t = CGFloat(step) / 36
            let angle = t * .pi * 4
            let radius = tile * 0.24 * (1 - t * 0.70)
            let p = CGPoint(x: cos(angle) * radius, y: t * tile * 0.95)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        let strand = SKShapeNode(path: path)
        strand.position = point; strand.strokeColor = color; strand.lineWidth = tile * 0.06
        strand.lineCap = .round; strand.glowWidth = 1.5; strand.yScale = 0.10
        parent.addChild(strand)
        strand.run(.sequence([.scaleY(to: 1, duration: 0.22),
            .group([.scaleX(to: 0.10, duration: 0.19), .moveBy(x: 0, y: tile * 0.2, duration: 0.19),
                    .fadeOut(withDuration: 0.19)]), .removeFromParent()]))
    }

    static func flyingScarab(from start: CGPoint, to end: CGPoint, size: CGFloat, in parent: SKNode) {
        guard !SignatureMotion.isReduced, parent.children.count < 210 else { return }
        let root = SKNode(); root.position = start; root.zPosition = 4
        parent.addChild(root)
        for sign: CGFloat in [-1, 1] {
            let wing = SKSpriteNode(texture: WorldParticleFactory.texture(.petal))
            wing.size = CGSize(width: size * 0.60, height: size * 0.85)
            wing.position.x = sign * size * 0.18; wing.zRotation = sign * 0.20
            wing.color = UIColor(hex: "#A0EEFF"); wing.colorBlendFactor = 1; wing.alpha = 0.75
            wing.xScale = 0.10; root.addChild(wing)
            wing.run(.sequence([.group([.scaleX(to: 1, duration: 0.10), .rotate(toAngle: sign * 0.72, duration: 0.10)]),
                .repeat(.sequence([.scaleX(to: 0.45, duration: 0.045), .scaleX(to: 1, duration: 0.045)]), count: 4)]))
        }
        root.addChild(GameArt.boardSprite("objective_scarab", fitting: CGSize(width: size, height: size)))
        let path = UIBezierPath(); path.move(to: start)
        path.addCurve(to: end,
            controlPoint1: CGPoint(x: start.x - size, y: start.y + size * 1.5),
            controlPoint2: CGPoint(x: end.x + size * 0.7, y: end.y - size))
        root.run(.sequence([.wait(forDuration: 0.07),
            .group([.follow(path.cgPath, asOffset: false, orientToPath: false, duration: 0.43),
                    .scale(to: 0.40, duration: 0.43),
                    .sequence([.wait(forDuration: 0.28), .fadeOut(withDuration: 0.15)])]), .removeFromParent()]))
    }
}
