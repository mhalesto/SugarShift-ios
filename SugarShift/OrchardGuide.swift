import SpriteKit
import UIKit

/// Pip is an original fruit guide assembled from Sugar Shift's own strawberry art.
/// Facial features stay vector-sharp and dialogue stays localized, selectable text.
enum OrchardGuide {
    static func avatar(size: CGFloat) -> SKNode {
        let root = SKNode()
        let body = MenuStyle.art("fruit_strawberry", size: size)
        root.addChild(body)
        for side in [-1.0, 1.0] {
            let eye = SKShapeNode(ellipseOf: CGSize(width: size * 0.14, height: size * 0.18))
            eye.fillColor = .white
            eye.strokeColor = UIColor(hex: "#661B49")
            eye.lineWidth = max(0.5, size * 0.009)
            eye.position = CGPoint(x: size * 0.14 * side, y: size * 0.012)
            eye.zPosition = 2
            let pupil = SKShapeNode(ellipseOf: CGSize(width: size * 0.071, height: size * 0.11))
            pupil.fillColor = UIColor(hex: "#301642")
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: size * 0.013, y: -size * 0.005)
            eye.addChild(pupil)
            let shine = SKShapeNode(circleOfRadius: size * 0.018)
            shine.fillColor = .white
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -size * 0.009, y: size * 0.028)
            pupil.addChild(shine)
            root.addChild(eye)
            let cheek = SKShapeNode(ellipseOf: CGSize(width: size * 0.13, height: size * 0.065))
            cheek.fillColor = UIColor(hex: "#FFABD1").withAlphaComponent(0.78)
            cheek.strokeColor = .clear
            cheek.position = CGPoint(x: size * 0.225 * side, y: -size * 0.1)
            cheek.zPosition = 2
            root.addChild(cheek)
        }
        let smilePath = UIBezierPath()
        smilePath.move(to: CGPoint(x: -size * 0.09, y: -size * 0.115))
        smilePath.addQuadCurve(to: CGPoint(x: size * 0.09, y: -size * 0.115),
                              controlPoint: CGPoint(x: 0, y: -size * 0.25))
        let smile = SKShapeNode(path: smilePath.cgPath)
        smile.strokeColor = UIColor(hex: "#661B49")
        smile.lineWidth = max(1, size * 0.021)
        smile.lineCap = .round
        smile.zPosition = 3
        root.addChild(smile)
        return root
    }

    static func greeting(for world: WorldThemeDefinition) -> String {
        switch world.id {
        case "ice": return String(localized: "Brrr-illiant! Let's bring a little warmth to this frozen wonderland.")
        case "honey": return String(localized: "Follow that golden glow. There's something sweet around every corner!")
        case "volcano": return String(localized: "This valley has a fiery heart. Let's make some spectacular sparks!")
        case "coral": return String(localized: "Dive in with me! A whole ocean of little treasures is waiting.")
        case "cloud": return String(localized: "Clouds below, rainbows above. Our next adventure is sky-high!")
        case "golden": return String(localized: "A golden trail! I wonder what those ancient gardens are hiding.")
        case "firefly": return String(localized: "Shh… the forest is glowing. Let's follow the tiniest lights.")
        case "sahara": return String(localized: "Pack your sense of adventure. These dunes are full of surprises!")
        case "galaxy": return String(localized: "Ready for lift-off? Even the stars want to play!")
        case "sakura": return String(localized: "Make a wish beneath the blossoms. We've come a wonderful long way.")
        default: return String(localized: "I'm Pip! A little curiosity and a clever match can take us anywhere.")
        }
    }

    static func bubble(text: String, width: CGFloat) -> SKNode {
        let root = SKNode()
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: 78), cornerRadius: 22)
        MenuStyle.decorate(panel, size: CGSize(width: width, height: 78))
        root.addChild(panel)
        let pip = avatar(size: 57)
        pip.position = CGPoint(x: -width / 2 + 34, y: -1)
        panel.addChild(pip)
        let name = GameSurface.label(String(localized: "Pip"), size: 10, color: MenuStyle.pink)
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -width / 2 + 70, y: 23)
        panel.addChild(name)
        let label = GameSurface.label(text, size: 11.5, color: MenuStyle.ink)
        label.fontName = "AvenirNext-DemiBold"
        label.numberOfLines = 3
        label.preferredMaxLayoutWidth = max(60, width - 87)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: name.position.x, y: -6)
        panel.addChild(label)
        root.isAccessibilityElement = true
        root.accessibilityLabel = String(localized: "Pip") + ": " + text
        return root
    }

    static func lines(for world: WorldThemeDefinition) -> [String] {
        [greeting(for: world),
         String(localized: "Your goals are on the card above the board. Every thoughtful match brings them closer."),
         String(localized: "Try matching four or more fruits, then bring two power-ups together. I'll be cheering for you!")]
    }
}

final class GuideDialogueCard: SKNode {
    var onClose: (() -> Void)?
    private let lines: [String]
    private var index = 0
    private let dialogue = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let counter = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var nextButton: SKShapeNode!

    init(sceneSize: CGSize, title: String, lines: [String]) {
        self.lines = lines.isEmpty ? [String(localized: "Let's make something wonderful!")] : lines
        super.init()
        zPosition = 1550
        let scrim = SKSpriteNode(color: UIColor(hex: "#1B0C36").withAlphaComponent(0.6), size: sceneSize)
        addChild(scrim)
        let width = min(352, sceneSize.width - 32)
        let height = min(380, sceneSize.height - 110)
        let card = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 27)
        MenuStyle.decorate(card, size: CGSize(width: width, height: height))
        card.zPosition = 1
        addChild(card)
        let avatar = OrchardGuide.avatar(size: 100)
        avatar.position.y = height / 2 - 47
        card.addChild(avatar)
        MenuStyle.float(avatar, distance: 3)
        let heading = GameSurface.label(title, size: 21, color: MenuStyle.ink)
        heading.position.y = height / 2 - 117
        if heading.frame.width > width - 32 { heading.setScale((width - 32) / heading.frame.width) }
        card.addChild(heading)
        dialogue.fontColor = MenuStyle.ink
        dialogue.fontSize = 16
        dialogue.numberOfLines = 4
        dialogue.preferredMaxLayoutWidth = width - 42
        dialogue.verticalAlignmentMode = .center
        dialogue.position.y = -8
        card.addChild(dialogue)
        counter.fontColor = MenuStyle.muted
        counter.fontSize = 11
        counter.position.y = -height / 2 + 106
        card.addChild(counter)
        nextButton = MenuStyle.button(String(localized: "Continue"), name: "guideNext",
                                     size: CGSize(width: width - 52, height: 48))
        nextButton.position.y = -height / 2 + 71
        card.addChild(nextButton)
        let skip = MenuStyle.button(String(localized: "Skip chat"), name: "guideSkip",
                                   size: CGSize(width: 126, height: 36), tone: .cream)
        skip.position.y = -height / 2 + 25
        card.addChild(skip)
        refresh()
        MenuStyle.enter(card)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func handleTap(at point: CGPoint) {
        var hit: SKNode? = atPoint(convert(point, from: parent ?? self))
        while let node = hit {
            if node.name == "guideSkip" { finish(); return }
            if node.name == "guideNext" {
                if index + 1 < lines.count { index += 1; refresh(); Effects.haptic(.soft) }
                else { finish() }
                return
            }
            hit = node.parent
        }
    }

    private func refresh() {
        dialogue.text = lines[index]
        dialogue.isAccessibilityElement = true
        dialogue.accessibilityLabel = String(localized: "Pip") + ": " + lines[index]
        counter.text = "\(index + 1) / \(lines.count)"
        let title = index == lines.count - 1 ? String(localized: "Let's play!") : String(localized: "Continue")
        (nextButton.children.first { $0 is SKLabelNode } as? SKLabelNode)?.text = title
        nextButton.accessibilityLabel = title
        UIAccessibility.post(notification: .announcement, argument: lines[index])
    }

    private func finish() {
        let action = onClose
        onClose = nil
        removeFromParent()
        action?()
    }
}
