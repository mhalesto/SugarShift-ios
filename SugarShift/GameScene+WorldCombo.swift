import SpriteKit

extension ClearPresentationPlan {
    var worldComboCue: WorldComboCue {
        switch kind {
        case .playerSmash(.mega): return .megaSmash
        case .colorBomb: return .worldSpecial
        case .combo(.colorColor), .combo(.colorWrapped), .combo(.colorBomb),
             .combo(.wrappedWrapped), .combo(.bombWrapped), .combo(.bombBomb),
             .combo(.stripeStripe), .combo(.wrappedStripe), .combo(.colorStripe),
             .combo(.colorFish), .combo(.fishFish), .combo(.advanced):
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
        let mask = SKShapeNode(path: boardContourPath)
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

        // Hero has its own broad clip so its silhouette can cross a board hole,
        // while material beams and particles respect the active-cell contour.
        let heroLayer = SKCropNode()
        let heroMask = SKShapeNode(rect: frame.insetBy(dx: -3, dy: -3), cornerRadius: 12)
        heroMask.fillColor = .white
        heroMask.strokeColor = .clear
        heroLayer.maskNode = heroMask
        root.addChild(heroLayer)
        let heroSize = CGSize(width: tileSize * (style == .whaleWave ? 4.4 : style == .frost ? 1.6 : 3.2),
                              height: tileSize * (style == .rainbow ? 3.6 : 3.0))
        let hero = GameArt.boardSprite(worldTheme.comboHeroAsset ?? "", fitting: heroSize)
        hero.zPosition = 4
        hero.position = CGPoint(x: min(frame.maxX - hero.size.width / 2, max(frame.minX + hero.size.width / 2, origin.x)),
                                y: min(frame.maxY - hero.size.height / 2, max(frame.minY + hero.size.height / 2, origin.y)))
        heroLayer.addChild(hero)
        let impactPoint = hero.position
        let title = WorldComboArtwork.title(worldTheme.comboTitle, width: frame.width * 0.70,
                                           size: min(32, tileSize * 0.75), color: tint)
        title.position = CGPoint(x: min(frame.maxX - frame.width * 0.36, max(frame.minX + frame.width * 0.36, impactPoint.x)),
                                 y: min(frame.maxY - tileSize, max(frame.minY + tileSize, impactPoint.y + (style == .whaleWave ? 1.55 : -1.45) * tileSize)))
        title.zPosition = 8
        title.zRotation = 0.10
        title.alpha = 0
        title.setScale(0.65)
        heroLayer.addChild(title)
        title.run(.sequence([.wait(forDuration: sequence.impactAt * 0.65),
            .group([.fadeIn(withDuration: 0.10), .scale(to: 1.06, duration: 0.16)]),
            .scale(to: 1, duration: 0.10), .wait(forDuration: 0.28), .fadeOut(withDuration: 0.24)]))
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
        } else if style == .whaleWave {
            let path = CGMutablePath()
            let start = CGPoint(x: impactPoint.x - tileSize * 1.5, y: impactPoint.y - tileSize * 0.55)
            hero.position = start
            path.move(to: start)
            path.addQuadCurve(to: impactPoint,
                control: CGPoint(x: impactPoint.x - tileSize * 0.6, y: impactPoint.y + tileSize * 1.6))
            hero.run(.sequence([.follow(path, asOffset: false, orientToPath: false, duration: sequence.impactAt),
                .wait(forDuration: 0.16),
                .group([.moveBy(x: tileSize * 1.25, y: -tileSize * 0.7, duration: 0.40),
                        .fadeOut(withDuration: 0.40)])]))
            Audio.shared.play(.fish, pan: soundPan(at: origin))
        } else {
            hero.setScale(0.45)
            let grow = SKAction.scale(to: 1.04, duration: sequence.impactAt)
            grow.timingMode = .easeOut
            let hold = SKAction.group([.scale(to: style == .rainbow ? 1.10 : 1.18, duration: 0.30),
                                      .rotate(byAngle: style == .sandstorm || style == .cosmic ? 0.6 : 0.06, duration: 0.30)])
            hero.run(.sequence([grow, hold, .group([.fadeOut(withDuration: 0.30),
                .moveBy(x: 0, y: style == .rainbow ? tileSize : 0, duration: 0.30)])]))
            Audio.shared.play(.colorCharge, pan: soundPan(at: origin))
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
            wave.lineWidth = style == .eruption ? 6 : style == .frost ? 3 : 10
            wave.glowWidth = 3
            crop.addChild(wave)
            wave.run(.group([.scale(to: 8, duration: 0.32), .fadeOut(withDuration: 0.32)]))
            let particles = WorldEffectTextures.burst(style: style, tint: tint, count: sequence.particleCount)
            particles.position = impactPoint
            crop.addChild(particles)
            for (index, target) in sorted.prefix(sequence.linkCount).enumerated() {
                let end = self.point(forRow: target.r, col: target.c)
                let link = Effects.makeEnergySweep(from: impactPoint, to: end,
                    tint: tint, width: style == .eruption || style == .frost ? 10 : 5, delay: Double(index) * 0.015)
                crop.addChild(link)
                if style == .rainbow {
                    for (lane, hex) in ["#FF56B9", "#FFE64E", "#68FF74", "#68CFFF"].enumerated() {
                        let rainbow = Effects.makeEnergySweep(from: CGPoint(x: impactPoint.x + CGFloat(lane - 2) * 3, y: impactPoint.y),
                            to: CGPoint(x: end.x + CGFloat(lane - 2) * 3, y: end.y), tint: UIColor(hex: hex), width: 3, delay: Double(index) * 0.015)
                        crop.addChild(rainbow)
                    }
                }
                if style == .firefly {
                    let spark = SKSpriteNode(texture: WorldEffectTextures.ambientTexture(.firefly))
                    spark.size = CGSize(width: 15, height: 15)
                    spark.position = impactPoint
                    crop.addChild(spark)
                    let flight = CGMutablePath()
                    flight.move(to: impactPoint)
                    flight.addQuadCurve(to: end, control: CGPoint(x: (end.x + impactPoint.x) / 2 + CGFloat(index % 3 - 1) * 30,
                        y: (end.y + impactPoint.y) / 2 + 24))
                    spark.run(.sequence([.follow(flight, asOffset: false, orientToPath: false, duration: 0.28), .fadeOut(withDuration: 0.16)]))
                }
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
        emitter.particleTexture = style == .frost ? WorldComboArtwork.material("iceShard") : ambientTexture(style == .whaleWave ? .bubble : style == .petal ? .petal : style == .firefly ? .firefly : style == .rainbow || style == .cosmic ? .cosmic : style == .sandstorm ? .sand : .ember)
        emitter.particleBirthRate = 500
        emitter.numParticlesToEmit = min(48, max(0, count))
        emitter.particleLifetime = 0.40
        emitter.particleLifetimeRange = 0.08
        emitter.particleSpeed = 240
        emitter.particleSpeedRange = 110
        emitter.emissionAngleRange = .pi * 2
        emitter.yAcceleration = style == .eruption ? -380 : -140
        emitter.particleScale = style == .eruption ? 0.22 : style == .frost ? 0.52 : 0.35
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.3
        emitter.particleAlphaSpeed = -2.0
        emitter.particleColor = tint
        emitter.particleColorBlendFactor = 0.25
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = style == .eruption ? 4 : 0
        return emitter
    }
}
