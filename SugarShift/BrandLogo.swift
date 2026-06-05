import SpriteKit
import UIKit

/// SugarShift wordmark + tagline rendered as an SKNode tree.
/// Reusable across splash, end-of-level cards, share images, etc.
enum BrandLogo {

    /// Builds the wordmark + halo + tagline.
    /// - Parameter size: target font size for the wordmark.
    static func make(fontSize: CGFloat = 56, withTagline: Bool = true) -> SKNode {
        let container = SKNode()

        let pink = UIColor(hex: "#F472B6")
        let mint = UIColor(hex: "#34D399")
        let cream = UIColor(hex: "#FFF7ED")

        // ── Halo (soft glow behind the wordmark)
        let haloW = fontSize * 4.4
        let haloH = fontSize * 1.8
        let halo = SKShapeNode(ellipseOf: CGSize(width: haloW, height: haloH))
        halo.fillColor = UIColor.white.withAlphaComponent(0.18)
        halo.strokeColor = .clear
        halo.glowWidth = 32
        halo.blendMode = .add
        halo.zPosition = -1
        container.addChild(halo)

        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.06, duration: 2.4),
                    .fadeAlpha(to: 0.32, duration: 2.4)]),
            .group([.scale(to: 1.0, duration: 2.4),
                    .fadeAlpha(to: 0.18, duration: 2.4)])
        ])))

        // ── "Sugar" + "Shift" two-tone wordmark
        // Anchor each half so they sit flush against the seam at x=0
        let sugar = makeBrandLabel("Sugar", color: pink, fontSize: fontSize, alignment: .right)
        sugar.position = CGPoint(x: -2, y: 0)
        container.addChild(sugar)

        let shift = makeBrandLabel("Shift", color: mint, fontSize: fontSize, alignment: .left)
        shift.position = CGPoint(x: 2, y: 0)
        container.addChild(shift)

        // Subtle individual letter wobble for dreamy float
        sugar.run(.repeatForever(.sequence([
            .rotate(byAngle:  0.012, duration: 2.0),
            .rotate(byAngle: -0.024, duration: 4.0),
            .rotate(byAngle:  0.012, duration: 2.0)
        ])))
        shift.run(.repeatForever(.sequence([
            .rotate(byAngle: -0.012, duration: 2.0),
            .rotate(byAngle:  0.024, duration: 4.0),
            .rotate(byAngle: -0.012, duration: 2.0)
        ])))

        // ── Sparkle accent above the wordmark seam
        let sparkle = SKLabelNode(text: "✦")
        sparkle.fontName = "AvenirNext-Heavy"
        sparkle.fontSize = fontSize * 0.4
        sparkle.fontColor = cream
        sparkle.verticalAlignmentMode = .center
        sparkle.horizontalAlignmentMode = .center
        sparkle.position = CGPoint(x: 0, y: fontSize * 0.7)
        sparkle.alpha = 0.85
        container.addChild(sparkle)
        sparkle.run(.repeatForever(.sequence([
            .group([.scale(to: 1.25, duration: 0.9), .fadeAlpha(to: 1.0, duration: 0.9)]),
            .group([.scale(to: 0.85, duration: 1.1), .fadeAlpha(to: 0.6, duration: 1.1)])
        ])))

        // ── Tagline
        if withTagline {
            let tagline = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
            tagline.text = String(localized: "sweet match magic")
            tagline.fontSize = fontSize * 0.32
            tagline.fontColor = UIColor.white.withAlphaComponent(0.85)
            tagline.verticalAlignmentMode = .center
            tagline.horizontalAlignmentMode = .center
            tagline.position = CGPoint(x: 0, y: -fontSize * 0.85)
            container.addChild(tagline)

            tagline.run(.repeatForever(.sequence([
                .fadeAlpha(to: 1.0, duration: 1.6),
                .fadeAlpha(to: 0.7, duration: 1.6)
            ])))
        }

        return container
    }

    /// One half of the wordmark, with a soft drop shadow underneath.
    private static func makeBrandLabel(_ text: String,
                                       color: UIColor,
                                       fontSize: CGFloat,
                                       alignment: SKLabelHorizontalAlignmentMode) -> SKNode {
        let group = SKNode()

        // shadow
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = UIColor(white: 0, alpha: 0.18)
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = alignment
        shadow.position = CGPoint(x: 2, y: -3)
        shadow.zPosition = -1
        group.addChild(shadow)

        // main
        let main = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        main.text = text
        main.fontSize = fontSize
        main.fontColor = color
        main.verticalAlignmentMode = .center
        main.horizontalAlignmentMode = alignment
        main.zPosition = 0
        group.addChild(main)

        return group
    }
}
