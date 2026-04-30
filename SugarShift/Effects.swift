import SpriteKit
import UIKit

/// Visual + tactile feedback for the game scene. Pure factory functions so the
/// scene just calls Effects.showX(in: self, …) and gets out of the way.
enum Effects {

    // MARK: - Combo phrases

    static func comboPhrase(forDepth depth: Int) -> (text: String, color: UIColor)? {
        switch depth {
        case 2: return ("SWEET!",      UIColor(hex: "#FACC15"))
        case 3: return ("TASTY!",      UIColor(hex: "#F472B6"))
        case 4: return ("DELICIOUS!",  UIColor(hex: "#34D399"))
        case 5: return ("AMAZING!",    UIColor(hex: "#A78BFA"))
        default:
            if depth >= 6 { return ("SUGAR RUSH!", UIColor(hex: "#F97316")) }
            return nil
        }
    }

    static func bigClearPhrase(forCount count: Int) -> (text: String, color: UIColor)? {
        switch count {
        case 4...5: return ("NICE!",       UIColor(hex: "#FACC15"))
        case 6...8: return ("HUGE SMASH!", UIColor(hex: "#F472B6"))
        default:
            if count >= 9 { return ("MEGA!", UIColor(hex: "#F97316")) }
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
        label.fontSize = 24
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

    /// Mid-screen banner ("SWEET!", "SUGAR RUSH!"). Auto-removes.
    static func showComboBanner(text: String,
                                color: UIColor,
                                in scene: SKScene) {
        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = text
        banner.fontSize = 56
        banner.fontColor = color
        banner.horizontalAlignmentMode = .center
        banner.verticalAlignmentMode = .center
        banner.zPosition = 900
        banner.alpha = 0
        banner.setScale(0.3)

        // Shadow stroke
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = 56
        shadow.fontColor = UIColor(white: 0, alpha: 0.5)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 2, y: -3)
        shadow.zPosition = -1
        banner.addChild(shadow)

        scene.addChild(banner)

        let inAnim = SKAction.group([
            .scale(to: 1.15, duration: 0.18),
            .fadeIn(withDuration: 0.12)
        ])
        let settle = SKAction.scale(to: 1.0, duration: 0.1)
        let hold = SKAction.wait(forDuration: 0.45)
        let out = SKAction.group([
            .scale(to: 1.4, duration: 0.3),
            .fadeOut(withDuration: 0.3),
            .moveBy(x: 0, y: 20, duration: 0.3)
        ])

        banner.run(.sequence([inAnim, settle, hold, out, .removeFromParent()]))

        // Subtle wiggle while held
        banner.run(.repeat(.sequence([
            .rotate(byAngle: 0.04, duration: 0.06),
            .rotate(byAngle: -0.08, duration: 0.12),
            .rotate(byAngle: 0.04, duration: 0.06)
        ]), count: 3))
    }

    // MARK: - Tile burst (small particle pop on each cleared tile)

    /// Programmatic particle emitter — no .sks file needed. Caller positions it.
    static func makeTileBurst(tint: UIColor) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeCirclePixel(diameter: 8, color: .white)
        emitter.particleColor = tint
        emitter.particleColorBlendFactor = 1.0
        emitter.numParticlesToEmit = 14
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

    // MARK: - Confetti (big combos)

    static func makeConfetti(width: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeRectPixel(size: CGSize(width: 8, height: 14), color: .white)
        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBirthRate = 240
        emitter.numParticlesToEmit = 140
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

    static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard Persistence.hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard Persistence.hapticsEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(type)
    }

    // MARK: - Pixel helpers (for emitter textures)

    private static func makeCirclePixel(diameter: CGFloat, color: UIColor) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: img)
    }

    private static func makeRectPixel(size: CGSize, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: img)
    }
}
