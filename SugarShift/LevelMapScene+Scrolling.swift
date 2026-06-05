import SpriteKit

// Touch / scrolling (wheel-style momentum)
extension LevelMapScene {
    // MARK: - Touch / scrolling (wheel-style momentum)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        if let card = shopCard {
            _ = card.handleTap(at: p)
            return
        }
        if collectionCard != nil {
            handleCollectionTap(at: p)
            return
        }
        if debugCard != nil {
            handleDebugTap(at: p)
            return
        }
        if let card = settingsCard {
            _ = card.handleTouchBegan(at: p, timestamp: t.timestamp)
            return
        }
        if levelPreviewCard != nil {
            handlePreviewTap(at: p)
            return
        }

        // HUD / bottom bar taps don't start a drag
        if let n = nodeAtScene(p)?.name {
            if n == "hudSettings" { onSettings?(); return }
            if n == "hudShop"     { onShop?();     return }
            if n == "tabMap"      { focusCurrentLevel(); return }
            if n == "tabShop"     { onShop?();     return }
            if n == "tabDaily"    { showDailyChallengePreview(); return }
            if n == "tabFriends"  { showCollectionAlbum(); return }
            if n == "tabBoosters" { openToolsTab(); return }
            if n == "tabRush"     { launchEndless(); return }
        }

        isDragging = true
        didDragSignificantly = false
        dragLastY = p.y
        dragStartY = p.y
        dragStartedAt = t.timestamp
        dragLastTime = t.timestamp
        velocity = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let card = settingsCard, let t = touches.first {
            _ = card.handleTouchMoved(at: t.location(in: self), timestamp: t.timestamp)
            return
        }

        guard isDragging, let t = touches.first else { return }
        let p = t.location(in: self)
        let dy = p.y - dragLastY
        let dt = max(t.timestamp - dragLastTime, 0.001)

        // Pre-clamp; allow rubber-band overshoot for that "wheel turning past stop" feel
        var newY = world.position.y + dy
        if newY > worldYMax {
            newY = worldYMax + (newY - worldYMax) * elasticPullFactor
        } else if newY < worldYMin {
            newY = worldYMin + (newY - worldYMin) * elasticPullFactor
        }
        world.position.y = newY

        // Track velocity (smoothed)
        let frameVel = CGFloat(dy) / CGFloat(dt)
        velocity = velocity * 0.4 + frameVel * 0.6

        if abs(p.y - dragStartY) > 6 { didDragSignificantly = true }

        dragLastY = p.y
        dragLastTime = t.timestamp
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let card = settingsCard, let t = touches.first {
            _ = card.handleTouchEnded(at: t.location(in: self), timestamp: t.timestamp)
            isDragging = false
            velocity = 0
            return
        }

        defer { isDragging = false }

        // If drag was just a tap, hit-test for level / bottom bar tap
        if !didDragSignificantly, let t = touches.first {
            let p = t.location(in: self)
            handleTapAt(scenePoint: p)
            velocity = 0
            return
        }
        // else: leave velocity intact for wheel-roll deceleration via update()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let card = settingsCard {
            card.handleTouchCancelled()
        }
        isDragging = false
        velocity = 0
    }

    func nodeAtScene(_ p: CGPoint) -> SKNode? {
        var n: SKNode? = atPoint(p)
        while let cur = n {
            if cur.name != nil { return cur }
            n = cur.parent
        }
        return nil
    }

    func handleTapAt(scenePoint p: CGPoint) {
        // Walk up the node chain looking for a tappable name
        var node: SKNode? = atPoint(p)
        while let cur = node {
            if let name = cur.name {
                if name.hasPrefix("lvl:") {
                    let lvl = Int(name.dropFirst(4)) ?? 0
                    if lvl >= 1, lvl <= Persistence.highestUnlockedLevel {
                        bounce(cur)
                        showLevelPreview(level: lvl, titleOverride: nil)
                    } else if lvl > 0 {
                        // Locked — wiggle
                        wiggle(cur)
                    }
                    return
                }
                if name == "hudSettings" { onSettings?(); return }
                if name == "hudShop"     { onShop?();     return }
                if name == "tabMap"      { focusCurrentLevel(); return }
                if name == "tabShop"     { onShop?();     return }
                if name == "tabDaily"    { showDailyChallengePreview(); return }
                if name == "tabFriends"  { showCollectionAlbum(); return }
                if name == "tabBoosters" { openToolsTab(); return }
                if name == "tabRush"     { launchEndless(); return }
            }
            node = cur.parent
        }
    }

    func openToolsTab() {
        #if DEBUG
        showDebugDesignerMenu()
        #else
        onShop?()
        #endif
    }

    func focusCurrentLevel() {
        scrollToLevel(Persistence.currentLevel, animated: true)
        if let node = levelNodes[Persistence.currentLevel] {
            bounce(node)
        }
    }

    func showDailyChallengePreview() {
        let daily = Levels.dailyChallenge()
        let claimed = Persistence.hasClaimedDailyReward(daily.dateKey)
        let title = claimed ? String(localized: "Daily cleared") : String(localized: "Daily Challenge")
        showLevelPreview(level: daily.level, titleOverride: title)
        Analytics.track("daily_preview_opened",
                        properties: ["level": "\(daily.level)",
                                     "date": daily.dateKey,
                                     "claimed": "\(claimed)"])
    }

    func showCollectionAlbum() {
        collectionCard?.removeFromParent()
        let overlay = makeOverlay(name: "collectionCard")
        let cardW = min(size.width - 34, 344)
        let cardH: CGFloat = 420
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.75)
        card.lineWidth = 1
        card.zPosition = 1
        overlay.addChild(card)

        addCardTitle("Collection", subtitle: String(localized: "Themes, crowns, badges, perfect clears"), to: card, y: cardH / 2 - 36)

        let themes = Persistence.unlockedThemes()
        let eventBadges = Persistence.claimedEventRewardIDs()
        let rows: [(String, String)] = [
            (String(localized: "Themes"), themes.isEmpty ? String(localized: "None yet") : themes.prefix(3).joined(separator: ", ")),
            ("Crowns", "\(Persistence.crownLevelCount()) crown levels cleared"),
            ("3-star milestones", "\(Persistence.threeStarLevelCount()) perfect clears"),
            (String(localized: "Event badges"), eventBadges.isEmpty ? String(localized: "Play events to earn badges") : String(localized: "\(eventBadges.count) earned")),
            (String(localized: "Daily streak"), String(localized: "\(Persistence.dailyStreak) days"))
        ]

        var y = cardH / 2 - 112
        for row in rows {
            addPreviewRow(to: card, width: cardW - 48, title: row.0, value: row.1, y: y)
            y -= 38
        }

        let crownRow = SKNode()
        crownRow.position = CGPoint(x: 0, y: -cardH / 2 + 92)
        card.addChild(crownRow)
        for i in 0..<5 {
            let level = 100 + i * 25
            let earned = Persistence.starsForLevel(min(level, Levels.count)) > 0
            let badge = makeAlbumBadge(title: "\(min(level, Levels.count))",
                                       earned: earned,
                                       icon: Icons.Name.crown)
            badge.position = CGPoint(x: CGFloat(i - 2) * 58, y: 0)
            crownRow.addChild(badge)
        }

        addCloseButton(to: card, width: cardW, y: -cardH / 2 + 30, name: "collectionClose")
        addChild(overlay)
        collectionCard = overlay
    }

    func makeAlbumBadge(title: String, earned: Bool, icon: String) -> SKNode {
        let node = SKNode()
        let circle = SKShapeNode(circleOfRadius: 20)
        circle.fillColor = earned ? UIColor(hex: "#FACC15") : UIColor(hex: "#E2E8F0")
        circle.strokeColor = earned ? UIColor(hex: "#92400E") : UIColor(hex: "#CBD5E1")
        circle.lineWidth = 1.2
        node.addChild(circle)

        let crown = Icons.sprite(icon,
                                 size: 13,
                                 weight: .heavy,
                                 tint: earned ? UIColor(hex: "#0F172A") : UIColor(hex: "#64748B"))
        crown.position = CGPoint(x: 0, y: 5)
        node.addChild(crown)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = title
        label.fontSize = 8
        label.fontColor = earned ? UIColor(hex: "#0F172A") : UIColor(hex: "#64748B")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -9)
        node.addChild(label)
        return node
    }

    func showDebugDesignerMenu() {
        #if DEBUG
        debugCard?.removeFromParent()
        let overlay = makeOverlay(name: "debugCard")
        let cardW = min(size.width - 34, 344)
        let cardH: CGFloat = 470
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.98)
        card.strokeColor = UIColor(hex: "#CBD5E1")
        card.lineWidth = 1
        card.zPosition = 1
        overlay.addChild(card)

        addCardTitle("Designer", subtitle: String(localized: "Jump, grant stock, reset events, export balance"), to: card, y: cardH / 2 - 36)

        let jumps = [1, 25, 50, 75, 100, 150, 200]
        var y = cardH / 2 - 104
        for chunk in stride(from: 0, to: jumps.count, by: 4) {
            let row = Array(jumps[chunk..<min(chunk + 4, jumps.count)])
            let spacing: CGFloat = 74
            for (index, level) in row.enumerated() {
                let btn = makeSmallDebugButton(text: "\(level)", name: "debugJump:\(level)")
                btn.position = CGPoint(x: CGFloat(index) * spacing - CGFloat(row.count - 1) * spacing / 2, y: y)
                card.addChild(btn)
            }
            y -= 50
        }

        let actions: [(String, String)] = [
            (String(localized: "Grant stock"), "debugGrant"),
            ("Reset daily/events", "debugResetDaily"),
            (String(localized: "Export CSV"), "debugExport")
        ]
        for action in actions {
            let btn = makeWideDebugButton(text: action.0, name: action.1, width: cardW - 62)
            btn.position = CGPoint(x: 0, y: y)
            card.addChild(btn)
            y -= 48
        }

        addCloseButton(to: card, width: cardW, y: -cardH / 2 + 30, name: "debugClose")
        addChild(overlay)
        debugCard = overlay
        #endif
    }

    func makeOverlay(name: String) -> SKNode {
        let overlay = SKNode()
        overlay.zPosition = 1700
        overlay.name = name
        let scrim = SKShapeNode(rectOf: size)
        scrim.fillColor = UIColor(white: 0, alpha: 0.42)
        scrim.strokeColor = .clear
        scrim.name = "\(name)Close"
        overlay.addChild(scrim)
        return overlay
    }

    func addCardTitle(_ titleText: String, subtitle: String, to card: SKNode, y: CGFloat) {
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = titleText
        title.fontSize = 24
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: y)
        card.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = subtitle
        sub.fontSize = 11
        sub.fontColor = UIColor(hex: "#64748B")
        sub.verticalAlignmentMode = .center
        sub.horizontalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: y - 24)
        card.addChild(sub)
    }

    func makeSmallDebugButton(text: String, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 58, height: 38), cornerRadius: 12)
        btn.fillColor = UIColor(hex: "#0F172A")
        btn.strokeColor = .clear
        btn.name = name
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    func makeWideDebugButton(text: String, name: String, width: CGFloat) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: 40), cornerRadius: 14)
        btn.fillColor = UIColor(hex: "#EC4899")
        btn.strokeColor = .clear
        btn.name = name
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    func addCloseButton(to card: SKNode, width: CGFloat, y: CGFloat, name: String) {
        let buttonW = min(width - 96, 158)
        let shell = SKShapeNode(rectOf: CGSize(width: buttonW, height: 32), cornerRadius: 16)
        shell.fillColor = UIColor(hex: "#F8FAFC")
        shell.strokeColor = UIColor(hex: "#CBD5E1")
        shell.lineWidth = 1
        shell.position = CGPoint(x: 0, y: y)
        shell.name = name
        card.addChild(shell)

        let close = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        close.text = String(localized: "Close")
        close.fontSize = 13
        close.fontColor = UIColor(hex: "#475569")
        close.verticalAlignmentMode = .center
        close.horizontalAlignmentMode = .center
        close.name = name
        shell.addChild(close)
    }

    func handleCollectionTap(at p: CGPoint) {
        var node: SKNode? = atPoint(p)
        while let cur = node {
            if cur.name == "collectionClose" || cur.name == "collectionCardClose" {
                collectionCard?.removeFromParent()
                collectionCard = nil
                return
            }
            node = cur.parent
        }
    }

    func handleDebugTap(at p: CGPoint) {
        #if DEBUG
        var node: SKNode? = atPoint(p)
        while let cur = node {
            guard let name = cur.name else {
                node = cur.parent
                continue
            }
            if name == "debugClose" || name == "debugCardClose" {
                debugCard?.removeFromParent()
                debugCard = nil
                return
            }
            if name.hasPrefix("debugJump:") {
                let level = Int(name.dropFirst("debugJump:".count)) ?? Persistence.currentLevel
                Persistence.currentLevel = level
                debugCard?.removeFromParent()
                debugCard = nil
                reloadProgress(animated: true)
                showLevelPreview(level: level, titleOverride: "Designer Level \(level)")
                return
            }
            if name == "debugGrant" {
                Persistence.grantDesignerBoosters()
                refreshHUD()
                bounce(cur)
                return
            }
            if name == "debugResetDaily" {
                Persistence.resetDailyAndEventState()
                refreshFixedPromos()
                bounce(cur)
                return
            }
            if name == "debugExport" {
                UIPasteboard.general.string = LevelDesignReport.csv()
                bounce(cur)
                return
            }
            node = cur.parent
        }
        #endif
    }

    func showLevelPreview(level: Int, titleOverride: String?) {
        levelPreviewCard?.removeFromParent()
        previewLevel = level

        let config = Levels.config(for: level)
        let chapter = Levels.chapter(for: level)
        let daily = Levels.dailyChallenge()
        let events = Levels.activeEvents()
        let matchingEvents = events.filter { $0.level == level }
        let isDaily = level == daily.level
        let stars = Persistence.starsForLevel(level)
        var baseRows: [(String, String)] = [
            (String(localized: "Difficulty"), config.difficulty.displayName),
            ("Goal", config.goal.previewText),
            ("Stars", LevelScoring.previewSummary(for: config)),
            ("Moves", "\(config.moves)"),
            ("Board", "\(config.rows)x\(config.cols), \(config.colors) fruits"),
            ("Mechanics", config.layout.mechanicSummary),
            ("Tip", suggestedBooster(for: config))
        ]
        if !config.modifiers.isEmpty {
            baseRows.insert(("Rules", config.modifiers.map(\.title).joined(separator: ", ")), at: 6)
        }
        let dailyRows: [(String, String)] = isDaily ? [
            (String(localized: "Daily"), Persistence.hasClaimedDailyReward(daily.dateKey) ? String(localized: "Reward claimed today") : daily.reward.summary),
            ("Streak", "\(Persistence.dailyStreak) days"),
            ("Tomorrow", Levels.tomorrowDailyRewardPreview().summary)
        ] : []
        let eventRows: [(String, String)] = matchingEvents.prefix(2).map { event in
            let claimed = Persistence.hasClaimedEventReward(event.id)
            return (event.title, claimed ? String(localized: "Reward claimed") : event.reward.summary)
        }
        let previewRows = baseRows + dailyRows + eventRows
        let rowStep: CGFloat = previewRows.count > 9 ? 31 : 34

        let overlay = SKNode()
        overlay.zPosition = 1600
        overlay.name = "levelPreview"

        let scrim = SKShapeNode(rectOf: size)
        scrim.fillColor = UIColor(white: 0, alpha: 0.42)
        scrim.strokeColor = .clear
        scrim.name = "previewClose"
        overlay.addChild(scrim)

        let cardW = min(size.width - 34, 344)
        let contentTopInset: CGFloat = 130
        let actionReserve: CGFloat = 142
        let desiredCardH = contentTopInset + actionReserve + CGFloat(max(0, previewRows.count - 1)) * rowStep
        let cardH = min(size.height - 96, max(matchingEvents.isEmpty ? 452 : 486, desiredCardH))
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.7)
        card.lineWidth = 1
        card.zPosition = 1
        overlay.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = titleOverride ?? "Level \(level)"
        title.fontSize = Persistence.largeText ? 25 : 23
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: cardH / 2 - 36)
        card.addChild(title)

        if level >= 100 || isDaily {
            let crown = Icons.sprite(isDaily ? Icons.Name.star : Icons.Name.crown,
                                     size: 18,
                                     tint: UIColor(hex: "#F59E0B"))
            crown.position = CGPoint(x: title.frame.maxX - card.position.x + 16, y: title.position.y + 5)
            card.addChild(crown)
        }

        let chapterLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        chapterLabel.text = "\(chapter.title)  •  \(chapter.range.lowerBound)-\(chapter.range.upperBound)"
        chapterLabel.fontSize = 12
        chapterLabel.fontColor = UIColor(hex: "#BE185D")
        chapterLabel.verticalAlignmentMode = .center
        chapterLabel.horizontalAlignmentMode = .center
        chapterLabel.position = CGPoint(x: 0, y: cardH / 2 - 62)
        card.addChild(chapterLabel)

        let starRow = makeStarRow(filled: stars, size: 10)
        starRow.position = CGPoint(x: 0, y: cardH / 2 - 92)
        card.addChild(starRow)

        var y = cardH / 2 - 130
        for row in previewRows {
            addPreviewRow(to: card,
                          width: cardW - 44,
                          title: row.0,
                          value: row.1,
                          y: y)
            y -= rowStep
        }

        let play = SKShapeNode(rectOf: CGSize(width: cardW - 62, height: 48), cornerRadius: 24)
        play.fillColor = UIColor(hex: "#EC4899")
        play.strokeColor = .clear
        play.name = "previewPlay"
        play.position = CGPoint(x: 0, y: -cardH / 2 + 94)
        card.addChild(play)

        let playLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        playLabel.text = isDaily ? String(localized: "Play Daily") : String(localized: "Play")
        playLabel.fontSize = 16
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.horizontalAlignmentMode = .center
        play.addChild(playLabel)

        addCloseButton(to: card, width: cardW, y: -cardH / 2 + 32, name: "previewClose")

        addChild(overlay)
        levelPreviewCard = overlay
        overlay.alpha = 0
        card.setScale(0.82)
        overlay.run(.fadeIn(withDuration: 0.12))
        card.run(.scale(to: 1.0, duration: 0.16))
    }

    func addPreviewRow(to parent: SKNode,
                               width: CGFloat,
                               title: String,
                               value: String,
                               y: CGFloat) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 11
        label.fontColor = UIColor(hex: "#64748B")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: -width / 2, y: y)
        fitLabel(label, maxWidth: width * 0.30, minFontSize: 9)
        parent.addChild(label)

        let valueLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        valueLabel.text = value
        valueLabel.fontSize = Persistence.largeText ? 12 : 11
        valueLabel.fontColor = UIColor(hex: "#0F172A")
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.position = CGPoint(x: width / 2, y: y)
        fitLabelOrTruncate(valueLabel, maxWidth: width * 0.68, minFontSize: 8.5)
        parent.addChild(valueLabel)
    }

    func fitLabelOrTruncate(_ label: SKLabelNode, maxWidth: CGFloat, minFontSize: CGFloat) {
        fitLabel(label, maxWidth: maxWidth, minFontSize: minFontSize)
        guard label.frame.width > maxWidth, var text = label.text, text.count > 4 else { return }
        while label.frame.width > maxWidth && text.count > 4 {
            text.removeLast()
            label.text = "\(text)..."
        }
    }

    func suggestedBooster(for config: LevelConfig) -> String {
        if config.layout.crateCount > 0 || config.layout.colorLockCount > 0 {
            return "Hammer saves moves on tough blockers."
        }
        if !config.layout.conveyorBelts.isEmpty || !config.layout.portalPairs.isEmpty {
            return "Watch movement before spending moves."
        }
        switch config.goal {
        case .clearBlockers:
            return "Hammer helps finish blockers."
        case .detonateBombs:
            return "Swap sets up bomb blasts."
        case .createSpecials:
            return "Swap helps form specials."
        case .collectColor:
            return "Shuffle can refresh colors."
        case .collectIngredients:
            return "Hammer rows under stalled baskets."
        case .collectKeys:
            return "Clear columns under keys."
        case .openChests:
            return "Match beside chests or drop keys."
        case .collectIngredientsAndKeys:
            return "Drop baskets and keys before chasing score."
        case .score:
            return config.layout.iceCount + config.layout.lockCount > 0
                ? "Hammer helps protect moves."
                : "Save boosters for late moves."
        }
    }

    func handlePreviewTap(at p: CGPoint) {
        var node: SKNode? = atPoint(p)
        while let cur = node {
            if cur.name == "previewPlay" {
                let level = previewLevel
                dismissLevelPreview()
                if let level {
                    onLevelSelected?(level)
                }
                return
            }
            if cur.name == "previewClose" {
                dismissLevelPreview()
                return
            }
            node = cur.parent
        }
    }

    func dismissLevelPreview() {
        levelPreviewCard?.removeFromParent()
        levelPreviewCard = nil
        previewLevel = nil
    }

    func bounce(_ node: SKNode) {
        node.run(.sequence([
            .scale(to: 0.92, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
    }

    func wiggle(_ node: SKNode) {
        node.run(.sequence([
            .rotate(byAngle:  0.12, duration: 0.05),
            .rotate(byAngle: -0.24, duration: 0.10),
            .rotate(byAngle:  0.12, duration: 0.05)
        ]))
    }
}
