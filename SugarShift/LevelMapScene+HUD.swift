import SpriteKit

// HUD top bar + bottom bar
extension LevelMapScene {
    // MARK: - HUD (top bar)

    func buildHUD() {
        hud = SKNode()
        hud.zPosition = 1000
        addChild(hud)

        let cardW = size.width - 24
        let cardH = hudCardHeight
        let topY = hudCenterY

        // An opaque cap above the HUD so scrolling level dots can't show through
        // the safe-area when content overshoots upward.
        let topCap = SKShapeNode(rectOf: CGSize(width: size.width + 6,
                                                 height: cardH + 80))
        topCap.fillColor = UIColor(hex: "#FCE7F3")
        topCap.strokeColor = .clear
        topCap.position = CGPoint(x: 0, y: topY + 30)
        topCap.zPosition = -1
        hud.addChild(topCap)

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH),
                                cornerRadius: cardH / 2)
        card.fillColor = .white
        card.strokeColor = UIColor(hex: "#FBCFE8")
        card.lineWidth = 2
        card.position = CGPoint(x: 0, y: topY)
        hud.addChild(card)

        let leftX  = -cardW / 2 + 12
        let rightX =  cardW / 2 - 12

        // Lives pill
        let livesPillW: CGFloat = 124
        let livesPill = SKShapeNode(rectOf: CGSize(width: livesPillW, height: 36),
                                     cornerRadius: 18)
        livesPill.fillColor = UIColor.white
        livesPill.strokeColor = UIColor(hex: "#FBCFE8")
        livesPill.lineWidth = 1.5
        livesPill.position = CGPoint(x: leftX + livesPillW / 2 + 8, y: 0)
        card.addChild(livesPill)

        let heart = Icons.sprite(Icons.Name.life, size: 16, tint: UIColor(hex: "#EC4899"))
        heart.position = CGPoint(x: -livesPillW / 2 + 16, y: 1)
        livesPill.addChild(heart)

        let livesL = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        livesL.fontSize = 14
        livesL.fontColor = UIColor(hex: "#BE185D")
        livesL.verticalAlignmentMode = .center
        livesL.horizontalAlignmentMode = .left
        livesL.position = CGPoint(x: -livesPillW / 2 + 30, y: 0)
        livesPill.addChild(livesL)
        livesLabel = livesL

        // Cash pill
        let cashPillW: CGFloat = 92
        let cashPill = SKShapeNode(rectOf: CGSize(width: cashPillW, height: 36),
                                    cornerRadius: 18)
        cashPill.fillColor = UIColor.white
        cashPill.strokeColor = UIColor(hex: "#FCD9C8")
        cashPill.lineWidth = 1.5
        cashPill.position = CGPoint(x: rightX - 48 - cashPillW / 2, y: 0)
        cashPill.name = "hudShop"
        card.addChild(cashPill)

        let bar = makeGoldBarShape(size: 22)
        bar.position = CGPoint(x: -cashPillW / 2 + 18, y: 1)
        cashPill.addChild(bar)

        let cashL = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        cashL.fontSize = 16
        cashL.fontColor = UIColor(hex: "#92400E")
        cashL.verticalAlignmentMode = .center
        cashL.horizontalAlignmentMode = .left
        cashL.position = CGPoint(x: -cashPillW / 2 + 36, y: 0)
        cashPill.addChild(cashL)
        cashLabel = cashL
        cashPill.isAccessibilityElement = true
        cashPill.accessibilityLabel = String(localized: "Coins. Open shop")
        cashPill.accessibilityTraits = .button

        // Settings gear button
        let gear = SKShapeNode(circleOfRadius: 22)
        gear.fillColor = UIColor(hex: "#EC4899")
        gear.strokeColor = .white
        gear.lineWidth = 2
        gear.position = CGPoint(x: rightX - 22, y: 0)
        gear.name = "hudSettings"
        card.addChild(gear)

        let gearIcon = Icons.sprite(Icons.Name.settings, size: 20, tint: .white)
        gear.addChild(gearIcon)
        gear.isAccessibilityElement = true
        gear.accessibilityLabel = String(localized: "Settings")
        gear.accessibilityTraits = .button
    }

    func refreshHUD() {
        let countdown = Persistence.nextLifeCountdownText
        livesLabel?.text = countdown.isEmpty ? "\(Persistence.lives)" : "\(Persistence.lives) \(countdown)"
        cashLabel?.text = "\(Persistence.cash)"
    }

    func observeStoreKitDeliveries() {
        guard storeKitDeliveryObserver == nil else { return }
        storeKitDeliveryObserver = NotificationCenter.default.addObserver(forName: .storeKitCoinsDelivered,
                                                                          object: nil,
                                                                          queue: .main) { [weak self] _ in
            guard let self else { return }
            self.refreshHUD()
            self.shopCard?.setWallet(Persistence.cash)
            Effects.notify(.success)
        }
        storeKitProductObserver = NotificationCenter.default.addObserver(forName: .storeKitProductsLoaded,
                                                                         object: nil,
                                                                         queue: .main) { [weak self] _ in
            guard let self, self.shopCard != nil else { return }
            self.openShop()
        }
    }

    func buildEventBanners() {
        eventBannerNode?.removeFromParent()
        eventBannerNode = nil

        let events = Levels.activeEvents()
        guard let event = events.first else { return }
        let banner = SKNode()
        banner.zPosition = 998
        banner.name = "tabDaily"
        banner.position = CGPoint(x: 0, y: eventBannerCenterY)
        addChild(banner)
        eventBannerNode = banner

        let width = min(size.width - 28, 350)
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 44), cornerRadius: 14)
        bg.fillColor = UIColor(hex: event.title.contains("Crown") ? "#0F172A" : "#ECFEFF").withAlphaComponent(0.94)
        bg.strokeColor = UIColor(hex: event.title.contains("Crown") ? "#FACC15" : "#22D3EE")
        bg.lineWidth = 1.4
        bg.name = "tabDaily"
        banner.addChild(bg)

        let icon = Icons.sprite(event.title.contains("Crown") ? Icons.Name.crown : Icons.Name.star,
                                size: 17,
                                weight: .heavy,
                                tint: event.title.contains("Crown") ? UIColor(hex: "#FACC15") : UIColor(hex: "#0891B2"))
        icon.position = CGPoint(x: -width / 2 + 22, y: 0)
        banner.addChild(icon)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "\(event.title)  •  Level \(event.level)"
        title.fontSize = 13
        title.fontColor = event.title.contains("Crown") ? .white : UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -width / 2 + 44, y: 7)
        fitLabel(title, maxWidth: width - 58, minFontSize: 10)
        banner.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = event.reward.summary
        sub.fontSize = 10
        sub.fontColor = event.title.contains("Crown") ? UIColor(hex: "#FDE68A") : UIColor(hex: "#0E7490")
        sub.verticalAlignmentMode = .center
        sub.horizontalAlignmentMode = .left
        sub.position = CGPoint(x: -width / 2 + 44, y: -10)
        fitLabel(sub, maxWidth: width - 58, minFontSize: 8)
        banner.addChild(sub)

        banner.isAccessibilityElement = true
        banner.accessibilityLabel = "\(event.title). \(event.reward.summary)"
        banner.accessibilityTraits = .button
    }

    func buildDailyStreakStrip() {
        dailyStreakNode?.removeFromParent()
        dailyStreakNode = nil

        let strip = SKNode()
        strip.zPosition = 997
        strip.name = "tabDaily"
        strip.position = CGPoint(x: 0, y: dailyStreakCenterY)
        addChild(strip)
        dailyStreakNode = strip

        let width = min(size.width - 34, 346)
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 40), cornerRadius: 20)
        bg.fillColor = UIColor.white.withAlphaComponent(0.92)
        bg.strokeColor = UIColor(hex: "#FBCFE8")
        bg.lineWidth = 1
        bg.name = "tabDaily"
        strip.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        let tomorrow = Levels.tomorrowDailyRewardPreview()
        let chestText = Persistence.dailyStreak >= 6 ? String(localized: "7-day chest ready tomorrow") : String(localized: "Tomorrow: \(tomorrow.summary)")
        label.text = "Daily streak \(Persistence.dailyStreak)  •  \(chestText)"
        label.fontSize = 10.5
        label.fontColor = UIColor(hex: "#0F172A")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        fitLabel(label, maxWidth: width - 22, minFontSize: 8)
        strip.addChild(label)

        strip.isAccessibilityElement = true
        strip.accessibilityLabel = label.text ?? String(localized: "Daily streak")
        strip.accessibilityTraits = .button
    }

    func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minFontSize: CGFloat) {
        while label.frame.width > maxWidth && label.fontSize > minFontSize {
            label.fontSize -= 0.5
        }
    }

    func refreshFixedPromos() {
        buildEventBanners()
        buildDailyStreakStrip()
        buildMissionsStrip()
    }

    // MARK: - Bottom bar

    /// Launches the replayable Score Rush mode through the normal level path.
    func launchEndless() {
        onLevelSelected?(Levels.endlessLevel, nil)
    }

    func buildBottomBar() {
        bottomBar = SKNode()
        bottomBar.zPosition = 1000
        addChild(bottomBar)

        let H = bottomBarHeight
        let y = bottomBarCenterY

        // Solid cap so level dots scrolling off-bottom don't bleed into the bar.
        let bottomCap = SKShapeNode(rectOf: CGSize(width: size.width + 6,
                                                    height: H + 50))
        bottomCap.fillColor = UIColor(hex: "#FCE7F3")
        bottomCap.strokeColor = .clear
        bottomCap.position = CGPoint(x: 0, y: y - 18)
        bottomCap.zPosition = -1
        bottomBar.addChild(bottomCap)

        let bg = SKShapeNode(rectOf: CGSize(width: size.width - 16, height: H),
                              cornerRadius: 24)
        bg.fillColor = UIColor(hex: "#FBCFE8")
        bg.strokeColor = .white
        bg.lineWidth = 2
        bg.position = CGPoint(x: 0, y: y)
        bottomBar.addChild(bg)

        // Subtle inner highlight along the top of the bar
        let topHi = SKShapeNode(rectOf: CGSize(width: size.width - 30, height: 4),
                                  cornerRadius: 2)
        topHi.fillColor = UIColor.white.withAlphaComponent(0.5)
        topHi.strokeColor = .clear
        topHi.position = CGPoint(x: 0, y: y + H / 2 - 8)
        bottomBar.addChild(topHi)

        struct Tab { let name: String; let label: String?; let icon: SKNode; let selected: Bool }
        let tabs: [Tab] = [
            .init(name: "tabMap",      label: "Map",   icon: makeMapTabIcon(),       selected: true),
            .init(name: "tabDaily",    label: "Daily", icon: makeDailyTabIcon(),     selected: false),
            .init(name: "tabFriends",  label: "Album", icon: makeFriendsTabIcon(),   selected: false),
            .init(name: "tabTower",    label: "Tower", icon: makeTowerTabIcon(),     selected: false),
            .init(name: "tabShop",     label: "Shop",  icon: makeShopTabIcon(),      selected: false),
            .init(name: "tabRush",     label: "Rush",  icon: makeRushTabIcon(),      selected: false)
        ]

        let slotW = (size.width - 16) / CGFloat(tabs.count)
        for (i, tab) in tabs.enumerated() {
            let cx = -size.width / 2 + 8 + slotW * (CGFloat(i) + 0.5)
            let cy = y + 8

            // Soft glow halo behind the selected tab
            if tab.selected {
                let halo = SKShapeNode(circleOfRadius: 26)
                halo.fillColor = .white
                halo.strokeColor = .clear
                halo.position = CGPoint(x: cx, y: cy)
                halo.alpha = 0.85
                bottomBar.addChild(halo)
            }

            // Icon container that owns the tap
            let slot = SKNode()
            slot.position = CGPoint(x: cx, y: cy)
            slot.name = tab.name
            slot.zPosition = 1
            slot.isAccessibilityElement = true
            slot.accessibilityLabel = tab.label ?? tab.name
            slot.accessibilityTraits = tab.selected ? [.button, .selected] : .button
            bottomBar.addChild(slot)

            let hit = SKShapeNode(rectOf: CGSize(width: max(50, slotW), height: H - 6),
                                  cornerRadius: 18)
            hit.fillColor = UIColor.white.withAlphaComponent(0.001)
            hit.strokeColor = .clear
            hit.name = tab.name
            hit.zPosition = -5
            slot.addChild(hit)

            // The illustrated icon — sized roughly 36pt
            tab.icon.zPosition = 2
            slot.addChild(tab.icon)

            // Subtle pulse on the active tab
            if tab.selected {
                tab.icon.run(.repeatForever(.sequence([
                    .scale(to: 1.06, duration: 1.0),
                    .scale(to: 1.0, duration: 1.0)
                ])))
            }

            // Label below
            if let labelText = tab.label {
                let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                lbl.text = labelText
                lbl.fontSize = 10
                lbl.fontColor = tab.selected
                    ? UIColor(hex: "#0F172A")
                    : UIColor(hex: "#475569")
                lbl.verticalAlignmentMode = .center
                lbl.horizontalAlignmentMode = .center
                lbl.position = CGPoint(x: 0, y: -H / 2 + 4)
                lbl.name = tab.name
                fitLabel(lbl, maxWidth: slotW - 10, minFontSize: 8)
                slot.addChild(lbl)
            }
        }
    }
}
