import SpriteKit
import UIKit

/// Shared presentation vocabulary. These actions never mutate board state or
/// consume the gameplay generator; their owners keep resolution callbacks.
enum SignatureMotion {
    static var isReduced: Bool {
        Persistence.reduceMotion || UIAccessibility.isReduceMotionEnabled
    }

    static let clearDuration: TimeInterval = 0.18
    static let landingSettleDuration: TimeInterval = 0.115

    /// Fragment delivery belongs at the impact, after the fruit has compressed.
    /// Both accessibility paths occupy the same existing clear window.
    static func clearAction(major: Bool = false, impact: @escaping () -> Void = {}) -> SKAction {
        if isReduced {
            return .sequence([.run(impact), .fadeOut(withDuration: clearDuration)])
        }
        return .sequence([
            .group([.scaleX(to: major ? 1.17 : 1.12, duration: 0.045),
                    .scaleY(to: major ? 0.76 : 0.83, duration: 0.045)]),
            .run(impact),
            .group([
                .sequence([
                    .group([.scaleX(to: 0.94, duration: 0.035),
                            .scaleY(to: major ? 1.30 : 1.19, duration: 0.035)]),
                    .scale(to: major ? 1.42 : 1.28, duration: 0.10)
                ]),
                .fadeOut(withDuration: 0.135)
            ])
        ])
    }

    static func swapAction(to destination: CGPoint, duration: TimeInterval = 0.15) -> SKAction {
        let duration = max(0, duration)
        if isReduced {
            return .sequence([.fadeAlpha(to: 0.55, duration: duration / 2),
                .move(to: destination, duration: 0), .fadeIn(withDuration: duration / 2)])
        }
        let travel = SKAction.move(to: destination, duration: duration)
        travel.timingMode = .easeInEaseOut
        return .group([travel, .sequence([
            .group([.scaleX(to: 0.94, duration: duration * 0.30),
                    .scaleY(to: 1.06, duration: duration * 0.30)]),
            .group([.scaleX(to: 1.04, duration: duration * 0.35),
                    .scaleY(to: 0.96, duration: duration * 0.35)]),
            .scale(to: 1, duration: duration * 0.35)
        ])])
    }

    static func landingAction(to destination: CGPoint, duration: TimeInterval,
                              delay: TimeInterval) -> SKAction {
        let duration = max(0, duration)
        let delay = max(0, delay)
        if isReduced {
            return .sequence([.wait(forDuration: delay),
                .fadeOut(withDuration: duration * 0.45),
                .move(to: destination, duration: 0),
                .fadeIn(withDuration: duration * 0.55)])
        }
        let fall = SKAction.move(to: destination, duration: duration)
        fall.timingMode = .easeIn
        return .sequence([.wait(forDuration: delay), fall,
            .group([.scaleX(to: 1.10, duration: 0.040),
                    .scaleY(to: 0.86, duration: 0.040)]),
            .group([.scaleX(to: 0.98, duration: 0.035),
                    .scaleY(to: 1.035, duration: 0.035)]),
            .scale(to: 1, duration: 0.040)
        ])
    }

    static func blockerRecoilAction() -> SKAction {
        if isReduced { return .wait(forDuration: 0.16) }
        return .sequence([
            .group([.scaleX(to: 1.045, duration: 0.05), .scaleY(to: 0.95, duration: 0.05)]),
            .scale(to: 1, duration: 0.11)
        ])
    }

    /// An earned special gets one clean corona, without adding a pretend piece
    /// or changing the timing of its insertion into the grid.
    static func makeSpecialCreation(at point: CGPoint, tint: UIColor, tileSize: CGFloat) -> SKNode {
        let root = SKNode()
        root.position = point
        root.zPosition = 746
        let radius = max(8, tileSize * 0.40)
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.fillColor = .clear
        ring.strokeColor = tint.withAlphaComponent(0.85)
        ring.lineWidth = 2.5
        root.addChild(ring)
        if isReduced {
            root.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
            return root
        }
        ring.setScale(0.6)
        ring.run(.sequence([.scale(to: 1.15, duration: 0.16),
            .group([.scale(to: 1.4, duration: 0.28), .fadeOut(withDuration: 0.28)])]))
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let spark = SKSpriteNode(texture: WorldComboArtwork.material("sparkle"))
            spark.size = CGSize(width: 10, height: 10)
            spark.position = CGPoint(x: cos(angle) * radius * 0.45, y: sin(angle) * radius * 0.45)
            root.addChild(spark)
            spark.run(.group([
                .move(to: CGPoint(x: cos(angle) * radius * 1.65, y: sin(angle) * radius * 1.65), duration: 0.38),
                .sequence([.wait(forDuration: 0.12), .fadeOut(withDuration: 0.26)]),
                .scale(to: 0.3, duration: 0.38)
            ]))
        }
        remove(root, after: 0.48)
        return root
    }

    /// A whole clear receives at most 72 droplets and 36 artwork fragments,
    /// distributed across its ordered cells instead of multiplying per tile.
    static func clearDetail(index: Int, count: Int, major: Bool) -> (droplets: Int, fragments: Int) {
        guard !isReduced, count > 0, index >= 0, index < count else { return (0, 0) }
        func allocation(budget: Int, cap: Int) -> Int {
            // The quotient form avoids multiplying an untrusted count.
            let base = min(cap, budget / count)
            let remainder = budget % count
            return min(cap, base + (index < remainder ? 1 : 0))
        }
        return (allocation(budget: 72, cap: major ? 8 : 6),
                allocation(budget: 36, cap: major ? 5 : 3))
    }

    /// Real outlined text remains level and still while its backing settles.
    static func lettering(_ text: String, width: CGFloat, fontSize: CGFloat,
                          tint: UIColor) -> SKNode {
        let root = SKNode()
        let font = UIFont(name: "AvenirNext-Heavy", size: fontSize)
            ?? UIFont.boldSystemFont(ofSize: fontSize)
        for (offset, stroke, fill, strokeWidth) in [
            (CGPoint(x: 0, y: -3), UIColor(hex: "#351332"), UIColor(hex: "#351332"), -13.0),
            (CGPoint.zero, UIColor(hex: "#FFF7E7"), tint.darker(by: 0.34), -8.0),
            (CGPoint.zero, tint.darker(by: 0.28), UIColor(hex: "#FFF9E9"), -2.0)
        ] {
            let label = SKLabelNode()
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: fill, .strokeColor: stroke, .strokeWidth: strokeWidth
            ])
            label.numberOfLines = 2
            label.preferredMaxLayoutWidth = max(60, width)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = offset
            root.addChild(label)
        }
        return root
    }

    static func remove(_ node: SKNode, after duration: TimeInterval) {
        node.run(.sequence([.wait(forDuration: max(0, duration)), .removeFromParent()]),
                 withKey: "ss.effectLifetime")
    }

    /// A stationary local signal is the common Reduce Motion fallback.
    static func quietMark(at point: CGPoint = .zero, tint: UIColor, radius: CGFloat = 14,
                          delay: TimeInterval = 0) -> SKNode {
        let root = SKNode()
        root.position = point
        root.alpha = 0
        let ring = SKShapeNode(circleOfRadius: max(3, radius))
        ring.fillColor = tint.withAlphaComponent(0.10)
        ring.strokeColor = tint.withAlphaComponent(0.7)
        ring.lineWidth = 1.5
        root.addChild(ring)
        root.run(.sequence([.wait(forDuration: max(0, delay)), .fadeIn(withDuration: 0.06),
            .fadeOut(withDuration: 0.20), .removeFromParent()]))
        return root
    }

    static func feedbackFrame(in scene: SKScene) -> CGRect {
        if let game = scene as? GameScene { return game.gameplayLayout.board.insetBy(dx: 12, dy: 12) }
        return scene.frame.insetBy(dx: 20, dy: 32)
    }

    static func feedbackParent(in scene: SKScene) -> SKNode {
        if let game = scene as? GameScene, let world = game.worldNode { return world }
        return scene
    }

    static func cancelFeedback(in scene: SKScene) {
        scene.childNode(withName: "ss.comboPraise")?.removeFromParent()
        feedbackParent(in: scene).children
            .filter { $0.name == "ss.scoreFeedback" || $0.name == "ss.comboPraise" }
            .forEach { $0.removeAllActions(); $0.removeFromParent() }
    }
}
