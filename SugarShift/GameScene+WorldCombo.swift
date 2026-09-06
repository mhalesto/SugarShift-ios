import SpriteKit

extension ClearPresentationPlan {
    var worldComboCue: WorldComboCue {
        switch kind {
        case .playerSmash(.mega): return .megaSmash
        case .combo(.colorColor), .combo(.colorWrapped), .combo(.colorBomb),
             .combo(.wrappedWrapped), .combo(.bombWrapped), .combo(.bombBomb):
            return .powerfulPair
        default: return .ordinary
        }
    }
}

extension GameScene {
    func worldComboSequence(for plan: ClearPresentationPlan?, affectedCount: Int) -> WorldComboSequence? {
        guard let plan, let style = worldTheme.comboStyle else { return nil }
        return WorldComboPolicy.sequence(cue: plan.worldComboCue, style: style,
            affectedCount: affectedCount,
            reduceMotion: Persistence.reduceMotion || UIAccessibility.isReduceMotionEnabled)
    }

    /// Only consumes the engine's resolved footprint. Heroes never clear extra
    /// cells, select targets or change scoring. All actions live under one
    /// removable root, including delayed sound/haptics, so level changes cancel it.
    func playWorldCombo(_ sequence: WorldComboSequence, plan: ClearPresentationPlan,
                        affected: Set<Pos>) {
        guard let style = worldTheme.comboStyle else { return }
        worldNode.childNode(withName: "worldComboPresentation")?.removeFromParent()
        let root = SKNode()
        root.name = "worldComboPresentation"
        root.zPosition = 790
        worldNode.addChild(root)
        let frame = gameplayLayout.board.insetBy(dx: -6, dy: -6)
        let crop = SKCropNode()
        let mask = SKShapeNode(rect: frame, cornerRadius: 16)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        root.addChild(crop)
        let tint = worldTheme.glowColor
        let origin = point(forRow: plan.origin.r, col: plan.origin.c)
        let sorted = affected.sorted { $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r }

        gamePhase = .worldCombo
        Audio.shared.duckMusic(for: sequence.finishesAt)
        Effects.prepareHaptics()

        // Accessibility: retain a single soft impact indication, no travel,
        // debris, rapidly repeating flashes or screen displacement.
        if sequence.particleCount == 0 {
            let halo = SKShapeNode(circleOfRadius: tileSize * 0.7)
            halo.position = origin
            halo.strokeColor = tint.withAlphaComponent(0.65)
            halo.lineWidth = 3
            halo.fillColor = .clear
            crop.addChild(halo)
            halo.run(.fadeOut(withDuration: sequence.finishesAt))
            Effects.haptic(.heavy, intensity: 0.75)
            root.run(.sequence([.wait(forDuration: sequence.finishesAt), .removeFromParent()]))
            return
        }

        let heroSize = CGSize(width: tileSize * (style == .eruption ? 2.25 : 3.7),
                              height: tileSize * 2.5)
        let hero = GameArt.sprite(worldTheme.comboHeroAsset ?? "", fitting: heroSize)
        hero.zPosition = 4
        hero.position = CGPoint(x: min(frame.maxX - hero.size.width / 2, max(frame.minX + hero.size.width / 2, origin.x)),
                                y: min(frame.maxY - hero.size.height / 2, max(frame.minY + hero.size.height / 2, origin.y)))
        crop.addChild(hero)
        let impactPoint = hero.position
        if style == .eruption {
            hero.setScale(0.60)
            hero.run(.sequence([
                .scale(to: 1.07, duration: sequence.impactAt),
                .group([.scale(to: 1.30, duration: 0.16), .fadeOut(withDuration: 0.16)])
            ]))
            // Branches follow real affected cells; deterministic geometry makes
            // the fracture readable without consuming the gameplay RNG.
            for (index, target) in sorted.prefix(sequence.linkCount).enumerated() {
                let end = point(forRow: target.r, col: target.c)
                let path = CGMutablePath()
                path.move(to: impactPoint)
                path.addLine(to: CGPoint(x: impactPoint.x * 0.58 + end.x * 0.42 + CGFloat(index % 3 - 1) * 8,
                                         y: impactPoint.y * 0.58 + end.y * 0.42 - CGFloat(index % 2) * 7))
                path.addLine(to: end)
                let crack = SKShapeNode(path: path)
                crack.strokeColor = tint
                crack.lineWidth = 2
                crack.glowWidth = 3
                crack.alpha = 0
                crop.addChild(crack)
                crack.run(.sequence([.fadeAlpha(to: 0.85, duration: sequence.impactAt),
                    .fadeOut(withDuration: 0.20)]))
            }
            Effects.haptic(.rigid, intensity: 0.38)
            Audio.shared.play(.crate, pan: soundPan(at: origin))
        } else {
            let path = CGMutablePath()
            let start = CGPoint(x: impactPoint.x - tileSize * 1.5, y: impactPoint.y - tileSize * 0.55)
            hero.position = start
            path.move(to: start)
            path.addQuadCurve(to: impactPoint,
                control: CGPoint(x: impactPoint.x - tileSize * 0.6, y: impactPoint.y + tileSize * 1.6))
            hero.run(.sequence([.follow(path, asOffset: false, orientToPath: false, duration: sequence.impactAt),
                .group([.moveBy(x: tileSize * 0.6, y: -tileSize * 0.6, duration: 0.20),
                        .fadeOut(withDuration: 0.20)])]))
            Audio.shared.play(.fish, pan: soundPan(at: origin))
        }

        root.run(.sequence([.wait(forDuration: sequence.impactAt), .run { [weak self, weak crop] in
            guard let self, let crop else { return }
            Effects.haptic(.heavy, intensity: style == .eruption ? 1 : 0.85)
            Effects.shake(self.worldNode, intensity: CGFloat(sequence.shakeStrength), duration: 0.24)
            Audio.shared.play(style == .eruption ? .bomb : .wrapped, pan: self.soundPan(at: impactPoint))
            let wave = SKShapeNode(circleOfRadius: self.tileSize * 0.30)
            wave.position = impactPoint
            wave.fillColor = .clear
            wave.strokeColor = tint.withAlphaComponent(0.85)
            wave.lineWidth = style == .eruption ? 6 : 10
            wave.glowWidth = 3
            crop.addChild(wave)
            wave.run(.group([.scale(to: 8, duration: 0.32), .fadeOut(withDuration: 0.32)]))
            let particles = WorldEffectTextures.burst(style: style, tint: tint, count: sequence.particleCount)
            particles.position = impactPoint
            crop.addChild(particles)
            for (index, target) in sorted.prefix(sequence.linkCount).enumerated() {
                let end = self.point(forRow: target.r, col: target.c)
                let link = Effects.makeEnergySweep(from: impactPoint, to: end,
                    tint: tint, width: style == .eruption ? 7 : 5, delay: Double(index) * 0.008)
                crop.addChild(link)
            }
        }]))
        root.run(.sequence([.wait(forDuration: sequence.finishesAt), .removeFromParent()]))
    }
}

/// Small cached, genuinely transparent textures. Particle budgets are fixed;
/// there is no per-frame texture rendering or unbounded emitter lifetime.
enum WorldEffectTextures {
    private static var textures: [String: SKTexture] = [:]
    static func texture(bubble: Bool) -> SKTexture {
        let key = bubble ? "bubble" : "ember"
        if let texture = textures[key] { return texture }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24), format: format).image { _ in
            if bubble {
                UIColor.white.withAlphaComponent(0.7).setStroke()
                let ring = UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 18, height: 18))
                ring.lineWidth = 1.8
                ring.stroke()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 6, y: 6, width: 5, height: 3)).fill()
            } else {
                UIColor.white.setFill()
                let shard = UIBezierPath()
                shard.move(to: CGPoint(x: 12, y: 2))
                shard.addLine(to: CGPoint(x: 19, y: 13))
                shard.addLine(to: CGPoint(x: 8, y: 22))
                shard.addLine(to: CGPoint(x: 4, y: 10))
                shard.close()
                shard.fill()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    static func burst(style: WorldComboStyle, tint: UIColor, count: Int) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture(bubble: style == .whaleWave)
        emitter.particleBirthRate = 500
        emitter.numParticlesToEmit = min(48, max(0, count))
        emitter.particleLifetime = 0.25
        emitter.particleLifetimeRange = 0.08
        emitter.particleSpeed = 240
        emitter.particleSpeedRange = 110
        emitter.emissionAngleRange = .pi * 2
        emitter.yAcceleration = style == .eruption ? -380 : -140
        emitter.particleScale = style == .eruption ? 0.18 : 0.32
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.3
        emitter.particleAlphaSpeed = -2.0
        emitter.particleColor = tint
        emitter.particleColorBlendFactor = 1
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = style == .eruption ? 4 : 0
        return emitter
    }
}
