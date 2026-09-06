import SpriteKit

extension GameScene {
    func buildHeaderCard() {
        childNode(withName: "premiumTopHUD")?.removeFromParent()
        headerCard?.removeFromParent()
        objectiveLabels.removeAll()
        premiumStarNodes.removeAll()
        let layout = gameplayLayout
        let s = layout.levelCard.height / 140
        let w = layout.levelCard.width
        let top = SKNode()
        top.name = "premiumTopHUD"
        top.position = CGPoint(x: 0, y: layout.brand.midY)
        top.zPosition = 60
        addChild(top)

        let logo = GameArt.sprite("sugar_shift_logo", fitting: CGSize(width: w * 0.38, height: 77 * s))
        logo.name = "brandLogo"
        logo.position = CGPoint(x: 0, y: 22 * s)
        top.addChild(logo)
        let pillW = w * 0.29
        func economyPill(name: String, x: CGFloat, icon: String, pink: Bool) -> SKLabelNode {
            let pill = GameSurface.panel(size: CGSize(width: pillW, height: 29 * s), top: UIColor(hex: "#294B70"), bottom: UIColor(hex: "#132B4B"), radius: 14 * s, rim: UIColor(hex: "#D8F7EF"))
            pill.position = CGPoint(x: x, y: 23 * s)
            pill.name = name
            top.addChild(pill)
            let image = GameArt.sprite(icon, fitting: CGSize(width: 34 * s, height: 34 * s))
            image.position.x = -pillW / 2 + 10 * s
            pill.addChild(image)
            if pink {
                let count = GameSurface.label(size: 16 * s, color: .white)
                count.name = "lifeCount"
                count.position = CGPoint(x: image.position.x, y: -1 * s)
                count.zPosition = 2
                pill.addChild(count)
            }
            let label = GameSurface.label(size: 11 * s, color: .white)
            label.position.x = pink ? 4 * s : 1 * s
            pill.addChild(label)
            let plus = GameSurface.panel(size: CGSize(width: 25 * s, height: 25 * s), top: UIColor(hex: "#A7EC53"), bottom: UIColor(hex: "#39A22F"), radius: 7 * s)
            plus.position.x = pillW / 2 - 8 * s
            plus.addChild(GameSurface.label("+", size: 22 * s, color: .white))
            pill.addChild(plus)
            return label
        }
        livesLabel = economyPill(name: "booster:Life", x: -w / 2 + pillW / 2, icon: "fruit_heart", pink: true)
        cashLabel = economyPill(name: "cartButton", x: w / 2 - pillW / 2, icon: "ui_coin", pink: false)
        let gear = GameArt.sprite("ui_settings", fitting: CGSize(width: 34 * s, height: 34 * s))
        gear.position = CGPoint(x: w / 2 - 14 * s, y: -14 * s)
        gear.name = "settingsButton"
        top.addChild(gear)
        #if DEBUG
        // Keep the existing level tester reachable after the HUD redesign.
        let levelPicker = SKSpriteNode(color: .clear, size: CGSize(width: 80 * s, height: 44))
        levelPicker.name = "levelTesterButton"
        levelPicker.position = CGPoint(x: -w / 2 + 42 * s, y: -17 * s)
        let pickerSurface = GameSurface.panel(size: CGSize(width: 80 * s, height: 27 * s),
            top: UIColor(hex: "#9866CB"), bottom: UIColor(hex: "#503085"), radius: 9 * s)
        pickerSurface.addChild(GameSurface.label("Levels ▾", size: 12 * s, color: .white))
        levelPicker.addChild(pickerSurface)
        top.addChild(levelPicker)
        #endif
        let sign = WorldHUDDecoration.sign(theme: worldTheme, size: CGSize(width: 89 * s, height: 45 * s))
        sign.name = "worldSign"
        sign.position = CGPoint(x: w / 2 - 48 * s, y: -layout.brand.height / 2 + 9 * s)
        sign.zRotation = 0.12
        top.addChild(sign)
        // Keep settings reachable beside the logo, clear of the world sign.
        gear.position = CGPoint(x: w / 2 - 16 * s, y: 51 * s)
        gear.size = CGSize(width: 22 * s, height: 22 * s)

        let ice = worldTheme.id == "ice"
        let ink = UIColor(hex: worldTheme.cardPalette.ink)
        let card = SKShapeNode()
        card.name = "levelCard"
        card.position = CGPoint(x: 0, y: layout.levelCard.midY)
        card.zPosition = 50
        card.addChild(GameplayHUDArt.card(size: layout.levelCard.size, ice: ice, theme: worldTheme))
        if ice {
            for (x, width) in [(-w * 0.29, w * 0.43), (w * 0.31, w * 0.37)] {
                let cap = WorldHUDDecoration.snowCap(size: CGSize(width: width, height: 28 * s))
                cap.position = CGPoint(x: x, y: layout.levelCard.height / 2 - 4 * s)
                cap.zPosition = 1
                card.addChild(cap)
            }
        } else {
            let icing = GameplayHUDArt.icing(size: CGSize(width: w * 0.39, height: 49 * s), ice: false, color: worldTheme.cardPalette.trim)
            icing.position = CGPoint(x: -w * 0.305 + 3 * s, y: layout.levelCard.height / 2 - 22 * s)
            icing.zPosition = 1
            card.addChild(icing)
        }
        addChild(card)
        headerCard = card
        let left = -w / 2 + 21 * s
        let title = levelNumber == Levels.endlessLevel ? String(localized: "Score Rush") : levelNumber == Levels.towerLevel ? String(localized: "Floor \(TowerMode.activeRun()?.floor ?? 1)") : String(localized: "Level \(levelNumber)")
        let level = GameSurface.label(title, size: 23 * s, color: ink)
        level.horizontalAlignmentMode = .left
        level.position = CGPoint(x: left, y: 39 * s)
        card.addChild(level)
        levelLabel = level
        let dividerX = w / 2 - 108 * s
        if levelConfig.difficulty != .normal {
            let badgeText = NSLocalizedString(levelConfig.difficulty.rawValue.uppercased(), comment: "Level difficulty")
            let badge = GameSurface.panel(size: CGSize(width: 47 * s, height: 18 * s),
                top: UIColor(hex: "#FF787E"), bottom: UIColor(hex: "#FF306A"), radius: 9 * s)
            badge.name = "difficultyBadge"
            badge.addChild(GameSurface.label(badgeText, size: 9 * s, color: .white))
            badge.position = CGPoint(x: min(dividerX - 30 * s, level.frame.maxX + 30 * s), y: 39 * s)
            let maxTitleWidth = badge.position.x - 27 * s - left
            if level.frame.width > maxTitleWidth { level.xScale = maxTitleWidth / level.frame.width }
            card.addChild(badge)
        }
        let cap = GameSurface.label(String(localized: "Collect & Clear:"), size: 11 * s, color: ink)
        cap.fontName = "AvenirNext-Bold"
        cap.horizontalAlignmentMode = .left
        cap.position = CGPoint(x: left, y: 19 * s)
        card.addChild(cap)
        goalLabel = cap
        let goalW = dividerX - left - 7 * s
        let strip = SKShapeNode(rectOf: CGSize(width: goalW + 9 * s, height: 43 * s), cornerRadius: 12 * s)
        strip.name = "objectiveStrip"
        strip.position = CGPoint(x: left + goalW / 2 - 2 * s, y: -10 * s)
        strip.fillColor = UIColor.white.withAlphaComponent(0.30)
        strip.strokeColor = .clear
        card.addChild(strip)
        let objectives = displayedHUDObjectives
        let count = max(1, objectives.count)
        let itemW = goalW / CGFloat(count)
        let iconSize = min(38 * s, itemW * 0.50)
        for (index, objective) in objectives.enumerated() {
            let item = SKNode()
            item.name = "objective:\(index)"
            item.position = CGPoint(x: left + CGFloat(index) * itemW, y: -10 * s)
            let icon = makeHUDObjectiveIcon(objective, size: iconSize)
            icon.position.x = iconSize / 2
            item.addChild(icon)
            let value = GameSurface.label(size: min(11.5 * s, itemW * 0.18), color: ink)
            value.fontName = "AvenirNext-Bold"
            value.horizontalAlignmentMode = .left
            value.position.x = iconSize + 2 * s
            item.addChild(value)
            objectiveLabels.append(value)
            // A single goal uses a compact icon + value + caption, with no empty slot.
            if count == 1 {
                value.fontSize = 16 * s
                value.position.y = 6 * s
                let description = GameSurface.label(objective.accessibilityTitle, size: 9 * s, color: ink.withAlphaComponent(0.76))
                description.fontName = "AvenirNext-DemiBold"
                description.horizontalAlignmentMode = .left
                description.position = CGPoint(x: value.position.x, y: -10 * s)
                let maxWidth = goalW - value.position.x - 5 * s
                if description.frame.width > maxWidth { description.setScale(maxWidth / description.frame.width) }
                item.addChild(description)
            }
            card.addChild(item)
        }
        let divider = SKShapeNode(rectOf: CGSize(width: 1 * s, height: 60 * s), cornerRadius: 0.5 * s)
        divider.position = CGPoint(x: dividerX, y: 14 * s)
        divider.fillColor = UIColor(hex: ice ? "#6EC3EA" : "#E5A395").withAlphaComponent(0.6)
        divider.strokeColor = .clear
        card.addChild(divider)
        let moves = GameplayHUDArt.card(size: CGSize(width: 89 * s, height: 82 * s), ice: ice, inset: true, theme: worldTheme)
        moves.name = "movesInset"
        moves.position = CGPoint(x: w / 2 - 55 * s, y: 17 * s)
        card.addChild(moves)
        let movesInk = UIColor(hex: ice ? "#152274" : "#340B4F")
        let movesCap = GameSurface.label(String(localized: "Moves"), size: 13 * s, color: movesInk)
        movesCap.fontName = "AvenirNext-Bold"
        movesCap.position.y = 22 * s
        moves.addChild(movesCap)
        movesValueLabel = GameSurface.label(size: 43 * s, color: movesInk)
        movesValueLabel.position.y = -8 * s
        moves.addChild(movesValueLabel)
        let trackW = w - 59 * s
        progressTrack = SKShapeNode(rectOf: CGSize(width: trackW, height: 14 * s), cornerRadius: 7 * s)
        progressTrack.position = CGPoint(x: 0, y: -43 * s)
        progressTrack.fillColor = UIColor(hex: ice ? "#7C9CB7" : "#9B8290")
        progressTrack.strokeColor = UIColor(hex: ice ? "#DAF8FF" : "#F8E7DC")
        progressTrack.lineWidth = 1.2 * s
        card.addChild(progressTrack)
        // The gradient is revealed by a mask; the rounded end remains rounded.
        progressFill = SKShapeNode()
        progressFill.fillColor = .white
        progressFill.strokeColor = .clear
        let crop = SKCropNode()
        crop.name = "scoreFill"
        crop.position = progressTrack.position
        crop.maskNode = progressFill
        crop.addChild(GameplayHUDArt.progress(size: CGSize(width: trackW, height: 14 * s)))
        card.addChild(crop)
        for stop in HUDScoreProgress.starStops {
            let star = makeProgressStar(size: 29 * s)
            star.position = CGPoint(x: -trackW / 2 + trackW * stop, y: progressTrack.position.y)
            star.zPosition = 3
            card.addChild(star)
            premiumStarNodes.append(star)
        }
        starHintLabel = GameSurface.label(size: 8 * s)
        starHintLabel.isHidden = true
        card.addChild(starHintLabel)
        totalLabel = GameSurface.label(size: 11.5 * s, color: ink)
        totalLabel.fontName = "AvenirNext-Bold"
        totalLabel.position = CGPoint(x: 0, y: -61 * s)
        card.addChild(totalLabel)
        // A few fixed glints catch the icing and card edge without visual noise.
        for (x, y, radius) in [(left - 8 * s, -43 * s, 2.3 * s), (dividerX - 17 * s, 36 * s, 2.5 * s)] {
            let glint = SKShapeNode(path: UIBezierPath(ovalIn: CGRect(x: -radius / 3, y: -radius, width: radius * 2 / 3, height: radius * 2)).cgPath)
            glint.fillColor = UIColor.white.withAlphaComponent(0.85)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: x, y: y)
            card.addChild(glint)
            let cross = glint.copy() as! SKShapeNode
            cross.zRotation = .pi / 2
            card.addChild(cross)
        }
    }

    func buildFooterCard() {
        footerCard?.removeFromParent()
        childNode(withName: "premiumNavigation")?.removeFromParent()
        boosterCircles.removeAll()
        boosterPriceLabels.removeAll()
        let layout = gameplayLayout
        let s = layout.boosters.height / 88
        let w = layout.boosters.width
        let card = SKShapeNode()
        card.position = CGPoint(x: 0, y: layout.boosters.midY)
        card.zPosition = 50
        card.addChild(GameSurface.panel(size: layout.boosters.size, top: UIColor(hex: "#D3F6FF").withAlphaComponent(0.50), bottom: UIColor(hex: "#214778").withAlphaComponent(0.62), radius: 20 * s))
        addChild(card)
        footerCard = card
        let definitions = [("Hammer", "hammer", "#00B7FF"), ("Swap", "swap", "#A93AFF"), ("Shuffle", "shuffle", "#19DB48"), ("+Moves", "moves", "#FA27CC"), ("Life", "life", "#FFC928")]
        let cellW = (w - 16 * s) / 5
        let diameter = min(58 * s, cellW - 5 * s)
        for (index, entry) in definitions.enumerated() {
            let x = -w / 2 + 8 * s + cellW * (CGFloat(index) + 0.5)
            let circle = SKShapeNode(circleOfRadius: diameter / 2)
            circle.fillColor = .clear
            circle.strokeColor = .clear
            circle.position = CGPoint(x: x, y: 9 * s)
            circle.name = "booster:\(entry.0)"
            let halo = SKShapeNode(circleOfRadius: diameter / 2 - 1 * s)
            halo.fillColor = UIColor(hex: entry.2).withAlphaComponent(0.2)
            halo.strokeColor = UIColor(hex: entry.2).withAlphaComponent(0.8)
            halo.lineWidth = 1.5 * s
            halo.glowWidth = 4 * s
            circle.addChild(halo)
            circle.addChild(GameplayHUDArt.orb(diameter: diameter, color: entry.2))
            circle.addChild(GameArt.sprite("booster_\(entry.1)", fitting: CGSize(width: diameter * 0.82, height: diameter * 0.82)))
            circle.isAccessibilityElement = true
            circle.accessibilityLabel = NSLocalizedString(entry.0, comment: "Booster")
            circle.accessibilityTraits = .button
            card.addChild(circle)
            boosterCircles[entry.0] = circle
            if entry.0 == "+Moves" {
                movesBoosterCircle = circle
                let badge = makePill(width: 24 * s, height: 17 * s, fill: UIColor(hex: "#42C565"), stroke: .white)
                badge.name = "movesQuantityBadge"
                badge.position = CGPoint(x: diameter / 2 - 3 * s, y: diameter / 2 - 2 * s)
                badge.zPosition = 4
                let badgeLabel = GameSurface.label("+\(movesQuantity)", size: 10 * s, color: .white)
                badge.addChild(badgeLabel)
                movesQuantityBadgeLabel = badgeLabel
                circle.addChild(badge)
                movesQuantityBadge = badge
            }
            let chip = makePill(width: 34 * s, height: 20 * s, fill: UIColor(hex: "#E71D5B"), stroke: UIColor.white.withAlphaComponent(0.95))
            chip.position = CGPoint(x: x + diameter * 0.25, y: -12 * s)
            chip.zPosition = 5
            let value = GameSurface.label(size: 10 * s, color: .white)
            chip.addChild(value)
            card.addChild(chip)
            boosterPriceLabels[entry.0] = value
            let label = GameSurface.label(NSLocalizedString(entry.0, comment: "Booster"), size: 11 * s, color: .white)
            label.fontName = "AvenirNext-Bold"
            label.position = CGPoint(x: x, y: -32 * s)
            card.addChild(label)
        }
        let nav = SKNode()
        nav.name = "premiumNavigation"
        nav.position = CGPoint(x: 0, y: layout.navigation.midY)
        nav.zPosition = 55
        addChild(nav)
        for (name, text, x, icon) in [("mapButton", String(localized: "Map"), -w * 0.31, "ui_map"), ("playButton", String(localized: "PLAY"), CGFloat(0), ""), ("cartButton", String(localized: "Shop"), w * 0.31, "ui_shop")] {
            let play = name == "playButton"
            let button = GameSurface.panel(size: CGSize(width: (play ? 134 : 82) * s, height: (play ? 45 : 38) * s), top: UIColor(hex: play ? "#FF8CBD" : "#E9FFE1"), bottom: UIColor(hex: play ? "#D91A74" : "#63A980"), radius: 18 * s, rim: UIColor(hex: "#FFE6B8"))
            button.name = name
            button.position = CGPoint(x: x, y: play ? 2 * s : -2 * s)
            if !play {
                let art = GameArt.sprite(icon, fitting: CGSize(width: 32 * s, height: 30 * s))
                art.position = CGPoint(x: -22 * s, y: 3 * s)
                button.addChild(art)
            }
            let label = GameSurface.label(text, size: (play ? 21 : 13) * s, color: .white)
            label.position.x = play ? 0 : 12 * s
            button.addChild(label)
            nav.addChild(button)
        }
    }

    func updatePremiumHUD() {
        let moveText = "\(movesLeft)"
        if movesValueLabel?.text != moveText {
            movesValueLabel?.text = moveText
            if !Persistence.reduceMotion {
                movesValueLabel?.run(.sequence([.scale(to: 1.12, duration: 0.08), .scale(to: 1, duration: 0.13)]), withKey: "counterPop")
            }
        }
        let currentLives = Persistence.lives
        livesLabel?.text = currentLives >= livesMax ? String(localized: "FULL") : Persistence.nextLifeCountdownText
        (childNode(withName: "//lifeCount") as? SKLabelNode)?.text = "\(currentLives)"
        cashLabel?.text = cash.formatted()
        totalLabel?.text = String(localized: "Score: \(score.formatted())")
        starHintLabel?.text = nextStarText()
        for (index, objective) in displayedHUDObjectives.enumerated() where index < objectiveLabels.count {
            let progress = hudProgress(for: objective)
            objectiveLabels[index].text = "\(progress.current)/\(progress.target)"
            objectiveLabels[index].fontColor = progress.isComplete ? UIColor(hex: worldTheme.id == "galaxy" ? "#C9FFAF" : "#267632") : UIColor(hex: worldTheme.cardPalette.ink)
            objectiveLabels[index].accessibilityLabel = objective.accessibilityTitle + " \(progress.current) / \(progress.target)"
            objectiveLabels[index].isAccessibilityElement = true
        }
        boosterPriceLabels["Hammer"]?.text = hammerCount > 0 ? "×\(hammerCount)" : "● \(hammerCost)"
        boosterPriceLabels["Swap"]?.text = swapCount > 0 ? "×\(swapCount)" : "● \(swapCost)"
        boosterPriceLabels["Shuffle"]?.text = "×\(shuffleCount)"
        boosterPriceLabels["+Moves"]?.text = "● \(movesBuyCost)"
        boosterPriceLabels["Life"]?.text = currentLives >= livesMax ? String(localized: "FULL") : "● \(lifeCost)"
        let thresholds = levelConfig.starThresholds
        let earned = [thresholds.one, thresholds.two, thresholds.three].filter { score >= $0 }.count
        for (index, star) in premiumStarNodes.enumerated() {
            star.childNode(withName: "starEarned")?.isHidden = index >= earned
            star.childNode(withName: "starEmpty")?.isHidden = index < earned
            if index >= lastDisplayedStars && index < earned && !Persistence.reduceMotion {
                star.run(.sequence([.scale(to: 1.4, duration: 0.12), .scale(to: 1, duration: 0.22)]))
                emitSparkle(on: star)
                Audio.shared.play(.smashReady)
                Effects.haptic(.medium)
            }
        }
        lastDisplayedStars = earned
        if let track = progressTrack, let fill = progressFill, let path = track.path {
            let width = path.boundingBox.width
            let fraction = HUDScoreProgress.fraction(score: score, thresholds: thresholds)
            let height = path.boundingBox.height
            fill.isHidden = fraction == 0
            fill.path = UIBezierPath(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: max(0.01, width * fraction), height: height), cornerRadius: height / 2).cgPath
        }
        applyHUDAccessibility()
        #if DEBUG
        updateUITestReadout()
        #endif
    }
}

extension LevelObjective {
    var artName: String {
        switch self {
        case .collectPieces(let color, _): return "fruit_\(color.rawValue)"
        case .breakIce: return "blocker_ice_01"
        case .clearJelly: return "blocker_jelly_01"
        case .collectKeys: return "blocker_key"
        case .clearChocolate: return "blocker_chocolate"
        case .destroySpecificBlocker(let type, _): return BoardRenderer.blockerAsset(Blocker(type: type, hits: 1))
        case .freePieces: return "blocker_cage"
        case .breakBlockers: return "blocker_crate"
        case .collectIngredients: return "fruit_strawberry"
        case .reachScore: return "ui_coin"
        default: return "special_color_bomb"
        }
    }
    var accessibilityTitle: String {
        switch self {
        case .collectPieces(let color, _): return NSLocalizedString(color.rawValue, comment: "Objective fruit")
        case .breakIce: return String(localized: "Break ice")
        case .clearJelly: return String(localized: "Clear jelly")
        case .collectKeys: return String(localized: "Collect keys")
        case .reachScore: return String(localized: "Score")
        case .createSpecials: return String(localized: "Create specials")
        case .detonateBombs: return String(localized: "Detonate bombs")
        case .clearChocolate: return String(localized: "Clear chocolate")
        case .collectIngredients: return String(localized: "Collect ingredients")
        case .freePieces: return String(localized: "Free trapped fruit")
        case .breakBlockers: return String(localized: "Clear blockers")
        case .destroySpecificBlocker(let type, _):
            switch type {
            case .ice: return String(localized: "Break ice")
            case .jelly: return String(localized: "Clear jelly")
            case .lock, .colorLock, .cage: return String(localized: "Unlock fruit")
            case .chocolate: return String(localized: "Clear chocolate")
            case .chest: return String(localized: "Open chests")
            default: return NSLocalizedString(type.rawValue.capitalized, comment: "Objective blocker")
            }
        case .breakBossShield: return String(localized: "Break crown shield")
        case .comboObjective: return String(localized: "Build a cascade")
        default: return String(localized: "Clear objectives")
        }
    }
}
