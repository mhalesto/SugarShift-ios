import SpriteKit
import UIKit

/// Menu-only art direction. Gameplay's approved footer never uses this helper.
enum MenuStyle {
    enum Tone { case cream, glass, berry, mint, gold }
    static let ink = UIColor(hex: "#3A154F")
    static let muted = UIColor(hex: "#806580")
    static let pink = UIColor(hex: "#EF328C")

    static func decorate(_ node: SKShapeNode, size: CGSize, tone: Tone = .cream) {
        node.childNode(withName: "menuSurface")?.removeFromParent()
        node.fillColor = .clear
        node.strokeColor = .clear
        let colors: (String, String, String)
        switch tone {
        case .cream: colors = ("#FFF9EB", "#F8DBE6", "#FFFDF5")
        case .glass: colors = ("#3F467D", "#1B224B", "#B3E8FF")
        case .berry: colors = ("#FF9BD4", "#DF247D", "#FFE9A9")
        case .mint: colors = ("#D8FFD9", "#69BFA2", "#FFF2BB")
        case .gold: colors = ("#FFF6B2", "#FFC44C", "#FFFBE0")
        }
        let surface = GameSurface.panel(size: size, top: UIColor(hex: colors.0),
            bottom: UIColor(hex: colors.1), radius: min(27, size.height * 0.28),
            rim: UIColor(hex: colors.2))
        surface.name = "menuSurface"
        surface.zPosition = -0.5
        node.addChild(surface)
    }

    @discardableResult
    static func backdrop(in scene: SKScene, world: WorldThemeDefinition? = nil) -> SKNode {
        scene.childNode(withName: "menuBackdrop")?.removeFromParent()
        let theme = world ?? WorldThemes.theme(for: max(1, min(Levels.count, Persistence.currentLevel)))
        let root = SKNode()
        root.name = "menuBackdrop"
        root.zPosition = -100
        let texture = GameArt.texture(theme.backgroundAsset) ?? GameArt.texture("world_candy_background")
        let image = SKSpriteNode(texture: texture)
        if let texture {
            let source = texture.size()
            let scale = max(scene.size.width / max(1, source.width), scene.size.height / max(1, source.height))
            image.size = CGSize(width: source.width * scale, height: source.height * scale)
        }
        root.addChild(image)
        let veil = SKSpriteNode(color: UIColor(hex: "#190E3C").withAlphaComponent(0.26), size: scene.size)
        veil.zPosition = 1
        root.addChild(veil)
        scene.addChild(root)
        return root
    }

    static func art(_ name: String, size: CGFloat) -> SKSpriteNode {
        GameArt.boardSprite(name, fitting: CGSize(width: size, height: size))
    }

    static func enter(_ node: SKNode) {
        node.removeAction(forKey: "menuEntrance")
        node.alpha = 0
        guard !Persistence.reduceMotion else {
            node.run(.fadeIn(withDuration: 0.16), withKey: "menuEntrance")
            return
        }
        node.setScale(0.94)
        let settle = SKAction.scale(to: 1, duration: 0.28)
        settle.timingMode = .easeOut
        node.run(.group([.fadeIn(withDuration: 0.2), settle]), withKey: "menuEntrance")
    }

    static func button(_ title: String, name: String, size: CGSize, tone: Tone = .berry) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: min(24, size.height / 2))
        node.name = name
        decorate(node, size: size, tone: tone)
        let label = GameSurface.label(title, size: min(24, size.height * 0.39),
                                      color: tone == .cream || tone == .gold ? ink : .white)
        if label.frame.width > size.width - 24 { label.setScale((size.width - 24) / label.frame.width) }
        label.zPosition = 1
        node.addChild(label)
        node.isAccessibilityElement = true
        node.accessibilityLabel = title
        node.accessibilityTraits = .button
        return node
    }

    static func float(_ node: SKNode, distance: CGFloat = 5, delay: TimeInterval = 0) {
        guard !Persistence.reduceMotion else { return }
        let up = SKAction.moveBy(x: 0, y: distance, duration: 2.2)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        node.run(.sequence([.wait(forDuration: delay), .repeatForever(.sequence([up, down]))]), withKey: "menuFloat")
    }
}
