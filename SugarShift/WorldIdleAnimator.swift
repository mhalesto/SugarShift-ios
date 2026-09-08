import SpriteKit

/// One short gesture on a sampled cell. There are no permanent per-tile actions.
enum WorldIdleAnimator {
    static func animate(special: Special, art: SKNode, at point: CGPoint, tile: CGFloat,
                        particles: WorldParticleFactory, parent: SKNode) {
        guard !SignatureMotion.isReduced, art.action(forKey: "materialIdle") == nil else { return }
        switch special {
        case .rocket:
            let exhaust = CGPoint(x: point.x, y: point.y - tile * 0.32)
            particles.spawn(.glow, at: exhaust, in: parent, color: UIColor(hex: "#FFD37B"),
                size: tile * 0.20, life: 0.48)?.alpha = 0.55
            particles.spawn(.ember, at: exhaust, in: parent, color: UIColor(hex: "#FFBD67"),
                size: 3, life: 0.42, velocity: CGVector(dx: 0, dy: -8))
        case .fish:
            let angle = art.zRotation
            art.run(.sequence([.rotate(toAngle: angle + 0.035, duration: 0.22),
                .rotate(toAngle: angle - 0.035, duration: 0.30),
                .rotate(toAngle: angle, duration: 0.22)]), withKey: "materialIdle")
            particles.spawn(.bubble, at: CGPoint(x: point.x + tile * 0.30, y: point.y),
                in: parent, color: UIColor(hex: "#D4F6FF"), size: 4, life: 0.70,
                velocity: CGVector(dx: 4, dy: 7))
        case .ufo:
            particles.spawn(.glow, at: CGPoint(x: point.x, y: point.y - tile * 0.25),
                in: parent, color: UIColor(hex: "#B0FFC9"), size: tile * 0.45, life: 0.75)?.alpha = 0.24
        case .colorBomb:
            for (index, color) in ["#FFABDD", "#B9F7EE"].enumerated() {
                let offset: CGFloat = index == 0 ? -1 : 1
                particles.spawn(.sparkle, at: CGPoint(x: point.x + offset * tile * 0.23,
                                                     y: point.y + tile * 0.24),
                    in: parent, color: UIColor(hex: color), size: 5, life: 0.75,
                    velocity: CGVector(dx: -offset * 3, dy: 3))
            }
        case .stripedRow, .stripedCol, .lineBlast, .wrapped, .bomb:
            glint(on: art, tile: tile, color: UIColor(hex: "#FFF5D8"), strength: 0.28)
        }
    }

    static func portal(at point: CGPoint, tile: CGFloat, particles: WorldParticleFactory, parent: SKNode) {
        guard !SignatureMotion.isReduced else { return }
        let path = UIBezierPath()
        for step in 0...24 {
            let t = CGFloat(step) / 24
            let radius = tile * (0.44 - t * 0.14)
            let angle = t * .pi * 1.7
            let position = CGPoint(x: point.x + cos(angle) * radius, y: point.y + sin(angle) * radius)
            if step == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        particles.spawn(.glow, at: point, in: parent, color: UIColor(hex: "#CBA7FF"),
            size: 6, life: 0.85, path: path.cgPath)?.alpha = 0.68
    }

    static func animate(profile: WorldAnimationProfile, art: SKNode, at point: CGPoint,
                        tile: CGFloat, particles: WorldParticleFactory, parent: SKNode) {
        guard !SignatureMotion.isReduced, art.action(forKey: "materialIdle") == nil else { return }
        let material = profile.material
        let x = art.xScale, y = art.yScale, angle = art.zRotation
        let tint = UIColor(hex: profile.secondary)
        func breathe(_ amount: CGFloat = 0.025) {
            art.run(.sequence([
                .group([.scaleX(to: x * (1 + amount), duration: 0.48),
                        .scaleY(to: y * (1 - amount * 0.45), duration: 0.48)]),
                .group([.scaleX(to: x, duration: 0.48), .scaleY(to: y, duration: 0.48)])]), withKey: "materialIdle")
        }
        func sway(_ amount: CGFloat = 0.035) {
            art.run(.sequence([.rotate(toAngle: angle + amount, duration: 0.32),
                .rotate(toAngle: angle - amount * 0.65, duration: 0.40),
                .rotate(toAngle: angle, duration: 0.28)]), withKey: "materialIdle")
        }
        func mote(_ kind: WorldParticleKind, offset: CGPoint = .zero,
                  velocity: CGVector = CGVector(dx: 2, dy: 6), side: CGFloat = 4) {
            particles.spawn(kind, at: CGPoint(x: point.x + offset.x, y: point.y + offset.y),
                in: parent, color: tint, size: side, life: 0.85, velocity: velocity)?.alpha = 0.60
        }
        switch material {
        case .firefly:
            breathe(0.012)
            particles.spawn(.glow, at: point, in: parent, color: tint,
                size: tile * 0.70, life: 0.85)?.alpha = 0.18
            for index in 0..<2 {
                let path = UIBezierPath()
                let sign: CGFloat = index == 0 ? -1 : 1
                path.move(to: CGPoint(x: point.x + sign * tile * 0.10, y: point.y))
                path.addCurve(to: CGPoint(x: point.x - sign * tile * 0.08, y: point.y + tile * 0.04),
                    controlPoint1: CGPoint(x: point.x, y: point.y + tile * 0.18),
                    controlPoint2: CGPoint(x: point.x - sign * tile * 0.14, y: point.y - tile * 0.08))
                particles.spawn(.firefly, at: point, in: parent, color: tint, size: tile * 0.075,
                    life: 0.85, index: index, path: path.cgPath)
            }
        case .ice, .crystal, .amber, .metal:
            glint(on: art, tile: tile, color: tint)
            mote(.sparkle, offset: CGPoint(x: tile * 0.21, y: tile * 0.18), side: 4)
        case .vine, .seaweed:
            sway(material == .seaweed ? 0.048 : 0.024)
            if material == .seaweed { mote(.bubble, offset: CGPoint(x: tile * 0.18, y: 0), side: 4) }
        case .flower:
            breathe(0.035)
            mote(.petal, offset: CGPoint(x: tile * 0.24, y: tile * 0.16),
                 velocity: CGVector(dx: 5, dy: 8), side: 4)
        case .honey, .jelly:
            breathe(0.025)
            glint(on: art, tile: tile, color: tint, strength: 0.30)
            mote(.bubble, offset: CGPoint(x: -tile * 0.12, y: -tile * 0.10),
                 velocity: CGVector(dx: 1, dy: 5), side: 3)
        case .donut:
            mote(.sparkle, offset: CGPoint(x: tile * 0.16, y: tile * 0.22), side: 5)
        case .lava:
            particles.spawn(.glow, at: point, in: parent, color: UIColor(hex: "#FF733A"),
                size: tile * 0.72, life: 0.85)?.alpha = 0.17
            mote(.ember, offset: CGPoint(x: tile * 0.12, y: tile * 0.20),
                 velocity: CGVector(dx: 3, dy: 11), side: 3)
        case .water:
            breathe(0.022)
            glint(on: art, tile: tile, color: tint, strength: 0.30)
            mote(.bubble, offset: CGPoint(x: -tile * 0.26, y: 0), side: 5)
        case .cloud, .cream:
            breathe(0.045)
        case .star, .rainbow:
            sway(0.035)
            glint(on: art, tile: tile, color: tint)
        case .sandstone, .pottery, .stone:
            mote(.sand, offset: CGPoint(x: tile * 0.24, y: -tile * 0.22),
                 velocity: CGVector(dx: 1, dy: -7), side: 3)
        case .scarab:
            sway(0.025)
            glint(on: art, tile: tile, color: tint)
        case .cosmic:
            sway(0.055)
            let path = UIBezierPath(ovalIn: CGRect(x: point.x - tile * 0.34, y: point.y - tile * 0.16,
                                                  width: tile * 0.68, height: tile * 0.32))
            particles.spawn(.star, at: point, in: parent, color: tint, size: 4, life: 0.90, path: path.cgPath)
        case .lantern:
            sway(0.035)
            particles.spawn(.glow, at: point, in: parent, color: UIColor(hex: "#FFD597"),
                size: tile * 0.68, life: 0.85)?.alpha = 0.16
        case .fruit, .wood, .chocolate: break
        }
    }

    static func glint(on art: SKNode, tile: CGFloat, color: UIColor, strength: CGFloat = 0.48) {
        guard art.childNode(withName: "materialGlint") == nil else { return }
        let crop = SKCropNode()
        crop.name = "materialGlint"
        crop.zPosition = 2
        let mask = SKShapeNode(rectOf: CGSize(width: tile * 0.68, height: tile * 0.66), cornerRadius: tile * 0.20)
        mask.fillColor = .white; mask.strokeColor = .clear
        crop.maskNode = mask
        let shine = SKSpriteNode(texture: WorldParticleFactory.texture(.glow))
        shine.size = CGSize(width: tile * 0.12, height: tile * 0.83)
        shine.color = color; shine.colorBlendFactor = 1; shine.blendMode = .add
        shine.zRotation = -0.42; shine.alpha = 0
        shine.position.x = -tile * 0.36
        crop.addChild(shine)
        art.addChild(crop)
        shine.run(.group([.moveTo(x: tile * 0.36, duration: 0.85),
            .sequence([.fadeAlpha(to: strength, duration: 0.25), .wait(forDuration: 0.25), .fadeOut(withDuration: 0.35)])]))
        SignatureMotion.remove(crop, after: 0.90)
    }
}
