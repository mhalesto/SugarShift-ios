import SpriteKit
import UIKit

/// Functional settings overlay. Toggles for sound/music/haptics/reduce-motion
/// (persisted via Persistence), plus Restart Level and Reset Progress actions.
final class SettingsCard: SKNode {

    enum Action {
        case restartLevel
        case resetProgress
        case close
        case firebaseSignIn
        case firebaseSync
        case firebaseSignOut
        case shapedBoardChanged(Bool)
        case visualAccessibilityChanged
        case gameplayAppearanceChanged
        case showCombos
    }

    var onAction: ((Action) -> Void)?

    private let cardSize: CGSize
    private let showsCombos: Bool
    private var rows: [(key: String, row: SKShapeNode, pill: SKShapeNode, knob: SKShapeNode, isOn: Bool)] = []
    private var actionRows: [(key: String, row: SKShapeNode, enabled: Bool)] = []
    private var transparencySliders: [SettingsTransparencySlider] = []
    private weak var pendingTransparencySlider: SettingsTransparencySlider?
    private var isDraggingTransparency = false
    private var scrollCrop: SKCropNode?
    private var scrollContent: SKNode?
    private var scrollTrack: SKShapeNode?
    private var scrollThumbContainer: SKNode?
    private var scrollThumbHeight: CGFloat = 44
    private var scrollTrackHeight: CGFloat = 0
    private var scrollViewportTopY: CGFloat = 0
    private var scrollViewportBottomY: CGFloat = 0
    private var footerTopY: CGFloat = 0
    private var scrollOffset: CGFloat = 0
    private var maxScrollOffset: CGFloat = 0
    private var isTrackingScroll = false
    private var didDragScroll = false
    private enum ScrollDragMode {
        case content
        case indicator
    }
    private var scrollDragMode: ScrollDragMode = .content
    private var dragStartPoint: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var lastDragTime: TimeInterval = 0
    private var scrollVelocity: CGFloat = 0
    private var hasActiveTouch = false

    init(sceneSize: CGSize, showsCombos: Bool = false) {
        let availableHeight = max(430, sceneSize.height - 132)
        cardSize = CGSize(width: min(sceneSize.width - 32, 340),
                          height: min(availableHeight, 590))
        self.showsCombos = showsCombos
        super.init()
        zPosition = 1500
        build(sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func build(sceneSize: CGSize) {
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
        title.text = String(localized: "Settings")
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

        footerTopY = -cardSize.height / 2 + 88
        scrollViewportTopY = cardSize.height / 2 - 76
        scrollViewportBottomY = footerTopY + 12
        let viewportHeight = max(220, scrollViewportTopY - scrollViewportBottomY)
        let viewportCenterY = (scrollViewportTopY + scrollViewportBottomY) / 2
        let viewportWidth = cardSize.width - 32

        let crop = SKCropNode()
        crop.position = CGPoint(x: 0, y: viewportCenterY)
        crop.zPosition = 2
        card.addChild(crop)
        scrollCrop = crop

        let mask = SKShapeNode(rectOf: CGSize(width: viewportWidth, height: viewportHeight),
                               cornerRadius: 16)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let content = SKNode()
        content.position = CGPoint(x: 0, y: viewportHeight / 2)
        crop.addChild(content)
        scrollContent = content

        let rowHeight: CGFloat = 48
        let rowStep: CGFloat = 56
        let topScrollInset: CGFloat = 24
        let bottomScrollInset: CGFloat = 34
        var y: CGFloat = -topScrollInset - rowHeight / 2
        if showsCombos {
            addActionRow(card: content,
                         key: "combos",
                         title: String(localized: "Specials & Combos"),
                         subtitle: String(localized: "How power-ups are made and combined"),
                         emoji: "✨",
                         buttonTitle: String(localized: "View"),
                         enabled: true,
                         atY: y)
            y -= rowStep
        }
        if FirebaseBackendService.shared.isSignedIn {
            addActionRow(card: content,
                         key: "firebaseSync",
                         title: FirebaseBackendService.shared.accountTitle,
                         subtitle: FirebaseBackendService.shared.accountSubtitle,
                         emoji: "☁️",
                         buttonTitle: "Sync",
                         enabled: FirebaseBackendService.shared.accountActionEnabled,
                         atY: y)
            y -= rowStep
            addActionRow(card: content,
                         key: "firebaseSignOut",
                         title: String(localized: "Sign Out"),
                         subtitle: String(localized: "Keep local progress on this device"),
                         emoji: "↪",
                         buttonTitle: "Out",
                         enabled: FirebaseBackendService.shared.accountActionEnabled,
                         atY: y)
            y -= rowStep
        } else {
            addActionRow(card: content,
                         key: "firebaseSignIn",
                         title: FirebaseBackendService.shared.accountTitle,
                         subtitle: FirebaseBackendService.shared.accountSubtitle,
                         emoji: "☁️",
                         buttonTitle: FirebaseBackendService.shared.accountButtonTitle,
                         enabled: FirebaseBackendService.shared.accountActionEnabled,
                         atY: y)
            y -= rowStep
        }
        addToggleRow(card: content, key: "sound",
                     title: String(localized: "Sound effects"), emoji: "🔊",
                     initialOn: Persistence.soundEnabled, atY: y)
        y -= 56
        addToggleRow(card: content, key: "music",
                     title: String(localized: "Music"), emoji: "🎵",
                     initialOn: Persistence.musicEnabled, atY: y)
        y -= 56
        addToggleRow(card: content, key: "haptics",
                     title: String(localized: "Haptics"), emoji: "📳",
                     initialOn: Persistence.hapticsEnabled, atY: y)
        y -= 56
        for surface in SettingsTransparencySlider.Surface.allCases {
            let slider = SettingsTransparencySlider(surface: surface, width: cardSize.width - 32)
            slider.position = CGPoint(x: 0, y: y - (SettingsTransparencySlider.rowHeight - rowHeight) / 2)
            slider.onChange = { [weak self] in self?.onAction?(.gameplayAppearanceChanged) }
            content.addChild(slider)
            transparencySliders.append(slider)
            y -= SettingsTransparencySlider.rowHeight + 8
        }
        addToggleRow(card: content, key: "reduceMotion",
                     title: String(localized: "Reduce motion"), emoji: "🌀",
                     initialOn: Persistence.reduceMotion, atY: y)
        y -= 56
        addToggleRow(card: content, key: "highContrast",
                     title: String(localized: "High contrast"), emoji: "◐",
                     initialOn: Persistence.highContrast, atY: y)
        y -= 56
        addToggleRow(card: content, key: "largeText",
                     title: String(localized: "Large text"), emoji: "Aa",
                     initialOn: Persistence.largeText, atY: y)
        y -= 56
        addToggleRow(card: content, key: "candyLabels",
                     title: String(localized: "Candy labels"), emoji: "A",
                     initialOn: Persistence.candyLabels, atY: y)
        y -= 56
        addToggleRow(card: content, key: "colorBlindPatterns",
                     title: String(localized: "Color-blind patterns"), emoji: "◆",
                     initialOn: Persistence.colorBlindPatterns, atY: y)
        y -= 56
        addToggleRow(card: content, key: "ghostPreview",
                     title: String(localized: "Move preview"), emoji: "👁",
                     initialOn: Persistence.ghostPreview, atY: y)
        y -= 56
        addToggleRow(card: content, key: "shapedBoard",
                     title: String(localized: "Shape board"), emoji: "🔳",
                     initialOn: Persistence.shapedBoard, atY: y)
        y -= 56
        addToggleRow(card: content, key: "gameCenter",
                     title: String(localized: "Game Center"), emoji: "🎮",
                     initialOn: Persistence.gameCenterOptIn, atY: y)
        y -= 56
        let promiseHeight = addFairPlayPromise(card: content,
                                               width: viewportWidth - 16,
                                               atY: y)

        let totalRows = rows.count + actionRows.count
        let contentHeight = topScrollInset + rowHeight + CGFloat(max(0, totalRows - 1)) * rowStep
            + CGFloat(transparencySliders.count) * (SettingsTransparencySlider.rowHeight + 8)
            + promiseHeight + 16 + bottomScrollInset
        maxScrollOffset = max(0, contentHeight - viewportHeight)

        let topMist = SKShapeNode(rectOf: CGSize(width: viewportWidth - 8, height: 10),
                                  cornerRadius: 5)
        topMist.fillColor = UIColor.white.withAlphaComponent(0.52)
        topMist.strokeColor = .clear
        topMist.position = CGPoint(x: 0, y: scrollViewportTopY - 5)
        topMist.zPosition = 3
        card.addChild(topMist)

        let bottomMist = SKShapeNode(rectOf: CGSize(width: viewportWidth - 8, height: 18),
                                     cornerRadius: 9)
        bottomMist.fillColor = UIColor.white.withAlphaComponent(0.78)
        bottomMist.strokeColor = .clear
        bottomMist.position = CGPoint(x: 0, y: scrollViewportBottomY + 9)
        bottomMist.zPosition = 3
        card.addChild(bottomMist)

        scrollTrackHeight = max(56, viewportHeight - 18)
        scrollThumbHeight = max(42, min(74, scrollTrackHeight * viewportHeight / max(contentHeight, viewportHeight)))

        let track = SKShapeNode(rectOf: CGSize(width: 5, height: scrollTrackHeight), cornerRadius: 2.5)
        track.fillColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.32)
        track.strokeColor = .clear
        track.position = CGPoint(x: -cardSize.width / 2 + 16, y: viewportCenterY)
        track.zPosition = 4
        track.alpha = maxScrollOffset > 0 ? 1 : 0
        card.addChild(track)
        scrollTrack = track

        let thumbContainer = SKNode()
        thumbContainer.position = CGPoint(x: track.position.x, y: viewportCenterY)
        thumbContainer.zPosition = 5
        thumbContainer.alpha = maxScrollOffset > 0 ? 0.78 : 0
        card.addChild(thumbContainer)
        scrollThumbContainer = thumbContainer

        let thumbGlow = SKShapeNode(rectOf: CGSize(width: 13, height: scrollThumbHeight + 12),
                                    cornerRadius: 6.5)
        thumbGlow.fillColor = UIColor(hex: "#F9A8D4").withAlphaComponent(0.26)
        thumbGlow.strokeColor = .clear
        thumbGlow.glowWidth = 8
        thumbContainer.addChild(thumbGlow)

        let thumb = SKShapeNode(rectOf: CGSize(width: 6, height: scrollThumbHeight),
                                cornerRadius: 3)
        thumb.fillColor = UIColor(hex: "#F472B6").withAlphaComponent(0.92)
        thumb.strokeColor = UIColor.white.withAlphaComponent(0.65)
        thumb.lineWidth = 0.8
        thumbContainer.addChild(thumb)
        updateScrollIndicator(animated: false)
        startScrollerBreathing()

        let footerDivider = SKShapeNode(rectOf: CGSize(width: cardSize.width - 40, height: 1))
        footerDivider.fillColor = UIColor(white: 0, alpha: 0.08)
        footerDivider.strokeColor = .clear
        footerDivider.position = CGPoint(x: 0, y: footerTopY)
        footerDivider.zPosition = 6
        card.addChild(footerDivider)

        let infoText = "SugarShift  v\(appVersion()) (build \(appBuild()))"
        let info = SKLabelNode(fontNamed: "AvenirNext-Medium")
        info.text = infoText
        info.fontSize = 11
        info.fontColor = UIColor(white: 0, alpha: 0.45)
        info.verticalAlignmentMode = .center
        info.horizontalAlignmentMode = .center
        info.position = CGPoint(x: 0, y: footerTopY - 15)
        info.zPosition = 6
        card.addChild(info)

        let footer = SKNode()
        footer.zPosition = 7
        card.addChild(footer)

        let gap: CGFloat = 7
        let footerWidth = cardSize.width - 36
        let buttonSize = CGSize(width: (footerWidth - gap * 2) / 3, height: 36)
        let buttonY = -cardSize.height / 2 + 31
        let startX = -footerWidth / 2 + buttonSize.width / 2

        addFooterButton(card: footer,
                        name: "settingsAction:restart",
                        title: String(localized: "Restart"),
                        iconEmoji: "↻",
                        fill: UIColor(hex: "#F472B6"),
                        textColor: .white,
                        at: CGPoint(x: startX, y: buttonY),
                        size: buttonSize)

        addFooterButton(card: footer,
                        name: "settingsAction:reset",
                        title: String(localized: "Reset"),
                        iconEmoji: "🗑",
                        fill: UIColor(hex: "#FEE2E2"),
                        textColor: UIColor(hex: "#B91C1C"),
                        at: CGPoint(x: startX + buttonSize.width + gap, y: buttonY),
                        size: buttonSize)

        addFooterButton(card: footer,
                        name: "settingsClose",
                        title: String(localized: "Close"),
                        iconEmoji: "×",
                        fill: UIColor(hex: "#F8FAFC"),
                        textColor: UIColor(hex: "#475569"),
                        at: CGPoint(x: startX + (buttonSize.width + gap) * 2, y: buttonY),
                        size: buttonSize)
    }

    // MARK: - Rows

    /// Small statement panel at the end of the settings scroll — the player-
    /// facing version of the store positioning. Returns the panel height so
    /// the scroll content size can account for it.
    private func addFairPlayPromise(card: SKNode, width: CGFloat, atY y: CGFloat) -> CGFloat {
        let lines: [String] = [
            String(localized: "Every level is beatable without paying."),
            String(localized: "No forced ads. No fake difficulty."),
            String(localized: "One daily board, identical for everyone.")
        ]
        let lineStep: CGFloat = 19
        let panelHeight: CGFloat = 44 + CGFloat(lines.count) * lineStep
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: panelHeight), cornerRadius: 14)
        panel.fillColor = UIColor(hex: "#FDF2F8")
        panel.strokeColor = UIColor(hex: "#FBCFE8")
        panel.lineWidth = 1
        panel.position = CGPoint(x: 0, y: y - panelHeight / 2 + 24)
        card.addChild(panel)

        let heading = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        heading.text = String(localized: "Our Fair Play Promise 🍒")
        heading.fontSize = 13
        heading.fontColor = UIColor(hex: "#BE185D")
        heading.verticalAlignmentMode = .center
        heading.horizontalAlignmentMode = .center
        heading.position = CGPoint(x: 0, y: panelHeight / 2 - 20)
        panel.addChild(heading)

        var lineY = panelHeight / 2 - 44
        for text in lines {
            let line = SKLabelNode(fontNamed: "AvenirNext-Medium")
            line.text = text
            line.fontSize = 11.5
            line.fontColor = UIColor(hex: "#475569")
            line.verticalAlignmentMode = .center
            line.horizontalAlignmentMode = .center
            line.position = CGPoint(x: 0, y: lineY)
            panel.addChild(line)
            lineY -= lineStep
        }
        return panelHeight
    }

    private func addActionRow(card: SKNode, key: String, title: String, subtitle: String,
                              emoji: String, buttonTitle: String, enabled: Bool, atY y: CGFloat) {
        let rowW = cardSize.width - 32
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: 48), cornerRadius: 14)
        row.fillColor = UIColor(white: 0, alpha: 0.04)
        row.strokeColor = enabled ? UIColor(hex: "#60A5FA").withAlphaComponent(0.20) : UIColor(white: 0, alpha: 0.06)
        row.lineWidth = 1
        row.position = CGPoint(x: 0, y: y)
        row.name = "settingsActionRow:\(key)"
        row.alpha = enabled ? 1.0 : 0.62
        card.addChild(row)

        let icon = SKLabelNode(text: emoji)
        icon.fontSize = 21
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: -rowW / 2 + 28, y: 0)
        row.addChild(icon)

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        titleLabel.text = title
        titleLabel.fontSize = 13.5
        titleLabel.fontColor = UIColor(hex: "#0F172A")
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -rowW / 2 + 56, y: 8)
        row.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 9.5
        subtitleLabel.fontColor = UIColor(hex: "#64748B")
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.position = CGPoint(x: -rowW / 2 + 56, y: -11)
        fitLabel(subtitleLabel, maxWidth: rowW - 150, minFontSize: 8)
        row.addChild(subtitleLabel)

        let buttonW: CGFloat = 72
        let button = SKShapeNode(rectOf: CGSize(width: buttonW, height: 30), cornerRadius: 15)
        button.fillColor = enabled ? UIColor(hex: "#0F172A") : UIColor(white: 0, alpha: 0.16)
        button.strokeColor = .clear
        button.position = CGPoint(x: rowW / 2 - 12 - buttonW / 2, y: 0)
        button.name = "settingsActionRow:\(key)"
        row.addChild(button)

        let buttonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        buttonLabel.text = buttonTitle
        buttonLabel.fontSize = 11.5
        buttonLabel.fontColor = enabled ? .white : UIColor(white: 1, alpha: 0.75)
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.horizontalAlignmentMode = .center
        buttonLabel.name = "settingsActionRow:\(key)"
        fitLabel(buttonLabel, maxWidth: buttonW - 14, minFontSize: 9)
        button.addChild(buttonLabel)

        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title). \(subtitle)"
        row.accessibilityTraits = .button

        actionRows.append((key, row, enabled))
    }

    private func addToggleRow(card: SKNode, key: String, title: String,
                              emoji: String, initialOn: Bool, atY y: CGFloat) {
        let rowW = cardSize.width - 32
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: 48), cornerRadius: 14)
        row.fillColor = UIColor(white: 0, alpha: 0.04)
        row.strokeColor = UIColor(white: 0, alpha: 0.06)
        row.lineWidth = 1
        row.position = CGPoint(x: 0, y: y)
        row.name = "settingsToggle:\(key)"
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

        row.isAccessibilityElement = true
        row.accessibilityLabel = title
        row.accessibilityValue = initialOn ? String(localized: "On") : String(localized: "Off")
        row.accessibilityTraits = .button

        rows.append((key, row, pill, knob, initialOn))
    }

    private func addFooterButton(card: SKNode, name: String, title: String,
                                 iconEmoji: String, fill: UIColor,
                                 textColor: UIColor, at point: CGPoint,
                                 size: CGSize) {
        let btn = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        btn.fillColor = fill
        if name == "settingsClose" {
            btn.strokeColor = UIColor(hex: "#CBD5E1")
            btn.lineWidth = 1
        } else {
            btn.strokeColor = UIColor.white.withAlphaComponent(0.22)
            btn.lineWidth = 0
        }
        btn.position = point
        btn.name = name
        card.addChild(btn)

        let icon = SKLabelNode(text: iconEmoji)
        icon.fontSize = name == "settingsClose" ? 16 : 15
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: -size.width / 2 + 20, y: 0)
        icon.name = name
        btn.addChild(icon)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 12.5
        label.fontColor = textColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 8, y: 0)
        label.name = name
        fitLabel(label, maxWidth: size.width - 42, minFontSize: 10)
        btn.addChild(label)

        btn.isAccessibilityElement = true
        btn.accessibilityLabel = title
        btn.accessibilityTraits = .button
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minFontSize: CGFloat) {
        while label.frame.width > maxWidth && label.fontSize > minFontSize {
            label.fontSize -= 0.5
        }
    }

    // MARK: - Tap handling

    func handleTap(at scenePoint: CGPoint) -> Bool {
        performTap(at: scenePoint)
        return true
    }

    func handleTouchBegan(at scenePoint: CGPoint, timestamp: TimeInterval = 0) -> Bool {
        hasActiveTouch = true
        scrollContent?.removeAction(forKey: "settingsScrollMomentum")
        dragStartPoint = scenePoint
        lastDragPoint = scenePoint
        lastDragTime = timestamp
        scrollVelocity = 0
        didDragScroll = false
        pendingTransparencySlider = nil
        isDraggingTransparency = false

        let local = self.convert(scenePoint, from: self.parent ?? self)
        if isPointInScrollViewport(local), !isPointNearScrollIndicator(local) {
            pendingTransparencySlider = transparencySlider(at: scenePoint)
        }
        isTrackingScroll = maxScrollOffset > 0 && isPointInScrollViewport(local)
        if isTrackingScroll {
            scrollDragMode = isPointNearScrollIndicator(local) ? .indicator : .content
            highlightScroller(active: true)
        }
        return true
    }

    func handleTouchMoved(at scenePoint: CGPoint, timestamp: TimeInterval = 0) -> Bool {
        if let slider = pendingTransparencySlider, !didDragScroll {
            let dx = abs(scenePoint.x - dragStartPoint.x)
            let dy = abs(scenePoint.y - dragStartPoint.y)
            if isDraggingTransparency || (dx > 5 && dx > dy) {
                isDraggingTransparency = true
                isTrackingScroll = false
                highlightScroller(active: false)
                slider.adjust(at: slider.convert(scenePoint, from: parent ?? self))
                return true
            }
            if dy > 5 { pendingTransparencySlider = nil }
        }
        guard isTrackingScroll else { return true }

        let dy = scenePoint.y - lastDragPoint.y
        if abs(scenePoint.y - dragStartPoint.y) > 5 {
            didDragScroll = true
        }

        if didDragScroll {
            let dt = max(timestamp - lastDragTime, 0.001)
            let deltaOffset: CGFloat
            switch scrollDragMode {
            case .content:
                deltaOffset = dy * 0.82
            case .indicator:
                let indicatorTravel = max(1, scrollTrackHeight - scrollThumbHeight)
                deltaOffset = -dy * maxScrollOffset / indicatorTravel * 0.55
            }
            setScrollOffset(scrollOffset + deltaOffset, rubberBand: true, animated: false)
            let frameVelocity = CGFloat(deltaOffset) / CGFloat(dt)
            scrollVelocity = scrollVelocity * 0.35 + frameVelocity * 0.65
        }

        lastDragPoint = scenePoint
        lastDragTime = timestamp
        return true
    }

    func handleTouchEnded(at scenePoint: CGPoint, timestamp: TimeInterval = 0) -> Bool {
        guard hasActiveTouch else { return true }
        defer {
            hasActiveTouch = false
            isTrackingScroll = false
            pendingTransparencySlider = nil
            isDraggingTransparency = false
            highlightScroller(active: false)
        }

        if let slider = pendingTransparencySlider, !didDragScroll {
            slider.adjust(at: slider.convert(scenePoint, from: parent ?? self))
            return true
        }

        if didDragScroll {
            if scrollDragMode == .indicator {
                settleScroll()
            } else {
                finishScroll(withVelocity: scrollVelocity)
            }
            return true
        }

        performTap(at: scenePoint)
        return true
    }

    func handleTouchCancelled() {
        hasActiveTouch = false
        isTrackingScroll = false
        didDragScroll = false
        scrollVelocity = 0
        pendingTransparencySlider = nil
        isDraggingTransparency = false
        settleScroll()
        highlightScroller(active: false)
    }

    private func performTap(at scenePoint: CGPoint) {
        let local = self.convert(scenePoint, from: self.parent ?? self)
        guard isPointInsideCard(local) else {
            onAction?(.close)
            return
        }

        if isPointInScrollViewport(local), let content = scrollContent {
            if let slider = transparencySlider(at: scenePoint) {
                slider.adjust(at: slider.convert(scenePoint, from: parent ?? self))
                return
            }
            let contentPoint = content.convert(scenePoint, from: self.parent ?? self)
            for row in actionRows where row.row.contains(contentPoint) {
                guard row.enabled else { return }
                bounce(row.row)
                switch row.key {
                case "combos":
                    onAction?(.showCombos)
                case "firebaseSignIn":
                    onAction?(.firebaseSignIn)
                case "firebaseSync":
                    onAction?(.firebaseSync)
                case "firebaseSignOut":
                    onAction?(.firebaseSignOut)
                default:
                    break
                }
                return
            }
            for row in rows where row.row.contains(contentPoint) {
                bounce(row.row)
                toggle(key: row.key)
                return
            }
            return
        }

        var n: SKNode? = atPoint(local)
        while let node = n {
            if node.name == "settingsClose" {
                onAction?(.close)
                return
            }
            if node.name == "settingsAction:restart" {
                bounce(node)
                onAction?(.restartLevel)
                return
            }
            if node.name == "settingsAction:reset" {
                bounce(node)
                onAction?(.resetProgress)
                return
            }
            n = node.parent
        }
    }

    private func isPointInsideCard(_ point: CGPoint) -> Bool {
        abs(point.x) <= cardSize.width / 2 && abs(point.y) <= cardSize.height / 2
    }

    private func transparencySlider(at scenePoint: CGPoint) -> SettingsTransparencySlider? {
        transparencySliders.first { slider in
            slider.acceptsTouch(at: slider.convert(scenePoint, from: parent ?? self))
        }
    }

    private func isPointInScrollViewport(_ point: CGPoint) -> Bool {
        abs(point.x) <= (cardSize.width - 32) / 2 &&
        point.y <= scrollViewportTopY &&
        point.y >= scrollViewportBottomY
    }

    private func isPointNearScrollIndicator(_ point: CGPoint) -> Bool {
        let indicatorX = -cardSize.width / 2 + 16
        return abs(point.x - indicatorX) <= 26 &&
        point.y <= scrollViewportTopY &&
        point.y >= scrollViewportBottomY
    }

    private func setScrollOffset(_ value: CGFloat, rubberBand: Bool, animated: Bool) {
        let target: CGFloat
        if rubberBand {
            if value < 0 {
                target = value * 0.35
            } else if value > maxScrollOffset {
                target = maxScrollOffset + (value - maxScrollOffset) * 0.35
            } else {
                target = value
            }
        } else {
            target = clamp(value, lower: 0, upper: maxScrollOffset)
        }

        scrollOffset = target
        let viewportHeight = scrollViewportTopY - scrollViewportBottomY
        let contentY = viewportHeight / 2 + target
        if animated {
            scrollContent?.run(.moveTo(y: contentY, duration: 0.14), withKey: "settingsScrollSettle")
        } else {
            scrollContent?.position.y = contentY
        }
        updateScrollIndicator(animated: animated)
    }

    private func finishScroll(withVelocity velocity: CGFloat) {
        guard maxScrollOffset > 0 else { return }
        let projected = scrollOffset + velocity * 0.16
        animateScroll(to: clamp(projected, lower: 0, upper: maxScrollOffset), duration: 0.28)
    }

    private func settleScroll() {
        animateScroll(to: clamp(scrollOffset, lower: 0, upper: maxScrollOffset), duration: 0.18)
    }

    private func animateScroll(to target: CGFloat, duration: TimeInterval) {
        guard let content = scrollContent else { return }
        let start = scrollOffset
        let distance = target - start
        guard abs(distance) > 0.5 else {
            setScrollOffset(target, rubberBand: false, animated: true)
            return
        }

        content.removeAction(forKey: "settingsScrollMomentum")
        let action = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self else { return }
            let t = min(max(CGFloat(elapsed) / CGFloat(duration), 0), 1)
            let remaining = 1 - t
            let eased = 1 - remaining * remaining * remaining
            self.setScrollOffset(start + distance * eased,
                                 rubberBand: false,
                                 animated: false)
        }
        content.run(action, withKey: "settingsScrollMomentum")
    }

    private func updateScrollIndicator(animated: Bool) {
        guard let thumbContainer = scrollThumbContainer else { return }
        guard maxScrollOffset > 0 else {
            scrollTrack?.alpha = 0
            thumbContainer.alpha = 0
            return
        }

        let progress = clamp(scrollOffset, lower: 0, upper: maxScrollOffset) / maxScrollOffset
        let trackCenterY = (scrollViewportTopY + scrollViewportBottomY) / 2
        let travel = max(0, (scrollTrackHeight - scrollThumbHeight) / 2)
        let targetY = trackCenterY + travel - progress * travel * 2

        if animated {
            thumbContainer.run(.moveTo(y: targetY, duration: 0.12),
                               withKey: "settingsScrollThumbMove")
        } else {
            thumbContainer.position.y = targetY
        }
    }

    private func startScrollerBreathing() {
        guard maxScrollOffset > 0, !Persistence.reduceMotion else { return }
        scrollThumbContainer?.removeAction(forKey: "settingsScrollerBreathe")
        scrollThumbContainer?.setScale(1.0)
        scrollThumbContainer?.run(.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: 0.94, duration: 1.05),
                .scale(to: 1.08, duration: 1.05)
            ]),
            .group([
                .fadeAlpha(to: 0.55, duration: 1.25),
                .scale(to: 0.96, duration: 1.25)
            ])
        ])), withKey: "settingsScrollerBreathe")
    }

    private func highlightScroller(active: Bool) {
        guard maxScrollOffset > 0 else { return }
        if active {
            scrollThumbContainer?.removeAction(forKey: "settingsScrollerBreathe")
            scrollThumbContainer?.run(.group([
                .fadeAlpha(to: 1.0, duration: 0.08),
                .scale(to: 1.12, duration: 0.08)
            ]), withKey: "settingsScrollerActive")
        } else if Persistence.reduceMotion {
            scrollThumbContainer?.run(.fadeAlpha(to: 0.78, duration: 0.12),
                                      withKey: "settingsScrollerActive")
        } else {
            startScrollerBreathing()
        }
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func toggle(key: String) {
        guard let idx = rows.firstIndex(where: { $0.key == key }) else { return }
        let newValue = !rows[idx].isOn
        rows[idx].isOn = newValue

        // Animate the pill colour + knob position
        let pill = rows[idx].pill
        pill.run(.colorize(with: newValue ? UIColor(hex: "#10B981") : UIColor(white: 0, alpha: 0.18),
                           colorBlendFactor: 1.0, duration: 0.14))
        pill.fillColor = newValue ? UIColor(hex: "#10B981") : UIColor(white: 0, alpha: 0.18)

        let knob = rows[idx].knob
        let pillW: CGFloat = 50
        let targetX: CGFloat = newValue ? pillW / 2 - 14 : -pillW / 2 + 14
        knob.run(.move(to: CGPoint(x: targetX, y: 0), duration: 0.14))
        rows[idx].row.accessibilityValue = newValue
            ? String(localized: "On")
            : String(localized: "Off")

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
            if newValue {
                scrollThumbContainer?.removeAction(forKey: "settingsScrollerBreathe")
                scrollThumbContainer?.setScale(1.0)
                scrollThumbContainer?.alpha = maxScrollOffset > 0 ? 0.78 : 0
            } else {
                startScrollerBreathing()
            }
        case "highContrast":
            Persistence.highContrast = newValue
            onAction?(.visualAccessibilityChanged)
        case "largeText":
            Persistence.largeText = newValue
            onAction?(.visualAccessibilityChanged)
        case "candyLabels":
            Persistence.candyLabels = newValue
            onAction?(.visualAccessibilityChanged)
        case "colorBlindPatterns":
            Persistence.colorBlindPatterns = newValue
            onAction?(.visualAccessibilityChanged)
        case "ghostPreview":
            Persistence.ghostPreview = newValue
        case "shapedBoard":
            Persistence.shapedBoard = newValue
            onAction?(.shapedBoardChanged(newValue))
        case "gameCenter":
            Persistence.gameCenterOptIn = newValue
            if newValue { GameCenterService.shared.authenticate() }
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
