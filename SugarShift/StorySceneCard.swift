import SpriteKit
import UIKit

/// One self-contained dialogue overlay. The host owns what happens after the
/// opening (enter gameplay) or an explicit replay (return to its calling page).
final class StorySceneCard: SKNode {
    var onComplete: (() -> Void)?

    private var presentation: StoryPresentation
    private let store: StoryStore
    private let cardSize: CGSize
    private let card = SKShapeNode()
    private let content = SKNode()
    private var finished = false
    private var allowsMotion: Bool {
        !Persistence.reduceMotion && !UIAccessibility.isReduceMotionEnabled
    }

    init(presentation: StoryPresentation, sceneSize: CGSize,
         safeAreaInsets: UIEdgeInsets = .zero, store: StoryStore = .shared) {
        self.presentation = presentation
        self.store = store
        cardSize = CGSize(
            width: min(364, max(1, sceneSize.width - safeAreaInsets.left - safeAreaInsets.right - 24)),
            height: min(620, max(1, sceneSize.height - safeAreaInsets.top - safeAreaInsets.bottom - 24)))
        super.init()
        zPosition = 1900
        name = "storySceneCard"
        accessibilityViewIsModal = true

        let scrim = SKSpriteNode(color: UIColor(hex: "#21142E").withAlphaComponent(0.72), size: sceneSize)
        addChild(scrim)
        card.path = CGPath(roundedRect: CGRect(x: -cardSize.width / 2, y: -cardSize.height / 2,
            width: cardSize.width, height: cardSize.height), cornerWidth: 26, cornerHeight: 26, transform: nil)
        card.position = CGPoint(x: (safeAreaInsets.left - safeAreaInsets.right) / 2,
                                y: (safeAreaInsets.bottom - safeAreaInsets.top) / 2)
        card.zPosition = 1
        MenuStyle.decorate(card, size: cardSize)
        addChild(card)
        card.addChild(content)
        renderBeat()
        if allowsMotion { MenuStyle.enter(card) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Scene-coordinate taps are always consumed while the card is present.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard !finished else { return true }
        var hit: SKNode? = atPoint(convert(point, from: parent ?? self))
        while let node = hit {
            if let name = node.name,
               name == "storyContinue" || name == "storySkip" || name.hasPrefix("storyChoice:") {
                activate(name)
                return true
            }
            hit = node.parent
        }
        return true
    }

    private func activate(_ name: String) {
        guard !finished else { return }
        if name == "storySkip" {
            store.skip(presentation)
            complete()
            return
        }
        let choiceID = name.hasPrefix("storyChoice:") ? String(name.dropFirst("storyChoice:".count)) : nil
        switch store.advance(&presentation, choosing: choiceID) {
        case .advanced: renderBeat()
        case .completed: complete()
        case .invalid: break
        }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        let action = onComplete
        onComplete = nil
        removeAllActions()
        removeFromParent()
        action?()
    }

    private func renderBeat() {
        content.removeAllChildren()
        guard let beat = presentation.currentBeat else { return }
        let top = cardSize.height / 2
        let bottom = -top
        let inset: CGFloat = 18
        let width = cardSize.width - inset * 2

        let heading = label(presentation.scene.title, size: 18, color: MenuStyle.ink)
        heading.horizontalAlignmentMode = .left
        heading.position = CGPoint(x: -width / 2, y: top - 24)
        fit(heading, within: CGSize(width: max(60, width - 75), height: 25), minimumSize: 13)
        content.addChild(heading)
        let setting = label(presentation.isReplay ? String(localized: "Replay") : String(localized: "At home"),
                            size: 10.5, color: MenuStyle.muted)
        setting.horizontalAlignmentMode = .right
        setting.position = CGPoint(x: width / 2, y: top - 24)
        fit(setting, within: CGSize(width: 65, height: 20), minimumSize: 9)
        content.addChild(setting)

        // Decorative scenery yields space first. The two real choice buttons,
        // the skip control, and the full dialogue retain their own regions.
        let actionCount = max(1, beat.choices.count)
        let actionHeight: CGFloat = 44
        let actionStep: CGFloat = 54
        let actionTop = bottom + 58 + CGFloat(actionCount) * actionStep
        let stageHeight = min(192, max(70, cardSize.height - 356 - CGFloat(max(0, actionCount - 1)) * 24))
        let stageSize = CGSize(width: cardSize.width - 24, height: stageHeight)
        let stage = makeHomeStage(size: stageSize, beat: beat)
        stage.position.y = top - 49 - stageHeight / 2
        content.addChild(stage)
        let stageBottom = stage.position.y - stageHeight / 2

        let speaker = CharacterCatalog.definition(for: beat.dialogue.speakerID)
        let speakerName = label(speaker?.displayName ?? "", size: 19, color: MenuStyle.ink)
        speakerName.position.y = stageBottom - 22
        fit(speakerName, within: CGSize(width: width, height: 28), minimumSize: 14)
        content.addChild(speakerName)

        let dialogueTop = stageBottom - 42
        let dialogueBottom = actionTop + 7
        let dialogueHeight = max(28, dialogueTop - dialogueBottom)
        let dialogueBox = SKShapeNode(rectOf: CGSize(width: width, height: dialogueHeight), cornerRadius: 16)
        dialogueBox.fillColor = UIColor.white.withAlphaComponent(Persistence.highContrast ? 0.96 : 0.55)
        dialogueBox.strokeColor = UIColor(hex: "#D6A5AF").withAlphaComponent(0.38)
        dialogueBox.lineWidth = 1
        dialogueBox.position.y = (dialogueTop + dialogueBottom) / 2
        content.addChild(dialogueBox)

        let dialogue = label(beat.dialogue.text, size: Persistence.largeText ? 19 : 17, color: MenuStyle.ink)
        dialogue.fontName = "AvenirNext-DemiBold"
        dialogue.numberOfLines = 0
        dialogue.preferredMaxLayoutWidth = max(40, width - 24)
        fit(dialogue, within: CGSize(width: width - 24, height: max(20, dialogueHeight - 14)), minimumSize: 12.5)
        dialogueBox.addChild(dialogue)
        dialogue.isAccessibilityElement = true
        dialogue.accessibilityLabel = "\(speaker?.displayName ?? ""): \(beat.dialogue.text)"
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .screenChanged, argument: dialogue)
        }

        if beat.choices.isEmpty {
            let title = beat.isTerminal
                ? (presentation.isReplay ? String(localized: "Finish replay") : String(localized: "Let's play!"))
                : String(localized: "Continue")
            let next = button(title, name: "storyContinue", width: width, height: actionHeight, tone: .berry)
            next.position.y = bottom + 85
            content.addChild(next)
        } else {
            for (index, choice) in beat.choices.enumerated() {
                let choiceButton = button(choice.title, name: "storyChoice:\(choice.id)",
                                          width: width, height: actionHeight,
                                          tone: index == 0 ? .berry : .gold)
                choiceButton.position.y = bottom + 85 + CGFloat(beat.choices.count - 1 - index) * actionStep
                content.addChild(choiceButton)
            }
        }
        let skip = button(presentation.isReplay ? String(localized: "Close replay") : String(localized: "Skip story"),
                          name: "storySkip", width: min(150, width), height: 36, tone: .cream)
        skip.position.y = bottom + 29
        content.addChild(skip)

        if allowsMotion {
            stage.alpha = 0
            stage.run(.fadeIn(withDuration: 0.18))
        }
        UIAccessibility.post(notification: .announcement, argument: dialogue.accessibilityLabel)
    }

    private func button(_ text: String, name: String, width: CGFloat,
                        height: CGFloat, tone: MenuStyle.Tone) -> SKShapeNode {
        let node = StoryActionButton(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        node.name = name
        MenuStyle.decorate(node, size: CGSize(width: width, height: height), tone: tone)
        let title = label(text, size: 15, color: tone == .berry ? .white : MenuStyle.ink)
        fit(title, within: CGSize(width: width - 26, height: height - 10), minimumSize: 12)
        node.addChild(title)
        node.isAccessibilityElement = true
        node.accessibilityLabel = text
        node.accessibilityTraits = .button
        node.onActivate = { [weak self] in self?.activate(name) }
        return node
    }

    private func label(_ text: String, size: CGFloat, color: UIColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }

    private func fit(_ node: SKLabelNode, within size: CGSize, minimumSize: CGFloat) {
        while (node.frame.width > size.width || node.frame.height > size.height), node.fontSize > minimumSize {
            node.fontSize = max(minimumSize, node.fontSize - 0.5)
        }
    }

    // MARK: - A small home stage, with the actual memory box and unfolded map

    private func makeHomeStage(size: CGSize, beat: StoryBeat) -> SKNode {
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: size, cornerRadius: 19)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        let wall = SKSpriteNode(color: UIColor(hex: "#EBC9A9"), size: size)
        crop.addChild(wall)
        let floor = SKSpriteNode(color: UIColor(hex: "#B58069"), size: CGSize(width: size.width, height: size.height * 0.3))
        floor.position.y = -size.height * 0.35
        crop.addChild(floor)
        let rail = SKSpriteNode(color: UIColor(hex: "#FFF1D4"), size: CGSize(width: size.width, height: 5))
        rail.position.y = -size.height * 0.2
        crop.addChild(rail)

        let windowSize = CGSize(width: size.width * 0.3, height: size.height * 0.66)
        let window = SKShapeNode(rectOf: windowSize, cornerRadius: 14)
        window.fillColor = UIColor(hex: "#C7E8D5")
        window.strokeColor = UIColor(hex: "#FFF0D4")
        window.lineWidth = 6
        window.position = CGPoint(x: -size.width * 0.28, y: size.height * 0.12)
        crop.addChild(window)
        let windowCrop = SKCropNode()
        let windowMask = SKShapeNode(rectOf: CGSize(width: windowSize.width - 6, height: windowSize.height - 6), cornerRadius: 11)
        windowMask.fillColor = .white
        windowMask.strokeColor = .clear
        windowCrop.maskNode = windowMask
        if let texture = GameArt.texture("world_candy_background") {
            let background = SKSpriteNode(texture: texture)
            let scale = max(windowSize.width / texture.size().width, windowSize.height / texture.size().height)
            background.size = CGSize(width: texture.size().width * scale, height: texture.size().height * scale)
            windowCrop.addChild(background)
        }
        window.addChild(windowCrop)
        let mullion = SKSpriteNode(color: UIColor(hex: "#FFF0D4"), size: CGSize(width: 4, height: windowSize.height))
        window.addChild(mullion)

        let picture = SKShapeNode(rectOf: CGSize(width: size.width * 0.14, height: size.height * 0.28), cornerRadius: 5)
        picture.fillColor = UIColor(hex: "#FFEED3")
        picture.strokeColor = UIColor(hex: "#AE7157")
        picture.lineWidth = 4
        picture.position = CGPoint(x: size.width * 0.32, y: size.height * 0.25)
        picture.addChild(MenuStyle.art("fruit_strawberry", size: min(size.height * 0.2, size.width * 0.1)))
        crop.addChild(picture)

        let characters = beat.characterIDs.compactMap { CharacterCatalog.definition(for: $0) }
        let portraitSize = min(137, size.height * 0.9, size.width / CGFloat(max(1, characters.count)) * 1.04)
        for (index, character) in characters.enumerated() {
            let x = (CGFloat(index) - CGFloat(characters.count - 1) / 2) * size.width * (characters.count > 2 ? 0.3 : 0.5)
            let speaking = character.id == beat.dialogue.speakerID
            let portrait = CharacterPortrait.make(character: character,
                expression: speaking ? beat.dialogue.expression : .warm,
                size: portraitSize * (character.role == .player ? 0.84 : 1), avatar: store.avatar)
            portrait.position = CGPoint(x: x, y: -size.height * 0.015)
            portrait.alpha = speaking ? 1 : 0.92
            crop.addChild(portrait)
        }

        let table = SKShapeNode(rectOf: CGSize(width: size.width * 0.84, height: max(7, size.height * 0.06)), cornerRadius: 5)
        table.fillColor = UIColor(hex: "#885846")
        table.strokeColor = UIColor(hex: "#EBC093")
        table.lineWidth = 2
        table.position.y = -size.height * 0.37
        crop.addChild(table)
        let prop = makeMemoryBox(showMap: beat.propID == "orchard-map")
        prop.setScale(min(1, size.width / 290, size.height / 170))
        prop.position = CGPoint(x: 0, y: -size.height * 0.3)
        crop.addChild(prop)
        return crop
    }

    private func makeMemoryBox(showMap: Bool) -> SKNode {
        let root = SKNode()
        let box = SKShapeNode(rectOf: CGSize(width: 79, height: 25), cornerRadius: 5)
        box.fillColor = UIColor(hex: "#A76149")
        box.strokeColor = UIColor(hex: "#F5CE83")
        box.lineWidth = 2
        root.addChild(box)
        let lid = SKShapeNode(rectOf: CGSize(width: 84, height: 17), cornerRadius: 5)
        lid.fillColor = UIColor(hex: "#BE7D57")
        lid.strokeColor = UIColor(hex: "#F5CE83")
        lid.lineWidth = 2
        lid.position.y = 17
        lid.zRotation = showMap ? 0.12 : 0
        root.addChild(lid)
        let clasp = SKShapeNode(rectOf: CGSize(width: 10, height: 13), cornerRadius: 3)
        clasp.fillColor = UIColor(hex: "#F8D585")
        clasp.strokeColor = UIColor(hex: "#865244")
        root.addChild(clasp)

        if showMap {
            let map = SKShapeNode(rectOf: CGSize(width: 110, height: 55), cornerRadius: 7)
            map.fillColor = UIColor(hex: "#FFF1C9")
            map.strokeColor = UIColor(hex: "#D6AE77")
            map.lineWidth = 2
            map.position = CGPoint(x: 13, y: 13)
            map.zRotation = -0.12
            root.addChild(map)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -38, y: -11))
            path.addCurve(to: CGPoint(x: 35, y: 12), controlPoint1: CGPoint(x: -4, y: 29), controlPoint2: CGPoint(x: 10, y: -25))
            let route = SKShapeNode(path: path.cgPath)
            route.strokeColor = UIColor(hex: "#9BB789")
            route.lineWidth = 3
            route.lineCap = .round
            map.addChild(route)
            let fruit = MenuStyle.art("fruit_strawberry", size: 18)
            fruit.position = CGPoint(x: 36, y: 12)
            map.addChild(fruit)
            let fold = SKSpriteNode(color: UIColor(hex: "#DCBC8A").withAlphaComponent(0.5), size: CGSize(width: 1, height: 47))
            fold.position.x = -11
            map.addChild(fold)
        }
        return root
    }
}

/// Give VoiceOver the same action as a touch, without relying on a synthetic tap.
private final class StoryActionButton: SKShapeNode {
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}
