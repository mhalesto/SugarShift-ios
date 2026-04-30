import SpriteKit
import UIKit

/// Functional settings overlay. Toggles for sound/music/haptics/reduce-motion
/// (persisted via Persistence), plus Restart Level and Reset Progress actions.
final class SettingsCard: SKNode {

    enum Action {
        case restartLevel
        case resetProgress
        case close
    }

    var onAction: ((Action) -> Void)?

    private let cardSize: CGSize
    private var rows: [(key: String, node: SKShapeNode, knob: SKShapeNode, isOn: Bool)] = []

    init(sceneSize: CGSize) {
        cardSize = CGSize(width: min(sceneSize.width - 32, 340), height: 510)
        super.init()
        zPosition = 1500
        build(sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func build(sceneSize: CGSize) {
        // Scrim
        let scrim = SKShapeNode(rectOf: sceneSize)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        scrim.zPosition = 0
        scrim.name = "settingsScrim"
        scrim.alpha = 0
        addChild(scrim)
        scrim.run(.fadeAlpha(to: 1.0, duration: 0.18))

        // Card
        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 24)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.6)
        card.lineWidth = 1
        card.zPosition = 1
        card.alpha = 0
        card.setScale(0.7)
        addChild(card)
        card.run(.group([.fadeIn(withDuration: 0.18),
                         .scale(to: 1.0, duration: 0.22)]))

        // Header
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "Settings"
        title.fontSize = 26
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: cardSize.height / 2 - 32)
        card.addChild(title)

        let divider = SKShapeNode(rectOf: CGSize(width: cardSize.width - 40, height: 1))
        divider.fillColor = UIColor(white: 0, alpha: 0.08)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: cardSize.height / 2 - 60)
        card.addChild(divider)

        // Toggles
        var y = cardSize.height / 2 - 100
        addToggleRow(card: card, key: "sound",
                     title: "Sound effects", emoji: "🔊",
                     initialOn: Persistence.soundEnabled, atY: y)
        y -= 56
        addToggleRow(card: card, key: "music",
                     title: "Music", emoji: "🎵",
                     initialOn: Persistence.musicEnabled, atY: y)
        y -= 56
        addToggleRow(card: card, key: "haptics",
                     title: "Haptics", emoji: "📳",
                     initialOn: Persistence.hapticsEnabled, atY: y)
        y -= 56
        addToggleRow(card: card, key: "reduceMotion",
                     title: "Reduce motion", emoji: "🌀",
                     initialOn: Persistence.reduceMotion, atY: y)

        // Divider before actions
        y -= 26
        let div2 = SKShapeNode(rectOf: CGSize(width: cardSize.width - 40, height: 1))
        div2.fillColor = UIColor(white: 0, alpha: 0.08)
        div2.strokeColor = .clear
        div2.position = CGPoint(x: 0, y: y)
        card.addChild(div2)

        // Action buttons
        y -= 32
        addActionRow(card: card,
                     name: "settingsAction:restart",
                     title: "Restart Level",
                     iconEmoji: "↻",
                     fill: UIColor(hex: "#F472B6"),
                     textColor: .white,
                     atY: y)

        y -= 56
        addActionRow(card: card,
                     name: "settingsAction:reset",
                     title: "Reset Progress",
                     iconEmoji: "🗑",
                     fill: UIColor(hex: "#FEE2E2"),
                     textColor: UIColor(hex: "#B91C1C"),
                     atY: y)

        // Footer — version + close
        let infoText = "SugarShift  v\(appVersion()) (build \(appBuild()))"
        let info = SKLabelNode(fontNamed: "AvenirNext-Medium")
        info.text = infoText
        info.fontSize = 11
        info.fontColor = UIColor(white: 0, alpha: 0.45)
        info.verticalAlignmentMode = .center
        info.horizontalAlignmentMode = .center
        info.position = CGPoint(x: 0, y: -cardSize.height / 2 + 50)
        card.addChild(info)

        let close = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        close.text = "Close"
        close.fontSize = 14
        close.fontColor = UIColor(hex: "#475569")
        close.verticalAlignmentMode = .center
        close.horizontalAlignmentMode = .center
        close.position = CGPoint(x: 0, y: -cardSize.height / 2 + 24)
        close.name = "settingsClose"
        card.addChild(close)
    }

    // MARK: - Rows

    private func addToggleRow(card: SKNode, key: String, title: String,
                              emoji: String, initialOn: Bool, atY y: CGFloat) {
        let rowW = cardSize.width - 32
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: 48), cornerRadius: 14)
        row.fillColor = UIColor(white: 0, alpha: 0.04)
        row.strokeColor = UIColor(white: 0, alpha: 0.06)
        row.lineWidth = 1
        row.position = CGPoint(x: 0, y: y)
        card.addChild(row)

        // Emoji icon
        let icon = SKLabelNode(text: emoji)
        icon.fontSize = 22
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: -rowW / 2 + 28, y: 0)
        row.addChild(icon)

        // Title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        titleLabel.text = title
        titleLabel.fontSize = 15
        titleLabel.fontColor = UIColor(hex: "#0F172A")
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -rowW / 2 + 56, y: 0)
        row.addChild(titleLabel)

        // Toggle pill
        let pillW: CGFloat = 50
        let pillH: CGFloat = 30
        let pill = SKShapeNode(rectOf: CGSize(width: pillW, height: pillH), cornerRadius: pillH / 2)
        pill.fillColor = initialOn ? UIColor(hex: "#10B981") : UIColor(white: 0, alpha: 0.18)
        pill.strokeColor = .clear
        pill.position = CGPoint(x: rowW / 2 - 12 - pillW / 2, y: 0)
        pill.name = "settingsToggle:\(key)"
        row.addChild(pill)

        let knob = SKShapeNode(circleOfRadius: 12)
        knob.fillColor = .white
        knob.strokeColor = UIColor(white: 0, alpha: 0.18)
        knob.lineWidth = 1
        knob.position = CGPoint(x: initialOn ? pillW / 2 - 14 : -pillW / 2 + 14, y: 0)
        pill.addChild(knob)

        rows.append((key, pill, knob, initialOn))
    }

    private func addActionRow(card: SKNode, name: String, title: String,
                              iconEmoji: String, fill: UIColor,
                              textColor: UIColor, atY y: CGFloat) {
        let btnW = cardSize.width - 64
        let btnH: CGFloat = 46
        let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        btn.fillColor = fill
        btn.strokeColor = .clear
        btn.position = CGPoint(x: 0, y: y)
        btn.name = name
        card.addChild(btn)

        let icon = SKLabelNode(text: iconEmoji)
        icon.fontSize = 18
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: -btnW / 2 + 26, y: 0)
        btn.addChild(icon)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 15
        label.fontColor = textColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 8, y: 0)
        btn.addChild(label)
    }

    // MARK: - Tap handling

    func handleTap(at scenePoint: CGPoint) -> Bool {
        let local = self.convert(scenePoint, from: self.parent ?? self)
        var n: SKNode? = atPoint(local)
        while let node = n {
            if node.name == "settingsClose" || node.name == "settingsScrim" {
                onAction?(.close)
                return true
            }
            if let name = node.name, name.hasPrefix("settingsToggle:") {
                let key = String(name.dropFirst("settingsToggle:".count))
                bounce(node)
                toggle(key: key)
                return true
            }
            if node.name == "settingsAction:restart" {
                bounce(node)
                onAction?(.restartLevel)
                return true
            }
            if node.name == "settingsAction:reset" {
                bounce(node)
                onAction?(.resetProgress)
                return true
            }
            n = node.parent
        }
        return true
    }

    private func toggle(key: String) {
        guard let idx = rows.firstIndex(where: { $0.key == key }) else { return }
        let newValue = !rows[idx].isOn
        rows[idx].isOn = newValue

        // Animate the pill colour + knob position
        let pill = rows[idx].node
        pill.run(.colorize(with: newValue ? UIColor(hex: "#10B981") : UIColor(white: 0, alpha: 0.18),
                           colorBlendFactor: 1.0, duration: 0.14))
        pill.fillColor = newValue ? UIColor(hex: "#10B981") : UIColor(white: 0, alpha: 0.18)

        let knob = rows[idx].knob
        let pillW: CGFloat = 50
        let targetX: CGFloat = newValue ? pillW / 2 - 14 : -pillW / 2 + 14
        knob.run(.move(to: CGPoint(x: targetX, y: 0), duration: 0.14))

        // Persist + react
        switch key {
        case "sound":
            Persistence.soundEnabled = newValue
            if newValue { Audio.shared.play(.tap) }
        case "music":
            Persistence.musicEnabled = newValue
            if newValue { Audio.shared.startMusic() } else { Audio.shared.stopMusic() }
        case "haptics":
            Persistence.hapticsEnabled = newValue
        case "reduceMotion":
            Persistence.reduceMotion = newValue
        default: break
        }

        // Light haptic feedback if haptics still enabled
        Effects.haptic(.light)
    }

    // MARK: - Lifecycle

    func dismiss(_ completion: (() -> Void)? = nil) {
        run(.sequence([
            .group([.scale(to: 0.4, duration: 0.16),
                    .fadeOut(withDuration: 0.16)]),
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

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private func appBuild() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
