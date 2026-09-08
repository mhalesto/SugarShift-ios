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
            affectedCount: affectedCount, reduceMotion: SignatureMotion.isReduced)
    }

    /// Consumes only the resolved footprint. One removable root owns the hero,
    /// target travel, particles and delayed sound/haptics. No HUD node is moved.
    func playWorldCombo(_ sequence: WorldComboSequence, plan: ClearPresentationPlan,
                        affected: Set<Pos>) {
        guard let style = worldTheme.comboStyle, !affected.isEmpty else { return }
        worldNode.childNode(withName: "worldComboPresentation")?.removeFromParent()
        let root = SKNode()
        root.name = "worldComboPresentation"
        root.zPosition = 790
        worldNode.addChild(root)
        let frame = gameplayLayout.board
        let points = Dictionary(uniqueKeysWithValues: affected.union([plan.origin]).map {
            ($0, point(forRow: $0.r, col: $0.c))
        })
        root.addChild(BoardSpecialAnimator.make(plan: plan, sequence: sequence, affected: affected,
            points: points, tileSize: tileSize, tint: worldTheme.glowColor))
        if case .combo(let kind) = plan.kind {
            worldEffects.present([.comboTriggered(kind: kind, positions: [plan.origin] + [plan.secondary].compactMap { $0 })])
        }
        worldEffects.present([.worldComboTriggered(positions: Array(affected))], delay: { _ in sequence.impactAt })
        let crop = SKCropNode()
        let mask = SKShapeNode(path: boardContourPath)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        root.addChild(crop)
        let tint = worldTheme.glowColor
        let origin = point(forRow: plan.origin.r, col: plan.origin.c)
        let ordered = affected.sorted {
            let lhs = plan.delay(for: $0), rhs = plan.delay(for: $1)
            if lhs != rhs { return lhs < rhs }
            return $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r
        }
        gamePhase = .worldCombo
        Audio.shared.duckMusic(for: sequence.finishesAt)
        Effects.prepareHaptics()

        // Keep the real footprint visible. Accessibility uses a stationary
        // outline, a brief title and one impact; no hero travel or particles.
        if SignatureMotion.isReduced || sequence.particleCount == 0 {
            crop.addChild(SignatureMotion.quietMark(at: origin, tint: tint, radius: tileSize * 0.6))
            let title = SignatureMotion.lettering(worldTheme.comboTitle, width: frame.width * 0.80,
                fontSize: min(25, tileSize * 0.56), tint: tint)
            title.position = CGPoint(x: frame.midX, y: frame.midY)
            crop.addChild(title)
            title.run(.fadeOut(withDuration: 0.22))
            Effects.haptic(.heavy, intensity: 0.65)
            Audio.shared.play(.wrapped, pan: soundPan(at: origin))
            SignatureMotion.remove(root, after: 0.26)
            return
        }

        // The hero can cross inactive holes, but the broader board rectangle
        // still clips it before it reaches the header or protected footer.
        let heroLayer = SKCropNode()
        let heroMask = SKShapeNode(rect: frame.insetBy(dx: 2, dy: 2), cornerRadius: 12)
        heroMask.fillColor = .white
        heroMask.strokeColor = .clear
        heroLayer.maskNode = heroMask
        root.addChild(heroLayer)
        let heroWidth = min(frame.width * 0.70, tileSize * (style == .whaleWave ? 3.6 : 2.7))
        let heroHeight = min(frame.height * 0.50, tileSize * 2.6)
        let hero = GameArt.boardSprite(worldTheme.comboHeroAsset ?? "",
            fitting: CGSize(width: heroWidth, height: heroHeight))
        hero.position = origin
        hero.zPosition = 4
        heroLayer.addChild(hero)
        WorldComboMotion.animateHero(hero, style: style, origin: origin,
            tileSize: tileSize, impactAt: sequence.impactAt)
        crop.addChild(WorldComboMotion.charge(style: style, at: origin, tint: tint,
            tileSize: tileSize, duration: sequence.impactAt))

        // Lettering has its own stable lane and never inherits hero rotation.
        let title = SignatureMotion.lettering(worldTheme.comboTitle, width: frame.width * 0.78,
            fontSize: min(30, tileSize * 0.66), tint: tint)
        let titleHeight = title.calculateAccumulatedFrame().height
        if titleHeight > tileSize * 1.15 { title.setScale(tileSize * 1.15 / titleHeight) }
        title.position = CGPoint(x: frame.midX,
            y: min(frame.maxY - tileSize * 0.75, max(frame.minY + tileSize * 0.75,
                origin.y > frame.midY ? origin.y - tileSize * 1.50 : origin.y + tileSize * 1.50)))
        title.zPosition = 8
        title.alpha = 0
        heroLayer.addChild(title)
        title.run(.sequence([.wait(forDuration: sequence.impactAt * 0.72),
            .fadeIn(withDuration: 0.10), .wait(forDuration: 0.35), .fadeOut(withDuration: 0.20)]))

        // Evenly sample the already ordered footprint, including its final cell.
        // This spreads a fixed link budget over the board rather than decorating
        // only the first rows. Arrival time is exactly the tile impact delay.
        let count = min(sequence.linkCount, ordered.count)
        if count > 0 {
            for index in 0..<count {
                let targetIndex = count == 1 ? 0 : index * (ordered.count - 1) / (count - 1)
                let target = ordered[targetIndex]
                let end = point(forRow: target.r, col: target.c)
                let arrival = sequence.tileImpactDelay(normalDelay: plan.delay(for: target))
                let travel = min(arrival, style == .firefly || style == .petal ? 0.24 : 0.17)
                let link = WorldComboMotion.targetTrail(style: style, from: origin, to: end,
                    tint: tint, tileSize: tileSize, index: index,
                    delay: max(0, arrival - travel), travel: travel)
                crop.addChild(link)
            }
        }

        Effects.haptic(style == .eruption ? .rigid : .soft, intensity: style == .eruption ? 0.34 : 0.22)
        Audio.shared.play(style == .whaleWave ? .fish : style == .eruption ? .crate : .colorCharge,
                          pan: soundPan(at: origin))
        root.run(.sequence([.wait(forDuration: sequence.impactAt), .run { [weak self, weak crop] in
            guard let self, let crop else { return }
            Effects.haptic(style == .frost ? .rigid : .heavy, intensity: style == .eruption ? 0.95 : 0.72)
            if sequence.shakeStrength > 0 {
                Effects.shake(self.worldNode, intensity: CGFloat(sequence.shakeStrength), duration: 0.22)
            }
            Audio.shared.play(style == .eruption ? .bomb : style == .whaleWave ? .fish : .wrapped,
                              pan: self.soundPan(at: origin))
            crop.addChild(WorldComboMotion.impact(style: style, at: origin,
                tint: tint, tileSize: self.tileSize))
            let particles = WorldEffectTextures.burst(style: style, tint: tint, count: sequence.particleCount)
            particles.position = origin
            crop.addChild(particles)
        }]))
        SignatureMotion.remove(root, after: sequence.finishesAt)
    }
}

/// A small material vocabulary gives every world a distinct silhouette and
/// rhythm. All coordinates are decorative and derived from resolved cells.
private enum WorldComboMotion {
    static func material(for style: WorldComboStyle) -> String {
        switch style {
        case .frost: return "iceShard"
        case .honey: return "honey"
        case .whaleWave: return "bubble"
        case .firefly: return "firefly"
        case .sandstorm, .amber: return "sand"
        case .petal: return "petal"
        case .sugar, .rainbow, .cosmic: return "sparkle"
        case .eruption: return "ember"
        }
    }

    static func animateHero(_ hero: SKSpriteNode, style: WorldComboStyle,
                            origin: CGPoint, tileSize: CGFloat, impactAt: TimeInterval) {
        guard !SignatureMotion.isReduced else { hero.alpha = 0; return }
        let lead: SKAction
        let release: SKAction
        hero.setScale(0.74)
        switch style {
        case .whaleWave:
            hero.position = CGPoint(x: origin.x - tileSize * 1.9, y: origin.y - tileSize * 0.70)
            let arc = CGMutablePath()
            arc.move(to: hero.position)
            arc.addQuadCurve(to: origin, control: CGPoint(x: origin.x - tileSize * 0.8,
                                                         y: origin.y + tileSize * 1.65))
            lead = .group([.follow(arc, asOffset: false, orientToPath: false, duration: impactAt),
                .scale(to: 1, duration: impactAt), .sequence([
                    .rotate(toAngle: 0.20, duration: impactAt * 0.45),
                    .rotate(toAngle: -0.10, duration: impactAt * 0.55)])])
            release = .group([.moveBy(x: tileSize * 1.4, y: -tileSize * 0.9, duration: 0.40),
                .rotate(toAngle: -0.22, duration: 0.40), .fadeOut(withDuration: 0.40)])
        case .eruption:
            lead = .sequence([.scale(to: 0.96, duration: impactAt * 0.60),
                .group([.scaleX(to: 1.10, duration: impactAt * 0.40),
                        .scaleY(to: 0.86, duration: impactAt * 0.40)])])
            release = .group([.scale(to: 1.32, duration: 0.16), .fadeOut(withDuration: 0.20)])
        case .frost:
            hero.zRotation = -0.14
            lead = .group([.scale(to: 1, duration: impactAt), .rotate(toAngle: 0, duration: impactAt)])
            release = .group([.scaleX(to: 1.24, duration: 0.12), .scaleY(to: 1.12, duration: 0.12),
                .fadeOut(withDuration: 0.16)])
        case .honey:
            lead = .sequence([.group([.scaleX(to: 0.82, duration: impactAt * 0.55),
                                      .scaleY(to: 1.06, duration: impactAt * 0.55)]),
                .group([.scaleX(to: 1.10, duration: impactAt * 0.45),
                        .scaleY(to: 0.86, duration: impactAt * 0.45)])])
            release = .sequence([.group([.scaleX(to: 0.96, duration: 0.12), .scaleY(to: 1.08, duration: 0.12)]),
                .group([.moveBy(x: 0, y: -tileSize * 0.25, duration: 0.26), .fadeOut(withDuration: 0.26)])])
        case .rainbow:
            hero.position.y -= tileSize * 0.45
            lead = .group([.move(to: origin, duration: impactAt), .scale(to: 1, duration: impactAt)])
            release = .group([.moveBy(x: tileSize * 0.20, y: tileSize * 1.25, duration: 0.40),
                .rotate(toAngle: -0.12, duration: 0.40), .fadeOut(withDuration: 0.40)])
        case .amber:
            hero.zRotation = -0.24
            lead = .group([.rotate(toAngle: 0.10, duration: impactAt), .scale(to: 1, duration: impactAt)])
            release = .group([.scale(to: 1.17, duration: 0.28), .fadeOut(withDuration: 0.28)])
        case .firefly:
            lead = .sequence([.group([.scale(to: 0.94, duration: impactAt * 0.7),
                .rotate(toAngle: -0.12, duration: impactAt * 0.7)]),
                .rotate(toAngle: 0.08, duration: impactAt * 0.3)])
            release = .group([.moveBy(x: 0, y: tileSize * 0.40, duration: 0.35), .fadeOut(withDuration: 0.35)])
        case .sandstorm:
            hero.zRotation = -0.35
            lead = .group([.scale(to: 1.04, duration: impactAt), .rotate(toAngle: 0.35, duration: impactAt)])
            release = .group([.rotate(byAngle: 0.8, duration: 0.34), .scale(to: 1.2, duration: 0.34),
                .fadeOut(withDuration: 0.34)])
        case .cosmic:
            lead = .group([.scale(to: 0.96, duration: impactAt), .rotate(toAngle: 0.20, duration: impactAt)])
            release = .sequence([.scale(to: 0.84, duration: 0.06),
                .group([.scale(to: 1.24, duration: 0.24), .fadeOut(withDuration: 0.24)])])
        case .petal:
            hero.zRotation = -0.24
            lead = .group([.rotate(toAngle: 0.06, duration: impactAt), .scale(to: 1, duration: impactAt)])
            release = .group([.moveBy(x: tileSize * 0.4, y: tileSize * 0.7, duration: 0.42),
                .rotate(toAngle: 0.30, duration: 0.42), .fadeOut(withDuration: 0.42)])
        case .sugar:
            lead = .sequence([.scale(to: 0.98, duration: impactAt * 0.65),
                .group([.scaleX(to: 1.10, duration: impactAt * 0.35),
                        .scaleY(to: 0.88, duration: impactAt * 0.35)])])
            release = .group([.scale(to: 1.26, duration: 0.22), .rotate(byAngle: 0.15, duration: 0.22),
                .fadeOut(withDuration: 0.22)])
        }
        lead.timingMode = .easeInEaseOut
        hero.run(.sequence([lead, release]))
    }

    static func charge(style: WorldComboStyle, at point: CGPoint, tint: UIColor,
                       tileSize: CGFloat, duration: TimeInterval) -> SKNode {
        if SignatureMotion.isReduced { return SignatureMotion.quietMark(at: point, tint: tint) }
        let root = SKNode()
        root.position = point
        let count = style == .firefly ? 6 : 4
        for index in 0..<count {
            let angle = CGFloat(index) * .pi * 2 / CGFloat(count)
            let mote = SKSpriteNode(texture: WorldComboArtwork.material(material(for: style)))
            mote.size = CGSize(width: style == .honey ? 18 : 12, height: style == .honey ? 22 : 12)
            mote.position = CGPoint(x: cos(angle) * tileSize, y: sin(angle) * tileSize * 0.75)
            mote.color = tint
            mote.colorBlendFactor = 0.28
            root.addChild(mote)
            let path = CGMutablePath()
            path.move(to: mote.position)
            path.addQuadCurve(to: .zero, control: CGPoint(x: -sin(angle) * tileSize * 0.65,
                                                         y: cos(angle) * tileSize * 0.65))
            mote.run(.group([.follow(path, asOffset: false, orientToPath: false, duration: duration),
                .sequence([.wait(forDuration: duration * 0.65), .fadeOut(withDuration: duration * 0.35)])]))
        }
        // Thin local rings sell charge without dimming the whole board.
        let ring = SKShapeNode(ellipseOf: CGSize(width: tileSize * 2.0,
            height: tileSize * (style == .cosmic || style == .sandstorm ? 0.85 : 2.0)))
        ring.fillColor = .clear
        ring.strokeColor = tint.withAlphaComponent(0.70)
        ring.lineWidth = style == .honey ? 3 : 1.5
        root.addChild(ring)
        ring.run(.group([.scale(to: 0.45, duration: duration), .fadeOut(withDuration: duration)]))
        SignatureMotion.remove(root, after: duration + 0.02)
        return root
    }

    static func targetTrail(style: WorldComboStyle, from start: CGPoint, to end: CGPoint,
                            tint: UIColor, tileSize: CGFloat, index: Int,
                            delay: TimeInterval, travel: TimeInterval) -> SKNode {
        if SignatureMotion.isReduced { return SignatureMotion.quietMark(at: end, tint: tint, delay: delay + travel) }
        let root = SKNode()
        root.alpha = 0
        let path = CGMutablePath()
        path.move(to: start)
        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        if style == .eruption || style == .frost || style == .amber {
            path.addLine(to: CGPoint(x: midpoint.x + CGFloat(index % 3 - 1) * tileSize * 0.18,
                                    y: midpoint.y - tileSize * 0.13))
            path.addLine(to: end)
        } else {
            let lift: CGFloat = style == .honey ? -0.40 : style == .whaleWave ? 0.75 : style == .petal ? 0.65 : 0.45
            path.addQuadCurve(to: end, control: CGPoint(x: midpoint.x + CGFloat(index % 3 - 1) * tileSize * 0.25,
                                                       y: midpoint.y + tileSize * lift))
        }
        let strand = SKShapeNode(path: path)
        strand.fillColor = .clear
        strand.strokeColor = tint.withAlphaComponent(style == .firefly ? 0.35 : 0.58)
        strand.lineWidth = style == .honey ? 5 : style == .whaleWave ? 3.5 : 2
        strand.lineCap = .round
        root.addChild(strand)
        if style == .rainbow || style == .sugar {
            for (lane, hex) in ["#FF7ABB", "#FFE48D", "#83DCFF"].enumerated() {
                let ribbon = SKShapeNode(path: path)
                ribbon.fillColor = .clear
                ribbon.strokeColor = UIColor(hex: hex).withAlphaComponent(0.72)
                ribbon.lineWidth = 1.5
                ribbon.position.y = CGFloat(lane - 1) * 3
                root.addChild(ribbon)
            }
        }
        let head = SKSpriteNode(texture: WorldComboArtwork.material(material(for: style)))
        head.size = CGSize(width: style == .honey ? 19 : 14, height: style == .honey ? 24 : 14)
        head.position = start
        head.color = tint
        head.colorBlendFactor = 0.18
        root.addChild(head)
        head.run(.sequence([.wait(forDuration: delay),
            .follow(path, asOffset: false, orientToPath: false, duration: max(0.01, travel)),
            .fadeOut(withDuration: 0.06)]))
        root.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.02),
            .wait(forDuration: max(0, travel - 0.02)), .run { [weak root] in
                root?.addChild(SignatureMotion.quietMark(at: end, tint: tint, radius: tileSize * 0.28))
            }, .fadeOut(withDuration: 0.18), .removeFromParent()]))
        return root
    }

    static func impact(style: WorldComboStyle, at point: CGPoint,
                       tint: UIColor, tileSize: CGFloat) -> SKNode {
        if SignatureMotion.isReduced { return SignatureMotion.quietMark(at: point, tint: tint) }
        let root = SKNode()
        root.position = point
        switch style {
        case .whaleWave:
            // A low, broad wake followed by a smaller second ripple.
            for index in 0..<3 {
                let wake = SKShapeNode(ellipseOf: CGSize(width: tileSize * 0.8, height: tileSize * 0.32))
                wake.strokeColor = UIColor(hex: "#DAFCFF").withAlphaComponent(0.8)
                wake.fillColor = .clear
                wake.lineWidth = CGFloat(5 - index)
                wake.position.y = -tileSize * 0.30 - CGFloat(index) * 5
                root.addChild(wake)
                wake.run(.sequence([.wait(forDuration: Double(index) * 0.07),
                    .group([.scale(to: 4.5, duration: 0.38), .fadeOut(withDuration: 0.38)])]))
            }
        case .frost, .amber:
            for index in 0..<6 {
                let angle = CGFloat(index) * .pi / 3
                let ray = SKShapeNode(rectOf: CGSize(width: 3, height: tileSize * 0.9), cornerRadius: 1.5)
                ray.fillColor = tint.withAlphaComponent(0.85)
                ray.strokeColor = .clear
                ray.position = CGPoint(x: cos(angle) * tileSize * 0.30, y: sin(angle) * tileSize * 0.30)
                ray.zRotation = angle - .pi / 2
                root.addChild(ray)
                ray.run(.group([.moveBy(x: cos(angle) * tileSize * 1.4, y: sin(angle) * tileSize * 1.4, duration: 0.25),
                    .scaleY(to: 0.30, duration: 0.25), .fadeOut(withDuration: 0.25)]))
            }
        case .sandstorm, .cosmic:
            for index in 0..<3 {
                let orbit = SKShapeNode(ellipseOf: CGSize(width: tileSize * 1.4, height: tileSize * 0.50))
                orbit.fillColor = .clear
                orbit.strokeColor = tint.withAlphaComponent(0.8 - CGFloat(index) * 0.14)
                orbit.lineWidth = style == .sandstorm ? 4 : 2
                orbit.zRotation = CGFloat(index) * .pi / 3
                root.addChild(orbit)
                orbit.run(.group([.scale(to: 2.4, duration: 0.40),
                    .rotate(byAngle: style == .sandstorm ? 0.8 : 0.30, duration: 0.40),
                    .fadeOut(withDuration: 0.40)]))
            }
        case .petal, .firefly:
            for index in 0..<6 {
                let angle = CGFloat(index) * .pi / 3
                let petal = SKSpriteNode(texture: WorldComboArtwork.material(material(for: style)))
                petal.size = CGSize(width: style == .petal ? 22 : 16, height: style == .petal ? 28 : 16)
                root.addChild(petal)
                let path = CGMutablePath()
                path.move(to: .zero)
                path.addQuadCurve(to: CGPoint(x: cos(angle) * tileSize * 1.8, y: sin(angle) * tileSize * 1.6),
                    control: CGPoint(x: -sin(angle) * tileSize, y: cos(angle) * tileSize))
                petal.run(.group([.follow(path, asOffset: false, orientToPath: false, duration: 0.45),
                    .rotate(byAngle: 0.6, duration: 0.45),
                    .sequence([.wait(forDuration: 0.15), .fadeOut(withDuration: 0.30)])]))
            }
        case .sugar, .rainbow, .honey, .eruption:
            let colors = style == .sugar || style == .rainbow
                ? [UIColor(hex: "#FF85C2"), UIColor(hex: "#FFE697"), UIColor(hex: "#91DEFF")]
                : [tint, UIColor(hex: "#FFF0C1")]
            for (index, color) in colors.enumerated() {
                let ring = SKShapeNode(circleOfRadius: tileSize * 0.34)
                ring.fillColor = .clear
                ring.strokeColor = color.withAlphaComponent(0.80)
                ring.lineWidth = style == .honey ? 6 : style == .eruption ? 5 : 3
                root.addChild(ring)
                ring.run(.sequence([.wait(forDuration: Double(index) * 0.055),
                    .group([.scale(to: style == .eruption ? 4.3 : 3.3, duration: 0.32),
                            .fadeOut(withDuration: 0.32)])]))
            }
        }
        SignatureMotion.remove(root, after: 0.58)
        return root
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
        let budget = SignatureMotion.isReduced ? 0 : min(36, max(0, count))
        emitter.particleTexture = WorldComboArtwork.material(WorldComboMotion.material(for: style))
        emitter.particleBirthRate = budget == 0 ? 0 : 420
        emitter.numParticlesToEmit = max(1, budget)
        emitter.particleLifetime = style == .honey ? 0.46 : 0.38
        emitter.particleLifetimeRange = 0.06
        emitter.particleSpeed = style == .honey ? 100 : style == .firefly || style == .petal ? 85 : 185
        emitter.particleSpeedRange = 65
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = style == .whaleWave || style == .honey ? .pi * 0.8 : .pi * 2
        emitter.yAcceleration = style == .eruption ? -420 : style == .honey ? -300 : style == .whaleWave ? -240 : -80
        emitter.particleScale = style == .frost ? 0.42 : style == .petal ? 0.38 : 0.28
        emitter.particleScaleRange = 0.08
        emitter.particleScaleSpeed = -0.24
        emitter.particleAlphaSpeed = -1.8
        emitter.particleColor = tint
        emitter.particleColorBlendFactor = 0.25
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = style == .eruption || style == .sandstorm ? 4 : style == .petal ? 1.2 : 0
        SignatureMotion.remove(emitter, after: 0.68)
        return emitter
    }
}
