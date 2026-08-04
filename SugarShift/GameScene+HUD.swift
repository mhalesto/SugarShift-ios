import SpriteKit

// HUD: header, footer, helpers
extension GameScene {
    // MARK: - HUD: Header Card

    func rebuildHUD() {
        headerCard?.removeFromParent()
        footerCard?.removeFromParent()
        undoButton?.removeFromParent()
        comboMeterTrack?.parent?.removeFromParent()
        buildHeaderCard()
        buildFooterCard()
        buildUndoButton()
        buildComboMeter()
        updateHUD()
        updateComboMeter()
    }

    func buildHeaderCard() {
        let cardW = size.width - 24
        let cardH: CGFloat = 170
        let topY = size.height / 2 - safeTop - 8 - cardH / 2

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.42)
        card.strokeColor = UIColor(white: 1, alpha: 0.55)
        card.lineWidth = 1
        card.position = CGPoint(x: 0, y: topY)
        card.zPosition = 50
        addChild(card)
        headerCard = card

        let leftX = -cardW / 2 + 18
        let rightX = cardW / 2 - 18

        // Lives pill (heart icon + 5/6)
        let pillW: CGFloat = 124
        let pill = makePill(width: pillW, height: 30,
                            fill: UIColor(red: 0.99, green: 0.36, blue: 0.51, alpha: 0.95),
                            stroke: .clear)
        pill.position = CGPoint(x: leftX + pillW / 2, y: cardH / 2 - 24)
        card.addChild(pill)

        // Subtle drop shadow under the lives pill
        let pillShadow = SKShapeNode(rectOf: CGSize(width: pillW, height: 30), cornerRadius: 15)
        pillShadow.fillColor = UIColor(white: 0, alpha: 0.18)
        pillShadow.strokeColor = .clear
        pillShadow.position = CGPoint(x: leftX + pillW / 2, y: cardH / 2 - 24 - 2)
        pillShadow.zPosition = -1
        card.addChild(pillShadow)

        let heart = Icons.sprite(Icons.Name.life, size: 13, tint: .white)
        heart.position = CGPoint(x: -pillW / 2 + 16, y: 0)
        pill.addChild(heart)

        let livesL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        livesL.fontSize = 13
        livesL.fontColor = .white
        livesL.verticalAlignmentMode = .center
        livesL.horizontalAlignmentMode = .center
        livesL.position = CGPoint(x: 16, y: 0)
        pill.addChild(livesL)
        livesLabel = livesL

        // Moves badge card (with drop shadow)
        let movesBadgeW: CGFloat = 88
        let movesBadgeH: CGFloat = 64
        let badgeShadow = SKShapeNode(rectOf: CGSize(width: movesBadgeW, height: movesBadgeH), cornerRadius: 14)
        badgeShadow.fillColor = UIColor(white: 0, alpha: 0.18)
        badgeShadow.strokeColor = .clear
        badgeShadow.position = CGPoint(x: rightX - movesBadgeW / 2, y: cardH / 2 - movesBadgeH / 2 - 14 - 3)
        badgeShadow.zPosition = -1
        card.addChild(badgeShadow)

        let movesBadge = SKShapeNode(rectOf: CGSize(width: movesBadgeW, height: movesBadgeH), cornerRadius: 14)
        movesBadge.fillColor = UIColor(white: 1, alpha: 0.97)
        movesBadge.strokeColor = .clear
        movesBadge.position = CGPoint(x: rightX - movesBadgeW / 2, y: cardH / 2 - movesBadgeH / 2 - 14)
        card.addChild(movesBadge)

        let movesNum = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        movesNum.fontSize = 28
        movesNum.fontColor = UIColor(hex: "#0F172A")
        movesNum.verticalAlignmentMode = .center
        movesNum.horizontalAlignmentMode = .center
        movesNum.position = CGPoint(x: 0, y: 8)
        movesBadge.addChild(movesNum)
        movesValueLabel = movesNum

        let movesCap = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        movesCap.text = String(localized: "Moves")
        movesCap.fontSize = 12
        movesCap.fontColor = UIColor(white: 0, alpha: 0.55)
        movesCap.verticalAlignmentMode = .center
        movesCap.horizontalAlignmentMode = .center
        movesCap.position = CGPoint(x: 0, y: -14)
        movesBadge.addChild(movesCap)

        /*
        #if DEBUG
        let tester = makePill(width: 56, height: 24,
                              fill: UIColor(hex: "#0F172A").withAlphaComponent(0.78),
                              stroke: UIColor.white.withAlphaComponent(0.55))
        tester.position = CGPoint(x: rightX - movesBadgeW - 38, y: cardH / 2 - 24)
        tester.name = "levelTesterButton"
        card.addChild(tester)

        let testerLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        testerLabel.text = String(localized: "TEST")
        testerLabel.fontSize = 10
        testerLabel.fontColor = .white
        testerLabel.verticalAlignmentMode = .center
        testerLabel.horizontalAlignmentMode = .center
        testerLabel.name = "levelTesterButton"
        tester.addChild(testerLabel)
        #endif
        */

        // Level title (bolt icon + "Level N")
        let bolt = Icons.sprite(Icons.Name.level, size: 22, tint: UIColor(hex: "#FACC15"))
        bolt.position = CGPoint(x: leftX + 12, y: 14)
        card.addChild(bolt)

        let lvl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        lvl.fontSize = Persistence.largeText ? 30 : 28
        lvl.fontColor = .white
        if levelNumber == Levels.endlessLevel {
            lvl.text = String(localized: "Score Rush")
        } else if levelNumber == Levels.towerLevel {
            let floor = TowerMode.activeRun()?.floor ?? 1
            lvl.text = String(localized: "Floor \(floor)")
        } else {
            lvl.text = String(localized: "Level \(levelNumber)")
        }
        lvl.verticalAlignmentMode = .center
        lvl.horizontalAlignmentMode = .left
        lvl.position = CGPoint(x: leftX + 32, y: 14)
        card.addChild(lvl)
        levelLabel = lvl
        addCrownToLevelLabelIfNeeded(lvl)

        // Score caption + goal pill
        let scoreCap = SKLabelNode(fontNamed: "AvenirNext-Medium")
        scoreCap.text = String(localized: "Score")
        scoreCap.fontSize = 14
        scoreCap.fontColor = UIColor(white: 1, alpha: 0.95)
        scoreCap.verticalAlignmentMode = .center
        scoreCap.horizontalAlignmentMode = .left
        scoreCap.position = CGPoint(x: leftX, y: -22)
        card.addChild(scoreCap)

        let goalPill = makePill(width: 158, height: 28,
                                fill: UIColor(white: 1, alpha: 0.85),
                                stroke: .clear)
        goalPill.position = CGPoint(x: leftX + 50 + 79, y: -22)
        card.addChild(goalPill)

        let target = Icons.sprite(Icons.Name.goal, size: 14, tint: UIColor(hex: "#EF4444"))
        target.position = CGPoint(x: -60, y: 0)
        goalPill.addChild(target)

        let gLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gLabel.fontSize = Persistence.largeText ? 12 : 11
        gLabel.fontColor = UIColor(hex: "#0F172A")
        gLabel.verticalAlignmentMode = .center
        gLabel.horizontalAlignmentMode = .center
        gLabel.position = CGPoint(x: 10, y: 0)
        goalPill.addChild(gLabel)
        goalLabel = gLabel

        // Total
        let totalCap = SKLabelNode(fontNamed: "AvenirNext-Medium")
        totalCap.text = String(localized: "Total")
        totalCap.fontSize = 14
        totalCap.fontColor = UIColor(white: 1, alpha: 0.95)
        totalCap.verticalAlignmentMode = .center
        totalCap.horizontalAlignmentMode = .right
        totalCap.position = CGPoint(x: rightX - 70, y: -22)
        card.addChild(totalCap)

        let totalNum = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        totalNum.fontSize = Persistence.largeText ? 17 : 16
        totalNum.fontColor = .white
        totalNum.verticalAlignmentMode = .center
        totalNum.horizontalAlignmentMode = .right
        totalNum.position = CGPoint(x: rightX, y: -22)
        card.addChild(totalNum)
        totalLabel = totalNum

        // Star progress bar
        let trackW = cardW - 36
        let trackH: CGFloat = 8
        let trackY: CGFloat = -cardH / 2 + 22

        let nextStar = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nextStar.fontSize = Persistence.largeText ? 12 : 11
        nextStar.fontColor = .white.withAlphaComponent(0.92)
        nextStar.verticalAlignmentMode = .center
        nextStar.horizontalAlignmentMode = .center
        nextStar.position = CGPoint(x: 0, y: trackY + 20)
        card.addChild(nextStar)
        starHintLabel = nextStar

        let track = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: trackH / 2)
        track.fillColor = UIColor(white: 1, alpha: 0.25)
        track.strokeColor = .clear
        track.position = CGPoint(x: 0, y: trackY)
        card.addChild(track)
        progressTrack = track

        let fill = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: trackH / 2)
        fill.fillColor = UIColor(hex: "#FBBF24")
        fill.strokeColor = .clear
        fill.position = CGPoint(x: 0, y: trackY)
        fill.xScale = 0.0001
        card.addChild(fill)
        progressFill = fill

        let t = levelConfig.starThresholds
        let starFracs = [t.one, t.two, t.three].map {
            min(1.0, CGFloat($0) / CGFloat(max(1, t.three)))
        }
        for (idx, frac) in starFracs.enumerated() {
            let starNode = makeShinyStar(size: 22)
            let x = -trackW / 2 + trackW * CGFloat(frac)
            starNode.position = CGPoint(x: x, y: trackY)
            starNode.zPosition = 2
            card.addChild(starNode)

            // Stagger the pulse so the trio twinkles like a constellation
            let phase = Double(idx) * 0.45
            starNode.run(.sequence([.wait(forDuration: phase),
                                    .repeatForever(.sequence([
                                        .scale(to: 1.12, duration: 0.9),
                                        .scale(to: 1.0,  duration: 0.9)
                                    ]))]))

            // Occasional sparkle burst (radial dots that grow + fade)
            scheduleSparkle(on: starNode, delay: 1.5 + Double(idx) * 0.7)
        }
    }

    func addCrownToLevelLabelIfNeeded(_ label: SKLabelNode) {
        guard levelNumber >= 100 else { return }

        let crown = Icons.sprite(Icons.Name.crown,
                                 size: 13,
                                 weight: .heavy,
                                 tint: UIColor(hex: "#FACC15"))
        crown.name = "levelCrown"
        crown.position = CGPoint(x: 62, y: 22)
        crown.zPosition = 2
        label.addChild(crown)

        let glow = SKShapeNode(circleOfRadius: 10)
        glow.fillColor = UIColor(hex: "#FACC15").withAlphaComponent(0.22)
        glow.strokeColor = .clear
        glow.position = crown.position
        glow.zPosition = 1
        label.addChild(glow)
    }

    /// Builds a stack: glow halo → main gold star → subtle highlight → tiny sparkle layer.
    func makeShinyStar(size: CGFloat) -> SKNode {
        let container = SKNode()

        // Soft glow halo behind the star
        let halo = SKShapeNode(circleOfRadius: size * 0.78)
        halo.fillColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.45)
        halo.strokeColor = .clear
        halo.glowWidth = 6
        halo.zPosition = -2
        halo.blendMode = .add
        container.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.18, duration: 1.6),
                    .fadeAlpha(to: 0.7, duration: 1.6)]),
            .group([.scale(to: 1.0, duration: 1.6),
                    .fadeAlpha(to: 0.4, duration: 1.6)])
        ])))

        // Main gold star
        let star = SKShapeNode(path: starPath(size: size))
        star.fillColor = UIColor(hex: "#FBBF24")        // warm gold
        star.strokeColor = UIColor(hex: "#B45309")     // amber edge
        star.lineWidth = 1
        star.glowWidth = 0.5
        star.zPosition = 0
        container.addChild(star)

        // Inner highlight — lighter gold, smaller, offset up-left for "lit from above" feel
        let highlight = SKShapeNode(path: starPath(size: size * 0.55))
        highlight.fillColor = UIColor(hex: "#FEF3C7").withAlphaComponent(0.85)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -size * 0.05, y: size * 0.06)
        highlight.zPosition = 1
        container.addChild(highlight)

        return container
    }

    /// 5-pointed star path centered at origin.
    func starPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let outer = size / 2
        let inner = outer * 0.42
        let points = 5
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outer : inner
            let theta = -CGFloat.pi / 2 + CGFloat(i) * (.pi / CGFloat(points))
            let p = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        return path.cgPath
    }

    /// Periodic sparkle: a tiny white dot grows + fades around the star.
    func scheduleSparkle(on node: SKNode, delay: TimeInterval) {
        let action = SKAction.run { [weak self, weak node] in
            guard let self = self, let node = node else { return }
            self.emitSparkle(on: node)
        }
        node.run(.sequence([
            .wait(forDuration: delay),
            .repeatForever(.sequence([
                action,
                .wait(forDuration: 2.0 + Double.random(in: 0...1.2))
            ]))
        ]))
    }

    func emitSparkle(on node: SKNode) {
        let r: CGFloat = 12
        let theta = CGFloat.random(in: 0...(.pi * 2))
        let dot = SKShapeNode(circleOfRadius: 1.6)
        dot.fillColor = .white
        dot.strokeColor = .clear
        dot.glowWidth = 3
        dot.blendMode = .add
        dot.position = CGPoint(x: r * cos(theta) * 0.6,
                               y: r * sin(theta) * 0.6)
        dot.zPosition = 3
        dot.alpha = 0
        dot.setScale(0.3)
        node.addChild(dot)

        dot.run(.sequence([
            .group([
                .scale(to: 1.8, duration: 0.18),
                .fadeAlpha(to: 1.0, duration: 0.1)
            ]),
            .group([
                .scale(to: 0.2, duration: 0.4),
                .fadeOut(withDuration: 0.4)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - HUD: Footer Card

    func buildFooterCard() {
        let cardW = size.width - 24
        let cardH: CGFloat = 180
        let bottomY = -size.height / 2 + safeBottom + 8 + cardH / 2

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.42)
        card.strokeColor = UIColor(white: 1, alpha: 0.55)
        card.lineWidth = 1
        card.position = CGPoint(x: 0, y: bottomY)
        card.zPosition = 50
        addChild(card)
        footerCard = card

        let topRowY = cardH / 2 - 28
        let leftX = -cardW / 2 + 18
        let rightX = cardW / 2 - 18

        // Settings (gear) — light circle, soft slate icon (less aggressive than black)
        let slate = UIColor(hex: "#475569")
        let gear = makeSymbolCircle(symbol: Icons.Name.settings, diameter: 44,
                                    fill: UIColor(white: 1, alpha: 0.95),
                                    iconTint: slate,
                                    iconSize: 18,
                                    weight: .medium)
        gear.position = CGPoint(x: leftX + 22, y: topRowY)
        gear.name = "settingsButton"
        card.addChild(gear)

        let undoCenterX = rightX - 78

        // Cash pill — sized into the space between settings and undo so the
        // top-row buttons never crowd each other on narrow phones.
        let cashLeftLimit = gear.position.x + 34
        let cashRightLimit = undoCenterX - 30
        let cashPillW = max(112, min(150, cashRightLimit - cashLeftLimit))
        let cashPillX = (cashLeftLimit + cashRightLimit) / 2
        let cashPillH: CGFloat = 40

        let cashPillShadow = makePill(width: cashPillW, height: cashPillH,
                                      fill: UIColor(white: 0, alpha: 0.2),
                                      stroke: .clear)
        cashPillShadow.position = CGPoint(x: cashPillX, y: topRowY - 3)
        cashPillShadow.zPosition = -1
        card.addChild(cashPillShadow)

        let cashPill = makePill(width: cashPillW, height: cashPillH,
                                fill: UIColor(white: 1, alpha: 0.97),
                                stroke: UIColor(hex: "#FFD700").withAlphaComponent(0.55))
        cashPill.lineWidth = 1.5
        cashPill.position = CGPoint(x: cashPillX, y: topRowY)
        card.addChild(cashPill)

        // Gold gradient inset (a thin lighter pill on top to fake a soft sheen)
        let sheen = makePill(width: cashPillW - 4, height: cashPillH / 2,
                             fill: UIColor(hex: "#FFFBEB").withAlphaComponent(0.55),
                             stroke: .clear)
        sheen.position = CGPoint(x: 0, y: cashPillH / 4 - 2)
        cashPill.addChild(sheen)

        // Coin icon (gold banknote, prominent)
        let coinHalo = SKShapeNode(circleOfRadius: 14)
        coinHalo.fillColor = UIColor(hex: "#FEF3C7")
        coinHalo.strokeColor = UIColor(hex: "#FFD700").withAlphaComponent(0.5)
        coinHalo.lineWidth = 1
        coinHalo.position = CGPoint(x: -cashPillW / 2 + 22, y: 0)
        cashPill.addChild(coinHalo)

        let cashIcon = Icons.sprite(Icons.Name.cashFilled, size: 16,
                                    weight: .heavy,
                                    tint: UIColor(hex: "#D97706"))
        coinHalo.addChild(cashIcon)

        let cashL = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        cashL.fontSize = 19
        cashL.fontColor = UIColor(hex: "#0F172A")
        cashL.verticalAlignmentMode = .center
        cashL.horizontalAlignmentMode = .center
        cashL.position = CGPoint(x: min(10, cashPillW * 0.09), y: 0)
        cashPill.addChild(cashL)
        cashLabel = cashL

        // Cart — light circle, soft slate icon
        let cart = makeSymbolCircle(symbol: Icons.Name.cart, diameter: 44,
                                    fill: UIColor(white: 1, alpha: 0.95),
                                    iconTint: slate,
                                    iconSize: 18,
                                    weight: .medium)
        cart.position = CGPoint(x: rightX - 22, y: topRowY)
        cart.name = "cartButton"
        card.addChild(cart)

        // Booster row — softer pastel fills, smaller / lighter icons
        let boosters: [(symbol: String, label: String, fill: UIColor,
                        iconSize: CGFloat, iconWeight: UIImage.SymbolWeight,
                        iconTint: UIColor, chip: String, paid: Bool)] = [
            (Icons.Name.hammer,     "Hammer",  UIColor(hex: "#FB923C"), 22, .medium,    .white,                       "88",  true),
            (Icons.Name.swap,       "Swap",    UIColor(hex: "#FACC15"), 18, .regular,   UIColor(hex: "#1E293B"),      "130", true),
            (Icons.Name.shuffle,    "Shuffle", UIColor(hex: "#7DD3FC"), 22, .semibold,  .white,                       "2",   false),
            (Icons.Name.extraMoves, "+Moves",  UIColor(hex: "#F9A8D4"), 22, .heavy,     UIColor(hex: "#FACC15"),      "\(movesBuyCost)", true),
            (Icons.Name.life,       "Life",    UIColor(hex: "#F9A8D4"), 20, .heavy,     UIColor(hex: "#EF4444"),      "152", true)
        ]

        let cellW = (cardW - 24) / CGFloat(boosters.count)
        let circleD: CGFloat = 52
        let rowY: CGFloat = -cardH / 2 + 56

        for (i, b) in boosters.enumerated() {
            let cx = -cardW / 2 + 12 + cellW * (CGFloat(i) + 0.5)

            // Drop shadow under circle
            let shadow = SKShapeNode(circleOfRadius: circleD / 2)
            shadow.fillColor = UIColor(white: 0, alpha: 0.18)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: cx, y: rowY + 8)
            shadow.zPosition = 1
            card.addChild(shadow)

            let circle = SKShapeNode(circleOfRadius: circleD / 2)
            circle.fillColor = b.fill
            circle.strokeColor = .clear
            circle.position = CGPoint(x: cx, y: rowY + 12)
            circle.zPosition = 2
            circle.name = "booster:\(b.label)"
            boosterCircles[b.label] = circle
            circle.isAccessibilityElement = true
            circle.accessibilityLabel = b.label
            circle.accessibilityTraits = .button
            if b.label == "+Moves" {
                movesBoosterCircle = circle
            }
            card.addChild(circle)

            let icon = Icons.sprite(b.symbol, size: b.iconSize, weight: b.iconWeight, tint: b.iconTint)
            circle.addChild(icon)

            // Quantity badge — only on the +Moves booster. Shows currently selected
            // quantity (e.g. "+5"); tapping opens the picker popup.
            if b.label == "+Moves" {
                let badgeW: CGFloat = 28
                let badgeH: CGFloat = 18
                let badge = SKShapeNode(rectOf: CGSize(width: badgeW, height: badgeH), cornerRadius: badgeH / 2)
                badge.fillColor = UIColor(hex: "#22C55E")
                badge.strokeColor = .white
                badge.lineWidth = 1.2
                badge.position = CGPoint(x: circleD / 2 - 2, y: circleD / 2 - 2)
                badge.zPosition = 3
                badge.name = "movesQuantityBadge"
                circle.addChild(badge)
                movesQuantityBadge = badge

                badge.run(.repeatForever(.sequence([
                    .scale(to: 1.12, duration: 0.7),
                    .scale(to: 1.0, duration: 0.7)
                ])))

                let badgeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                badgeLabel.text = "+\(movesQuantity)"
                badgeLabel.fontSize = 11
                badgeLabel.fontColor = .white
                badgeLabel.verticalAlignmentMode = .center
                badgeLabel.horizontalAlignmentMode = .center
                badge.addChild(badgeLabel)
                movesQuantityBadgeLabel = badgeLabel
            }

            // Chip below circle
            let chipW: CGFloat = b.paid ? max(54, CGFloat(b.chip.count) * 9 + 28) : 30
            let chipH: CGFloat = 18
            let chip = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: chipH / 2)
            chip.fillColor = b.paid ? UIColor(white: 0, alpha: 0.7) : UIColor(white: 1, alpha: 0.85)
            chip.strokeColor = .clear
            chip.position = CGPoint(x: cx, y: rowY - 18)
            card.addChild(chip)

            if b.paid {
                // Programmatic gold coin — bypass SF Symbol multicolor weirdness
                let coin = SKShapeNode(circleOfRadius: 7)
                coin.fillColor = UIColor(hex: "#FFD700")
                coin.strokeColor = UIColor(hex: "#D97706")
                coin.lineWidth = 1
                coin.position = CGPoint(x: -16, y: 0)
                chip.addChild(coin)

                let dollar = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                dollar.text = "$"
                dollar.fontSize = 9
                dollar.fontColor = UIColor(hex: "#7C2D12")
                dollar.verticalAlignmentMode = .center
                dollar.horizontalAlignmentMode = .center
                coin.addChild(dollar)

                let chipL = SKLabelNode(fontNamed: "AvenirNext-Bold")
                chipL.text = b.chip
                chipL.fontSize = 11
                chipL.fontColor = .white
                chipL.verticalAlignmentMode = .center
                chipL.horizontalAlignmentMode = .center
                chipL.position = CGPoint(x: 6, y: 0)
                chip.addChild(chipL)
            } else {
                let chipL = SKLabelNode(fontNamed: "AvenirNext-Bold")
                chipL.text = b.chip
                chipL.fontSize = 11
                chipL.fontColor = UIColor(hex: "#0F172A")
                chipL.verticalAlignmentMode = .center
                chipL.horizontalAlignmentMode = .center
                chip.addChild(chipL)
            }

            // Booster name
            let nameL = SKLabelNode(fontNamed: "AvenirNext-Bold")
            nameL.text = b.label
            nameL.fontSize = 11
            nameL.fontColor = .white
            nameL.verticalAlignmentMode = .center
            nameL.horizontalAlignmentMode = .center
            nameL.position = CGPoint(x: cx, y: rowY - 38)
            card.addChild(nameL)
        }
    }

    // MARK: - HUD helpers

    func makePill(width: CGFloat, height: CGFloat, fill: UIColor, stroke: UIColor) -> SKShapeNode {
        let pill = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        pill.fillColor = fill
        pill.strokeColor = stroke
        pill.lineWidth = stroke == .clear ? 0 : 1
        return pill
    }

    func makeSymbolCircle(symbol: String, diameter: CGFloat, fill: UIColor,
                                  iconTint: UIColor, iconSize: CGFloat,
                                  weight: UIImage.SymbolWeight = .bold) -> SKNode {
        let node = SKNode()
        let bg = SKShapeNode(circleOfRadius: diameter / 2)
        bg.fillColor = fill
        bg.strokeColor = .clear
        node.addChild(bg)
        let icon = Icons.sprite(symbol, size: iconSize, weight: weight, tint: iconTint)
        node.addChild(icon)
        return node
    }

    func updateHUD() {
        movesValueLabel?.text = "\(movesLeft)"
        goalLabel?.text = goalProgressText()
        starHintLabel?.text = nextStarText()
        let countdown = Persistence.nextLifeCountdownText
        livesLabel?.text = countdown.isEmpty ? "\(lives)/\(livesMax)" : "\(lives)/\(livesMax) \(countdown)"
        totalLabel?.text = "\(totalScore)"
        cashLabel?.text = "\(cash)"

        // VoiceOver: combine each caption + value into one spoken readout so the
        // header is meaningful with the screen reader on.
        applyHUDAccessibility()

        if let track = progressTrack, let fill = progressFill {
            let frac = CGFloat(LevelScoring.meterProgress(for: levelConfig,
                                                          performance: currentPerformance(),
                                                          objectiveComplete: isLevelGoalComplete))
            let trackW = track.frame.width
            fill.removeAllActions()
            fill.run(.scaleX(to: max(0.0001, frac), duration: 0.18))
            fill.position.x = -trackW / 2 + trackW * frac / 2
        }
    }

    /// Marks the header readouts as accessibility elements and gives each a
    /// spoken label that merges its caption with its current value.
    func applyHUDAccessibility() {
        movesValueLabel?.isAccessibilityElement = true
        movesValueLabel?.accessibilityLabel = String(localized: "Moves left: \(movesLeft)")

        goalLabel?.isAccessibilityElement = true
        goalLabel?.accessibilityLabel = String(localized: "Goal: \(goalProgressText())")

        starHintLabel?.isAccessibilityElement = true
        starHintLabel?.accessibilityLabel = nextStarText()

        livesLabel?.isAccessibilityElement = true
        livesLabel?.accessibilityLabel = String(localized: "Lives: \(lives) of \(livesMax)")

        totalLabel?.isAccessibilityElement = true
        totalLabel?.accessibilityLabel = String(localized: "Total score: \(totalScore)")

        cashLabel?.isAccessibilityElement = true
        cashLabel?.accessibilityLabel = String(localized: "Coins: \(cash)")

        comboMeterTrack?.isAccessibilityElement = true
        let bossStatus = levelConfig.isBoss
            ? String(localized: ", crown shield \(bossShieldRemaining) of \(bossShieldMaximum)")
            : ""
        let flowStatus = flowLevel > 0
            ? String(localized: ", Flow \(flowLevel) of \(TurnMasteryPolicy.maximumFlow)")
            : ""
        let rushStatus = sugarRushCharged ? ", " + String(localized: "SUGAR RUSH READY") : ""
        let targetingStatus: String
        if smashTargeting, let tier = selectedSmashTier {
            let instruction = smashPreviewTarget == nil
                ? String(localized: "TAP A TILE")
                : String(localized: "TAP AGAIN TO SMASH")
            targetingStatus = ", " + tier.title + " " + instruction
        } else {
            targetingStatus = ""
        }
        comboMeterTrack?.accessibilityLabel = String(localized: "Smash charge \(smashCharge) percent\(bossStatus)")
            + flowStatus + rushStatus + targetingStatus
    }

    func goalProgressText() -> String {
        let primary: String
        switch levelConfig.goal {
        case .score:
            primary = "\(min(score, scoreTarget)) / \(scoreTarget)"
        case .clearBlockers:
            primary = String(localized: "Blockers \(max(0, startingBlockers - remainingBlockerCount()))/\(max(1, startingBlockers))")
        case .collectColor(let index, let count):
            primary = "\(LevelGoal.fruitName(for: index)) \(min(collectedGoalTiles, count))/\(count)"
        case .createSpecials(let count):
            primary = String(localized: "Specials \(min(createdSpecials, count))/\(count)")
        case .detonateBombs(let count):
            primary = String(localized: "Bombs \(min(detonatedBombs, count))/\(count)")
        case .collectIngredients(let count):
            primary = String(localized: "Baskets \(min(collectedIngredients, count))/\(count)")
        case .collectKeys(let count):
            primary = String(localized: "Keys \(min(collectedKeys, count))/\(count)")
        case .openChests(let count):
            primary = String(localized: "Chests \(min(openedChests, count))/\(count)")
        case .collectIngredientsAndKeys(let ingredients, let keys):
            primary = String(localized: "Baskets \(min(collectedIngredients, ingredients))/\(ingredients)  Keys \(min(collectedKeys, keys))/\(keys)")
        }
        guard levelConfig.isBoss else { return primary }
        return primary + String(localized: "  Crown \(bossShieldRemaining)/\(bossShieldMaximum)")
    }

    func nextStarText() -> String {
        LevelScoring.nextStarText(for: levelConfig,
                                  performance: currentPerformance(),
                                  objectiveComplete: isLevelGoalComplete)
    }

    func currentPerformance(effectiveMovesLeft: Int? = nil) -> LevelAttemptPerformance {
        LevelAttemptPerformance(score: score,
                                movesLeft: effectiveMovesLeft ?? max(0, movesLeft),
                                movesAtStart: movesAtStart,
                                maxCascadeDepth: maxCascadeDepth,
                                createdSpecials: createdSpecials,
                                detonatedBombs: detonatedBombs,
                                objectiveProgress: currentObjectiveProgress())
    }

    func currentObjectiveProgress() -> Double {
        LevelScoring.objectiveProgress(for: levelConfig,
                                       score: score,
                                       startingBlockers: startingBlockers,
                                       remainingBlockers: remainingBlockerCount(),
                                       collectedGoalTiles: collectedGoalTiles,
                                       createdSpecials: createdSpecials,
                                       detonatedBombs: detonatedBombs,
                                       collectedIngredients: collectedIngredients,
                                       collectedKeys: collectedKeys,
                                       openedChests: openedChests)
    }
}
