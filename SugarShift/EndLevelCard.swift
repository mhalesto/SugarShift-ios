import SpriteKit
import UIKit

/// Centred glass overlay shown at end of level (win or lose). Animates in,
/// reports back which button was tapped via the closures.
final class EndLevelCard: SKNode {

    enum Outcome {
        case win(stars: Int, score: Int, target: Int)
        case lose(score: Int, target: Int)
    }

    var onPrimary: (() -> Void)?  // "Next Level" or "Retry"
    var onSecondary: (() -> Void)? // "Levels"  (placeholder for now)

    private let outcome: Outcome
    private let cardSize: CGSize

    init(outcome: Outcome, sceneSize: CGSize) {
        self.outcome = outcome
        self.cardSize = CGSize(width: min(sceneSize.width - 40, 320), height: 360)
        super.init()
        self.zPosition = 2000
        build(sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func build(sceneSize: CGSize) {
        // Dimming scrim covering the entire scene (full-screen tap-blocker)
        let scrim = SKShapeNode(rectOf: sceneSize)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        scrim.position = .zero
        scrim.zPosition = 0
        scrim.name = "endLevelScrim"
        addChild(scrim)
        scrim.alpha = 0
        scrim.run(.fadeAlpha(to: 1.0, duration: 0.25))

        // Card background
        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.95)
        card.strokeColor = UIColor(white: 1, alpha: 0.6)
        card.lineWidth = 1
        card.position = .zero
        card.zPosition = 1
        card.alpha = 0
        card.setScale(0.5)
        addChild(card)

        // Title
        let isWin: Bool = {
            if case .win = outcome { return true }
            return false
        }()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = isWin ? "Level complete!" : "Out of moves"
        title.fontSize = 22
        title.fontColor = isWin ? UIColor(hex: "#10B981") : UIColor(hex: "#EF4444")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: cardSize.height / 2 - 38)
        card.addChild(title)

        // Stars (3 slots, lit based on outcome)
        let starCount: Int = {
            if case .win(let s, _, _) = outcome { return s }
            return 0
        }()
        addStars(to: card, lit: starCount, y: cardSize.height / 2 - 110)

        // Score / target
        let scoreLine = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        scoreLine.fontSize = 32
        scoreLine.fontColor = UIColor(hex: "#0F172A")
        scoreLine.verticalAlignmentMode = .center
        scoreLine.horizontalAlignmentMode = .center
        scoreLine.position = CGPoint(x: 0, y: 0)
        switch outcome {
        case .win(_, let score, _), .lose(let score, _):
            scoreLine.text = "\(score)"
        }
        card.addChild(scoreLine)

        let targetLine = SKLabelNode(fontNamed: "AvenirNext-Medium")
        targetLine.fontSize = 13
        targetLine.fontColor = UIColor(hex: "#475569")
        targetLine.verticalAlignmentMode = .center
        targetLine.horizontalAlignmentMode = .center
        switch outcome {
        case .win(_, _, let target), .lose(_, let target):
            targetLine.text = "Target  \(target)"
        }
        targetLine.position = CGPoint(x: 0, y: -28)
        card.addChild(targetLine)

        // Primary button (Next / Retry)
        let primary = makeButton(text: isWin ? "Next Level" : "Retry",
                                 fill: UIColor(hex: "#F472B6"),
                                 textColor: .white,
                                 width: cardSize.width - 56,
                                 height: 50,
                                 name: "primaryBtn")
        primary.position = CGPoint(x: 0, y: -cardSize.height / 2 + 90)
        card.addChild(primary)

        let secondary = makeButton(text: "Choose level",
                                   fill: UIColor(white: 0, alpha: 0.06),
                                   textColor: UIColor(hex: "#0F172A"),
                                   width: cardSize.width - 56,
                                   height: 42,
                                   name: "secondaryBtn")
        secondary.position = CGPoint(x: 0, y: -cardSize.height / 2 + 36)
        card.addChild(secondary)

        // Spring entrance
        card.run(.group([
            .fadeIn(withDuration: 0.18),
            .sequence([
                .scale(to: 1.05, duration: 0.22),
                .scale(to: 1.0, duration: 0.12)
            ])
        ]))

        // Confetti for wins with stars
        if isWin, starCount > 0 {
            let confetti = Effects.makeConfetti(width: cardSize.width)
            confetti.position = CGPoint(x: 0, y: cardSize.height / 2 + 8)
            card.addChild(confetti)
            confetti.run(.sequence([.wait(forDuration: 2.4), .removeFromParent()]))
        }
    }

    private func addStars(to parent: SKNode, lit: Int, y: CGFloat) {
        let spacing: CGFloat = 64
        for i in 0..<3 {
            let x = -spacing + CGFloat(i) * spacing
            let isLit = i < lit
            let star = makeStar(litFill: isLit, size: 44)
            star.position = CGPoint(x: x, y: y)
            parent.addChild(star)
            if isLit {
                // Stagger the pop-in
                star.alpha = 0
                star.setScale(0.3)
                star.run(.sequence([
                    .wait(forDuration: 0.3 + Double(i) * 0.18),
                    .group([
                        .fadeIn(withDuration: 0.2),
                        .sequence([
                            .scale(to: 1.25, duration: 0.18),
                            .scale(to: 1.0, duration: 0.12)
                        ])
                    ])
                ]))
            }
        }
    }

    private func makeStar(litFill: Bool, size: CGFloat) -> SKNode {
        let node = SKNode()
        let path = starPath(size: size)
        let body = SKShapeNode(path: path)
        body.fillColor = litFill ? UIColor(hex: "#FBBF24") : UIColor(white: 0, alpha: 0.1)
        body.strokeColor = litFill ? UIColor(hex: "#B45309") : UIColor(white: 0, alpha: 0.2)
        body.lineWidth = 1
        node.addChild(body)
        if litFill {
            let glow = SKShapeNode(circleOfRadius: size * 0.65)
            glow.fillColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.5)
            glow.strokeColor = .clear
            glow.glowWidth = 8
            glow.blendMode = .add
            glow.zPosition = -1
            node.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .group([.scale(to: 1.15, duration: 1.2),
                        .fadeAlpha(to: 0.7, duration: 1.2)]),
                .group([.scale(to: 1.0, duration: 1.2),
                        .fadeAlpha(to: 0.4, duration: 1.2)])
            ])))
        }
        return node
    }

    private func starPath(size: CGFloat) -> CGPath {
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
        return p.cgPath
    }

    private func makeButton(text: String, fill: UIColor, textColor: UIColor,
                            width: CGFloat, height: CGFloat, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        btn.fillColor = fill
        btn.strokeColor = .clear
        btn.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = textColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    /// Hit-test a tap point (in scene coords) and fire the matching callback.
    func handleTap(at scenePoint: CGPoint) -> Bool {
        let local = self.convert(scenePoint, from: self.parent ?? self)
        var n: SKNode? = atPoint(local)
        while let node = n {
            if node.name == "primaryBtn" {
                bounce(node)
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onPrimary?()
                }]))
                return true
            }
            if node.name == "secondaryBtn" {
                bounce(node)
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onSecondary?()
                }]))
                return true
            }
            n = node.parent
        }
        return true   // swallow taps that hit the scrim/card
    }

    func dismiss(_ completion: (() -> Void)? = nil) {
        run(.sequence([
            .group([.scale(to: 0.4, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent(),
            .run { completion?() }
        ]))
    }

    private func bounce(_ node: SKNode) {
        node.run(.sequence([
            .scale(to: 0.94, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
    }
}
