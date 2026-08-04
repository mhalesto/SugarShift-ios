import SpriteKit
import UIKit

/// Visual + tactile feedback for the game scene. Pure factory functions so the
/// scene just calls Effects.showX(in: self, …) and gets out of the way.
enum Effects {
    private static var textureCache: [String: SKTexture] = [:]
    private static let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    private static let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationHaptic = UINotificationFeedbackGenerator()

    // MARK: - Combo phrases

    static func comboPhrase(forDepth depth: Int) -> (text: String, color: UIColor)? {
        switch depth {
        case 2: return ("NICE CHAIN!",  UIColor(hex: "#FACC15"))
        case 3: return ("SWEET COMBO!", UIColor(hex: "#F472B6"))
        case 4: return ("HUGE CLEAR!",  UIColor(hex: "#34D399"))
        case 5: return ("AMAZING!",     UIColor(hex: "#A78BFA"))
        case 6: return ("CRUSHED!",     UIColor(hex: "#F97316"))
        case 7: return ("SUGAR RUSH!",  UIColor(hex: "#EF4444"))
        case 8: return ("SUGAR STORM!", UIColor(hex: "#EC4899"))
        default:
            if depth >= 9 { return ("UNREAL!", UIColor(hex: "#7C3AED")) }
            return nil
        }
    }

    static func bigClearPhrase(forCount count: Int) -> (text: String, color: UIColor)? {
        switch count {
        case 4:      return ("NICE CLEAR!", UIColor(hex: "#FACC15"))
        case 5:      return ("AWESOME!",    UIColor(hex: "#FB923C"))
        case 6...7:  return ("HUGE CLEAR!", UIColor(hex: "#F472B6"))
        case 8...9:  return ("MEGA CLEAR!", UIColor(hex: "#F97316"))
        case 10...11:return ("EPIC!",       UIColor(hex: "#A855F7"))
        default:
            if count >= 12 { return ("LEGENDARY!", UIColor(hex: "#EF4444")) }
            return nil
        }
    }

    // MARK: - Score popup

    /// Floating "+30" that drifts up and fades. Call once per cleared cluster.
    static func showScorePopup(_ amount: Int,
                               at point: CGPoint,
                               in scene: SKScene,
                               color: UIColor = .white) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "+\(amount)"
        label.fontSize = amount >= 100 ? 30 : 26
        label.fontColor = color
        label.position = point
        label.zPosition = 800
        label.setScale(0.4)
        scene.addChild(label)

        let pop = SKAction.group([
            .scale(to: 1.25, duration: 0.18),
            .fadeAlpha(to: 1.0, duration: 0.1)
        ])
        let drift = SKAction.group([
            .move(by: CGVector(dx: 0, dy: 70), duration: 0.7),
            .scale(to: 1.0, duration: 0.7),
            .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.25)])
        ])
        label.run(.sequence([pop, drift, .removeFromParent()]))
    }

    // MARK: - Combo banner

    /// Mid-screen cinematic banner — radial wedge starburst, big text with
    /// outline, sparkle ring around it. Auto-removes.
    static func showComboBanner(text: String,
                                color: UIColor,
                                in scene: SKScene) {
        let container = SKNode()
        container.zPosition = 900
        container.alpha = 0
        container.setScale(0.3)
        let majorKeywords = ["BOARD", "SMASH", "CROWN", "SUGAR", "UNREAL", "MEGA", "RAINBOW", "SUPER"]
        let isMajor = majorKeywords.contains { text.localizedCaseInsensitiveContains($0) }
        let burstRadius: CGFloat = isMajor ? 210 : 145

        // Radial starburst wedges behind the text
        let wedgeCount = 12
        for i in 0..<wedgeCount {
            let theta = CGFloat(i) * (.pi * 2 / CGFloat(wedgeCount))
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: cos(theta - 0.10) * burstRadius,
                                       y: sin(theta - 0.10) * burstRadius))
            path.addLine(to: CGPoint(x: cos(theta + 0.10) * burstRadius,
                                       y: sin(theta + 0.10) * burstRadius))
            path.close()
            let wedge = SKShapeNode(path: path.cgPath)
            wedge.fillColor = (i % 2 == 0)
                ? color.withAlphaComponent(isMajor ? 0.28 : 0.17)
                : UIColor.white.withAlphaComponent(isMajor ? 0.16 : 0.09)
            wedge.strokeColor = .clear
            wedge.blendMode = .add
            wedge.zPosition = -2
            container.addChild(wedge)
        }
        // Slowly spin the wedges so the banner looks alive
        if let wedgeParent = container.children.first?.parent {
            wedgeParent.run(.repeatForever(.rotate(byAngle: .pi / 2, duration: 4)))
        }

        // Soft glow halo
        let halo = SKShapeNode(circleOfRadius: isMajor ? 90 : 66)
        halo.fillColor = color.withAlphaComponent(isMajor ? 0.35 : 0.22)
        halo.strokeColor = .clear
        halo.glowWidth = 16
        halo.blendMode = .add
        halo.zPosition = -1
        container.addChild(halo)

        let maxFont: CGFloat = isMajor ? 56 : 44
        let bannerFontSize = min(maxFont, max(CGFloat(30), 560 / CGFloat(max(6, text.count))))

        // Drop shadow text
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = bannerFontSize
        shadow.fontColor = UIColor(white: 0, alpha: 0.55)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 3, y: -4)
        container.addChild(shadow)

        // White outline (offset stamps for a thick stroke effect)
        for off: (CGFloat, CGFloat) in [(-2, 0), (2, 0), (0, -2), (0, 2)] {
            let outline = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            outline.text = text
            outline.fontSize = bannerFontSize
            outline.fontColor = .white
            outline.horizontalAlignmentMode = .center
            outline.verticalAlignmentMode = .center
            outline.position = CGPoint(x: off.0, y: off.1)
            container.addChild(outline)
        }

        // Main coloured text on top
        let main = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        main.text = text
        main.fontSize = bannerFontSize
        main.fontColor = color
        main.horizontalAlignmentMode = .center
        main.verticalAlignmentMode = .center
        container.addChild(main)

        // Sparkles flying outward from the banner
        for _ in 0..<(isMajor ? 14 : 8) {
            let s = CGFloat.random(in: 6...11)
            let star = SKShapeNode(path: smashStarPath(size: s).cgPath)
            star.fillColor = .white
            star.strokeColor = color.withAlphaComponent(0.7)
            star.lineWidth = 0.6
            star.glowWidth = 4
            star.blendMode = .add
            star.zPosition = 1
            star.alpha = 0
            container.addChild(star)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 110...210)
            star.run(.sequence([
                .wait(forDuration: 0.10),
                .group([
                    .fadeAlpha(to: 1.0, duration: 0.1),
                    .move(by: CGVector(dx: cos(angle) * speed,
                                        dy: sin(angle) * speed),
                          duration: 0.7),
                    .sequence([.scale(to: 1.4, duration: 0.35),
                               .scale(to: 0.2, duration: 0.35)]),
                    .sequence([.wait(forDuration: 0.4),
                               .fadeOut(withDuration: 0.3)])
                ]),
                .removeFromParent()
            ]))
        }

        scene.addChild(container)

        // Soft screen flash — gentler than a true strobe, and skipped entirely
        // for users who've enabled Reduce Motion so it can't trigger photosensitive
        // reactions. Slow ramp-up + ramp-down stays well under WCAG 2.1's three
        // flashes-per-second guidance.
        if !Persistence.reduceMotion {
            let flash = SKShapeNode(rectOf: scene.size)
            flash.fillColor = .white
            flash.strokeColor = .clear
            flash.alpha = 0
            flash.zPosition = 880
            scene.addChild(flash)
            flash.run(.sequence([
                .fadeAlpha(to: isMajor ? 0.14 : 0.07, duration: 0.12),
                .fadeOut(withDuration: 0.32),
                .removeFromParent()
            ]))
        }

        let inAnim = SKAction.group([
            .scale(to: 1.18, duration: 0.20),
            .fadeIn(withDuration: 0.14)
        ])
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        let hold = SKAction.wait(forDuration: isMajor ? 0.50 : 0.32)
        let out = SKAction.group([
            .scale(to: 1.5, duration: 0.32),
            .fadeOut(withDuration: 0.32),
            .moveBy(x: 0, y: 24, duration: 0.32)
        ])
        container.run(.sequence([inAnim, settle, hold, out, .removeFromParent()]))

        // Subtle wiggle while held — gives the text "weight"
        main.run(.repeat(.sequence([
            .rotate(byAngle:  0.05, duration: 0.07),
            .rotate(byAngle: -0.10, duration: 0.13),
            .rotate(byAngle:  0.05, duration: 0.07)
        ]), count: 3))
    }

    // MARK: - Tile burst (small particle pop on each cleared tile)

    /// Programmatic particle emitter — no .sks file needed. Caller positions it.
    static func makeTileBurst(tint: UIColor, count: Int = 14) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeCirclePixel(diameter: 8, color: .white)
        emitter.particleColor = tint
        emitter.particleColorBlendFactor = 1.0
        emitter.numParticlesToEmit = max(3, count)
        emitter.particleBirthRate = 600
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 180
        emitter.particleSpeedRange = 80
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -1.6
        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.35
        emitter.particleScaleSpeed = -1.2
        emitter.yAcceleration = -180
        emitter.zPosition = 700
        emitter.targetNode = nil
        return emitter
    }

    // MARK: - Smash effects (per-tile shards + center flash + sparkles)

    /// Sharp colored shards flying outward — looks like the tile candy cracked.
    /// `count` and `size` scale up for higher-impact moments.
    static func makeShardBurst(tint: UIColor, count: Int = 8, size: CGFloat = 18) -> SKNode {
        let container = SKNode()
        for _ in 0..<count {
            let shardSize = CGFloat.random(in: size * 0.45 ... size)
            let path = makeShardPath(size: shardSize)
            let shard = SKShapeNode(path: path.cgPath)
            shard.fillColor = tint
            shard.strokeColor = UIColor(white: 0, alpha: 0.30)
            shard.lineWidth = 0.8
            shard.position = CGPoint(x: CGFloat.random(in: -3...3),
                                      y: CGFloat.random(in: -3...3))
            shard.zPosition = 700
            container.addChild(shard)

            shard.zRotation = CGFloat.random(in: 0...(.pi * 2))
            shard.run(.repeatForever(.rotate(byAngle: CGFloat.random(in: -2.6...2.6),
                                              duration: 0.6)))

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 90...170)
            let dur = TimeInterval.random(in: 0.55...0.85)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed

            shard.run(.sequence([
                .group([
                    .move(by: CGVector(dx: dx, dy: dy), duration: dur),
                    .sequence([
                        .scale(to: 1.1, duration: dur * 0.25),
                        .scale(to: 0.25, duration: dur * 0.75)
                    ]),
                    .fadeOut(withDuration: dur)
                ]),
                .removeFromParent()
            ]))
        }
        return container
    }

    /// Breaks the actual fruit artwork into small cropped sprites so a smashed
    /// apple still reads as apple pieces instead of generic coloured triangles.
    /// Blockers continue to use geometric chunks because their material is not
    /// represented by the fruit texture.
    static func makeFruitFragmentBurst(texture: SKTexture?,
                                       tint: UIColor,
                                       count: Int = 5,
                                       size: CGFloat = 18,
                                       gravity: CGFloat = -390) -> SKNode {
        guard let texture else {
            return makeShardBurst(tint: tint, count: count, size: size)
        }

        let container = SKNode()
        let columns = 3
        let rows = 2
        let pieceCount = max(1, min(count, columns * rows))
        for index in 0..<pieceCount {
            let column = index % columns
            let row = index / columns
            let rect = CGRect(x: CGFloat(column) / CGFloat(columns),
                              y: CGFloat(row) / CGFloat(rows),
                              width: 1 / CGFloat(columns),
                              height: 1 / CGFloat(rows))
            let fragmentTexture = SKTexture(rect: rect, in: texture)
            let fragment = SKSpriteNode(texture: fragmentTexture)
            let fragmentScale = CGFloat.random(in: 0.78...1.12)
            fragment.size = CGSize(width: size * fragmentScale,
                                   height: size * fragmentScale)
            fragment.color = tint
            fragment.colorBlendFactor = 0.08
            fragment.position = CGPoint(x: (CGFloat(column) - 1) * size * 0.45,
                                        y: (CGFloat(row) - 0.5) * size * 0.45)
            fragment.zPosition = 738
            fragment.zRotation = CGFloat.random(in: -0.25...0.25)
            container.addChild(fragment)

            let angle = CGFloat.random(in: 0.18...(.pi - 0.18))
            let speed = CGFloat.random(in: 135...235)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed
            let spin = CGFloat.random(in: -8...8)
            let duration = TimeInterval.random(in: 0.48...0.74)
            let start = fragment.position
            var previousElapsed: CGFloat = 0
            fragment.run(.sequence([
                .customAction(withDuration: duration) { node, elapsed in
                    let t = CGFloat(elapsed)
                    let dt = max(0, t - previousElapsed)
                    previousElapsed = t
                    node.position = CGPoint(x: start.x + vx * t,
                                            y: start.y + vy * t + 0.5 * gravity * t * t)
                    node.zRotation += spin * dt
                    node.alpha = max(0, 1 - t / CGFloat(duration))
                    node.setScale(max(0.30, 1 - t / CGFloat(duration) * 0.58))
                },
                .removeFromParent()
            ]))
        }
        container.run(.sequence([.wait(forDuration: 0.85), .removeFromParent()]))
        return container
    }

    /// Heavier fragments with a simple gravity curve. Used for blockers and
    /// bomb impacts so smashed pieces visibly fly away and fall.
    static func makeChunkBurst(tint: UIColor,
                               count: Int = 7,
                               size: CGFloat = 16,
                               gravity: CGFloat = -360) -> SKNode {
        let container = SKNode()
        for _ in 0..<count {
            let chunkSize = CGFloat.random(in: size * 0.45...size)
            let chunk = SKShapeNode(path: makeShardPath(size: chunkSize).cgPath)
            chunk.fillColor = tint
            chunk.strokeColor = UIColor(white: 0, alpha: 0.35)
            chunk.lineWidth = 0.9
            chunk.zPosition = 735
            chunk.alpha = 0.98
            chunk.zRotation = CGFloat.random(in: 0...(.pi * 2))
            container.addChild(chunk)

            let angle = CGFloat.random(in: 0.15...(.pi - 0.15))
            let speed = CGFloat.random(in: 150...270)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed
            let spin = CGFloat.random(in: -7...7)
            let duration = TimeInterval.random(in: 0.55...0.82)
            var previousElapsed: CGFloat = 0

            chunk.run(.sequence([
                .customAction(withDuration: duration) { node, elapsed in
                    let t = CGFloat(elapsed)
                    let dt = max(0, t - previousElapsed)
                    previousElapsed = t
                    node.position = CGPoint(x: vx * t,
                                            y: vy * t + 0.5 * gravity * t * t)
                    node.zRotation += spin * dt
                    node.alpha = max(0, 1 - t / CGFloat(duration))
                    node.setScale(max(0.22, 1 - t / CGFloat(duration) * 0.62))
                },
                .removeFromParent()
            ]))
        }
        container.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
        return container
    }

    /// Bright flash + expanding shockwave ring at an impact point.
    /// Pass `big = true` for chunky 4+ clears or combo cascades.
    /// Intensity is automatically reduced when the player enables Reduce Motion.
    static func makeImpactFlash(at point: CGPoint, big: Bool = false) -> SKNode {
        let reduce = Persistence.reduceMotion
        let node = SKNode()
        node.position = point
        node.zPosition = 720

        let radius: CGFloat = big ? 48 : 32
        let flash = SKShapeNode(circleOfRadius: radius)
        flash.fillColor = UIColor(hex: "#FFF8DC").withAlphaComponent(reduce ? 0.55 : 0.95)
        flash.strokeColor = .clear
        flash.glowWidth = big ? (reduce ? 10 : 18) : (reduce ? 6 : 12)
        flash.blendMode = .add
        flash.alpha = reduce ? 0.6 : 0.95
        flash.setScale(0.35)
        flash.zPosition = 721
        node.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: big ? 2.2 : 1.7, duration: reduce ? 0.45 : 0.34),
                    .fadeOut(withDuration: reduce ? 0.45 : 0.34)]),
            .removeFromParent()
        ]))

        // Expanding shockwave ring
        let ring = SKShapeNode(circleOfRadius: big ? 28 : 20)
        ring.fillColor = .clear
        ring.strokeColor = UIColor.white.withAlphaComponent(0.95)
        ring.lineWidth = big ? 4 : 3
        ring.glowWidth = big ? 5 : 3
        ring.zPosition = 722
        ring.setScale(0.4)
        node.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: big ? 3.2 : 2.4, duration: 0.5),
                    .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))

        // A second, faster inner ring for "punchy" impact
        let inner = SKShapeNode(circleOfRadius: big ? 14 : 10)
        inner.fillColor = .clear
        inner.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.95)
        inner.lineWidth = 2
        inner.glowWidth = 4
        inner.blendMode = .add
        inner.zPosition = 723
        node.addChild(inner)
        inner.run(.sequence([
            .group([.scale(to: big ? 2.4 : 2.0, duration: 0.32),
                    .fadeOut(withDuration: 0.32)]),
            .removeFromParent()
        ]))

        node.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
        return node
    }

    /// White star sparkles flying outward — the "candy magic" feel.
    static func makeStarSparkle(count: Int = 8) -> SKNode {
        let container = SKNode()
        for _ in 0..<count {
            let s = CGFloat.random(in: 7...13)
            let star = SKShapeNode(path: smashStarPath(size: s).cgPath)
            star.fillColor = .white
            star.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.8)
            star.lineWidth = 0.5
            star.glowWidth = 4
            star.blendMode = .add
            star.zPosition = 740
            star.alpha = 0.95
            container.addChild(star)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 70...140)
            let dur = TimeInterval.random(in: 0.55...0.85)

            star.zRotation = CGFloat.random(in: 0...(.pi * 2))
            star.run(.repeatForever(.rotate(byAngle: 6, duration: 0.8)))
            star.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * speed,
                                        dy: sin(angle) * speed), duration: dur),
                    .sequence([
                        .scale(to: 1.5, duration: dur * 0.4),
                        .scale(to: 0.2, duration: dur * 0.6)
                    ]),
                    .fadeOut(withDuration: dur)
                ]),
                .removeFromParent()
            ]))
        }
        container.run(.sequence([.wait(forDuration: 1.1), .removeFromParent()]))
        return container
    }

    // MARK: - Column beam (Candy Crush "striped candy" feel)

    /// Pink/cream vertical beam light + falling sparkles, evoking a striped-candy
    /// vertical clear effect. Auto-removes itself.
    static func makeColumnBeam(x: CGFloat,
                                fromY: CGFloat,
                                toY: CGFloat,
                                tint: UIColor) -> SKNode {
        let node = SKNode()
        node.zPosition = 730

        let height = toY - fromY
        // Soft pastel beam with rounded ends
        let beam = SKShapeNode(rectOf: CGSize(width: 36, height: height),
                                cornerRadius: 18)
        beam.fillColor = tint.withAlphaComponent(0.55)
        beam.strokeColor = .white
        beam.lineWidth = 1.5
        beam.glowWidth = 14
        beam.blendMode = .add
        beam.position = CGPoint(x: x, y: (fromY + toY) / 2)
        beam.alpha = 0.0
        beam.xScale = 0.2
        node.addChild(beam)

        beam.run(.sequence([
            .group([.fadeAlpha(to: 1.0, duration: 0.06),
                    .scaleX(to: 1.0, duration: 0.06)]),
            .wait(forDuration: 0.18),
            .group([.fadeOut(withDuration: 0.32),
                    .scaleX(to: 0.4, duration: 0.32)])
        ]))

        // White core line through the centre for an extra-bright streak
        let core = SKShapeNode(rectOf: CGSize(width: 8, height: height),
                                cornerRadius: 4)
        core.fillColor = UIColor.white.withAlphaComponent(0.85)
        core.strokeColor = .clear
        core.glowWidth = 6
        core.blendMode = .add
        core.position = beam.position
        core.alpha = 0.0
        node.addChild(core)
        core.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.12),
            .fadeOut(withDuration: 0.24)
        ]))

        // Cascading sparkles trailing along the beam
        let count = 18
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.6...3.4))
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.glowWidth = 3
            dot.blendMode = .add
            dot.position = CGPoint(x: x + CGFloat.random(in: -22...22),
                                    y: CGFloat.random(in: fromY...toY))
            dot.alpha = 0.0
            node.addChild(dot)
            let life = TimeInterval.random(in: 0.4...0.8)
            dot.run(.sequence([
                .wait(forDuration: TimeInterval.random(in: 0...0.18)),
                .group([.fadeAlpha(to: 1.0, duration: life * 0.3),
                        .moveBy(x: CGFloat.random(in: -10...10),
                                y: CGFloat.random(in: -40...40), duration: life)]),
                .fadeOut(withDuration: life * 0.4),
                .removeFromParent()
            ]))
        }

        node.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
        return node
    }

    /// A directional streak with a travelling impact head. Unlike the old
    /// screen-wide column decoration, this explicitly connects an origin and a
    /// destination, so the player can read what caused each lane clear.
    static func makeEnergySweep(from start: CGPoint,
                                to end: CGPoint,
                                tint: UIColor,
                                width: CGFloat = 12,
                                delay: TimeInterval = 0) -> SKNode {
        let node = SKNode()
        node.zPosition = 748
        node.alpha = 0

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let beam = SKShapeNode(rectOf: CGSize(width: length, height: width),
                               cornerRadius: width / 2)
        beam.fillColor = tint.withAlphaComponent(0.58)
        beam.strokeColor = UIColor.white.withAlphaComponent(0.88)
        beam.lineWidth = 1.4
        beam.glowWidth = 8
        beam.blendMode = .add
        beam.position = CGPoint(x: (start.x + end.x) / 2,
                                y: (start.y + end.y) / 2)
        beam.zRotation = angle
        node.addChild(beam)

        let head = SKShapeNode(circleOfRadius: max(6, width * 0.72))
        head.fillColor = .white
        head.strokeColor = tint
        head.lineWidth = 2
        head.glowWidth = 10
        head.blendMode = .add
        head.position = start
        node.addChild(head)

        let travel = max(0.10, min(0.28, TimeInterval(length / 950)))
        head.run(.sequence([
            .wait(forDuration: delay),
            .move(to: end, duration: travel),
            .removeFromParent()
        ]))
        node.run(.sequence([
            .wait(forDuration: delay),
            .fadeIn(withDuration: 0.035),
            .wait(forDuration: travel * 0.48),
            .fadeOut(withDuration: travel * 0.72),
            .removeFromParent()
        ]))
        return node
    }

    /// Curved objective-seeking flight used by fish combos. The motion is
    /// deliberately short and readable: players see where the fish chose to go
    /// without making the cascade wait several seconds.
    static func makeFishFlight(from start: CGPoint,
                               to end: CGPoint,
                               tint: UIColor,
                               delay: TimeInterval = 0) -> SKNode {
        let node = SKNode()
        node.zPosition = 770
        let fish = Icons.sprite("fish.fill", size: 30, weight: .heavy, tint: tint)
        fish.position = start
        fish.alpha = 0
        fish.setScale(0.72)
        node.addChild(fish)

        let path = UIBezierPath()
        path.move(to: start)
        let midpoint = CGPoint(x: (start.x + end.x) / 2,
                               y: (start.y + end.y) / 2 + max(28, abs(end.x - start.x) * 0.16))
        path.addQuadCurve(to: end, controlPoint: midpoint)
        let duration: TimeInterval = 0.22
        fish.run(.sequence([
            .wait(forDuration: delay),
            .fadeIn(withDuration: 0.04),
            .group([
                .follow(path.cgPath, asOffset: false, orientToPath: true, duration: duration),
                .sequence([.scale(to: 1.05, duration: duration * 0.55),
                           .scale(to: 0.72, duration: duration * 0.45)])
            ]),
            .fadeOut(withDuration: 0.04),
            .removeFromParent()
        ]))

        node.run(.sequence([
            .wait(forDuration: delay + duration),
            .run { [weak node] in
                node?.addChild(makeImpactFlash(at: end, big: false))
            },
            .wait(forDuration: 0.75),
            .removeFromParent()
        ]))
        return node
    }

    // MARK: - Bomb detonation (lightning bolts + ring blast)

    /// A jagged electric lightning bolt radiating outward from a point.
    /// `angle` (radians) sets the direction, `length` sets reach.
    static func makeLightningBolt(angle: CGFloat,
                                    length: CGFloat,
                                    tint: UIColor = UIColor(hex: "#FACC15")) -> SKNode {
        let node = SKNode()

        let path = UIBezierPath()
        path.move(to: .zero)
        let segments = 6
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let segLen = length * t
            let baseX = cos(angle) * segLen
            let baseY = sin(angle) * segLen
            let perpX = -sin(angle)
            let perpY =  cos(angle)
            // Jitter scales down toward the end so the bolt converges visually.
            let jitter = CGFloat.random(in: -16...16) * (1 - t * 0.7)
            path.addLine(to: CGPoint(x: baseX + perpX * jitter,
                                       y: baseY + perpY * jitter))
        }

        // White glow under-layer
        let glow = SKShapeNode(path: path.cgPath)
        glow.strokeColor = .white
        glow.lineWidth = 7
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.glowWidth = 10
        glow.blendMode = .add
        glow.fillColor = .clear
        glow.alpha = 0.85
        node.addChild(glow)

        // Coloured zig-zag on top
        let bolt = SKShapeNode(path: path.cgPath)
        bolt.strokeColor = tint
        bolt.lineWidth = 3
        bolt.lineCap = .round
        bolt.lineJoin = .round
        bolt.glowWidth = 4
        bolt.blendMode = .add
        bolt.fillColor = .clear
        node.addChild(bolt)

        // Gentler flicker (down to 2 cycles at slower rate so we stay below
        // the photosensitive 3-flashes-per-second threshold) then fade out.
        // Reduce Motion skips the flicker entirely.
        if Persistence.reduceMotion {
            node.run(.sequence([
                .fadeOut(withDuration: 0.35),
                .removeFromParent()
            ]))
        } else {
            node.run(.sequence([
                .repeat(.sequence([
                    .fadeAlpha(to: 0.55, duration: 0.10),
                    .fadeAlpha(to: 1.0, duration: 0.10)
                ]), count: 2),
                .fadeOut(withDuration: 0.28),
                .removeFromParent()
            ]))
        }
        return node
    }

    /// Big yellow/orange explosion ring + white shockwave at point. Pairs with
    /// the lightning bolts for the bomb-detonation showpiece.
    static func makeBombBlast(at point: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = point
        node.zPosition = 760

        // Bright yellow inner blast
        let core = SKShapeNode(circleOfRadius: 28)
        core.fillColor = UIColor(hex: "#FBBF24")
        core.strokeColor = UIColor(hex: "#FFFBEB")
        core.lineWidth = 3
        core.glowWidth = 16
        core.blendMode = .add
        core.alpha = 0.95
        core.setScale(0.3)
        node.addChild(core)
        core.run(.sequence([
            .group([.scale(to: 2.2, duration: 0.32),
                    .fadeOut(withDuration: 0.32)]),
            .removeFromParent()
        ]))

        // Outer orange ring
        let outer = SKShapeNode(circleOfRadius: 34)
        outer.fillColor = .clear
        outer.strokeColor = UIColor(hex: "#F97316")
        outer.lineWidth = 5
        outer.glowWidth = 8
        outer.blendMode = .add
        outer.setScale(0.4)
        node.addChild(outer)
        outer.run(.sequence([
            .group([.scale(to: 4.0, duration: 0.55),
                    .fadeOut(withDuration: 0.55)]),
            .removeFromParent()
        ]))

        // Pure white shock ring (fastest, sharpest)
        let shock = SKShapeNode(circleOfRadius: 22)
        shock.fillColor = .clear
        shock.strokeColor = .white
        shock.lineWidth = 4
        shock.glowWidth = 6
        shock.blendMode = .add
        shock.setScale(0.5)
        node.addChild(shock)
        shock.run(.sequence([
            .group([.scale(to: 5.0, duration: 0.4),
                    .fadeOut(withDuration: 0.4)]),
            .removeFromParent()
        ]))

        node.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
        return node
    }

    // MARK: - Falling tile sparkle trail

    /// A trailing emitter you attach to a node to leave a stardust trail behind it.
    /// Caller is responsible for removing/disabling once the node finishes moving.
    static func makeFallTrail(tint: UIColor = .white) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeCirclePixel(diameter: 6, color: .white)
        emitter.particleColor = tint
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBirthRate = 70
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngle = .pi / 2          // upward (so they linger above)
        emitter.emissionAngleRange = .pi / 6
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 20
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -1.6
        emitter.particleScale = 0.6
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -1.0
        emitter.zPosition = 6
        emitter.targetNode = nil
        return emitter
    }

    // MARK: - Smash shape paths

    private static func makeShardPath(size: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let r = size / 2
        // Pick 3 angles around the circle so we get an irregular triangle.
        let a0 = CGFloat.random(in: 0...0.6)             * (.pi * 2 / 3)
        let a1 = (CGFloat.random(in: 0...0.5) + 0.5)     * (.pi * 2 / 3) + (.pi * 2 / 3)
        let a2 = (CGFloat.random(in: 0...0.5) + 0.5)     * (.pi * 2 / 3) + (.pi * 4 / 3)
        for (i, theta) in [a0, a1, a2].enumerated() {
            let pt = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.close()
        return path
    }

    private static func smashStarPath(size: CGFloat) -> UIBezierPath {
        let p = UIBezierPath()
        let outer = size / 2
        let inner = outer * 0.42
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let theta = -CGFloat.pi / 2 + CGFloat(i) * (.pi / 5)
            let pt = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.close()
        return p
    }

    // MARK: - Confetti (big combos)

    static func makeConfetti(width: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeRectPixel(size: CGSize(width: 8, height: 14), color: .white)
        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBirthRate = 170
        emitter.numParticlesToEmit = 90
        emitter.particleLifetime = 2.4
        emitter.particleLifetimeRange = 0.6
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 5
        emitter.particleSpeed = 360
        emitter.particleSpeedRange = 160
        emitter.particlePositionRange = CGVector(dx: width, dy: 4)
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.25
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.4
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 4
        emitter.yAcceleration = -260
        emitter.xAcceleration = 0
        emitter.zPosition = 950

        // Multi-color via random per-particle hue
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            UIColor(hex: "#F472B6"),
            UIColor(hex: "#FACC15"),
            UIColor(hex: "#22D3EE"),
            UIColor(hex: "#A78BFA"),
            UIColor(hex: "#34D399"),
            UIColor(hex: "#F97316")
        ], times: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
        return emitter
    }

    // MARK: - Screen shake

    static func shake(_ node: SKNode, intensity: CGFloat = 8, duration: TimeInterval = 0.25) {
        guard !Persistence.reduceMotion else { return }
        let originalPos = node.position
        var actions: [SKAction] = []
        let steps = 6
        for _ in 0..<steps {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(.move(to: CGPoint(x: originalPos.x + dx, y: originalPos.y + dy),
                                  duration: duration / TimeInterval(steps * 2)))
            actions.append(.move(to: originalPos, duration: duration / TimeInterval(steps * 2)))
        }
        node.run(.sequence(actions))
    }

    // MARK: - Haptics

    static func prepareHaptics() {
        guard Persistence.hapticsEnabled else { return }
        softHaptic.prepare()
        lightHaptic.prepare()
        mediumHaptic.prepare()
        heavyHaptic.prepare()
        rigidHaptic.prepare()
        notificationHaptic.prepare()
    }

    static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                       intensity: CGFloat = 1.0) {
        guard Persistence.hapticsEnabled else { return }
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .soft: generator = softHaptic
        case .light: generator = lightHaptic
        case .medium: generator = mediumHaptic
        case .heavy: generator = heavyHaptic
        case .rigid: generator = rigidHaptic
        @unknown default: generator = mediumHaptic
        }
        generator.impactOccurred(intensity: max(0, min(1, intensity)))
        generator.prepare()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard Persistence.hapticsEnabled else { return }
        notificationHaptic.notificationOccurred(type)
        notificationHaptic.prepare()
    }

    // MARK: - Pixel helpers (for emitter textures)

    private static func makeCirclePixel(diameter: CGFloat, color: UIColor) -> SKTexture {
        let key = "circle:\(diameter):\(color.hashValue)"
        if let cached = textureCache[key] { return cached }
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        let texture = SKTexture(image: img)
        textureCache[key] = texture
        return texture
    }

    private static func makeRectPixel(size: CGSize, color: UIColor) -> SKTexture {
        let key = "rect:\(size.width)x\(size.height):\(color.hashValue)"
        if let cached = textureCache[key] { return cached }
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        let texture = SKTexture(image: img)
        textureCache[key] = texture
        return texture
    }
}
