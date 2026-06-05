import SpriteKit

// Settings + Shop modals
extension GameScene {
    // MARK: - Settings + Shop modals

    func openSettings() {
        settingsCard?.dismiss()
        let card = SettingsCard(sceneSize: size, showsCombos: true)
        card.position = .zero
        addChild(card)
        settingsCard = card

        card.onAction = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .close:
                self.settingsCard?.dismiss()
                self.settingsCard = nil
            case .restartLevel:
                self.settingsCard?.dismiss { [weak self] in
                    self?.settingsCard = nil
                    self?.resetLevel()
                }
            case .resetProgress:
                self.settingsCard?.dismiss { [weak self] in
                    self?.settingsCard = nil
                    self?.performResetProgress()
                }
            case .firebaseSignIn:
                self.signInToFirebaseFromSettings()
            case .firebaseSync:
                self.syncFirebaseFromSettings()
            case .firebaseSignOut:
                FirebaseBackendService.shared.signOut()
                self.reopenSettingsAfterFirebaseAction()
            case .shapedBoardChanged:
                self.layoutBoard()
                self.rebuildAllNodes()
            case .visualAccessibilityChanged:
                self.rebuildHUD()
                self.rebuildAllNodes()
            case .showCombos:
                self.settingsCard?.dismiss { [weak self] in
                    self?.settingsCard = nil
                    self?.showCombosGuide()
                }
            }
        }
    }

    /// Quick reference for how specials are made and what pairings do — reachable
    /// from Settings so the combo depth is discoverable, not just stumbled into.
    func showCombosGuide() {
        let lines = [
            String(localized: "Match 4 → Striped (clears a line)"),
            String(localized: "Match 5 → Color Bomb (one color)"),
            String(localized: "T or L → Wrapped (big blast)"),
            String(localized: "Swap two power-ups = combo!"),
            String(localized: "2 Color Bombs = clear the board")
        ]
        showModal(title: String(localized: "Specials & Combos"),
                  message: lines.joined(separator: "\n"),
                  primary: String(localized: "Got it"),
                  primaryAction: nil)
    }

    func signInToFirebaseFromSettings() {
        FirebaseBackendService.shared.signInWithApple(presentationAnchor: view?.window) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshRuntimeProgressFromPersistence()
                    Effects.notify(.success)
                case .failure:
                    Effects.notify(.warning)
                }
                self.reopenSettingsAfterFirebaseAction()
            }
        }
    }

    func syncFirebaseFromSettings() {
        FirebaseBackendService.shared.syncNow { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshRuntimeProgressFromPersistence()
                    Effects.notify(.success)
                case .failure:
                    Effects.notify(.warning)
                }
                self.reopenSettingsAfterFirebaseAction()
            }
        }
    }

    func reopenSettingsAfterFirebaseAction() {
        settingsCard?.dismiss { [weak self] in
            guard let self else { return }
            self.settingsCard = nil
            self.openSettings()
        }
    }

    func refreshRuntimeProgressFromPersistence() {
        lives         = Persistence.lives
        totalScore    = Persistence.totalScore
        cash          = Persistence.cash
        shuffleCount  = Persistence.shuffleCount
        hammerCount   = Persistence.hammerCount
        swapCount     = Persistence.swapCount
        movesQuantity = Persistence.movesQuantity
        rebuildHUD()
    }

    /// Wipes saved progress (level, cash, lives, boosters) and restarts at level 1.
    /// Preserves the user's settings toggles.
    func performResetProgress() {
        Persistence.resetAll()
        levelConfig = Levels.config(for: 1)
        // Hydrate with defaults
        lives         = Persistence.lives
        totalScore    = Persistence.totalScore
        cash          = Persistence.cash
        shuffleCount  = Persistence.shuffleCount
        hammerCount   = Persistence.hammerCount
        swapCount     = Persistence.swapCount
        movesQuantity = Persistence.movesQuantity
        rebuildHUD()
        layoutBoard()
        startNewGame()
        Effects.notify(.warning)
    }

    func makeRewardedAdShopItem(iconColor: UIColor) -> ShopCard.Item {
        let providerAvailable = Monetization.rewardedAdsAvailable
        let gate = Persistence.rewardedAdGate()
        let enabled = providerAvailable && gate.isAvailable
        let countdown = gate.countdownText
        return .init(id: "ad100",
                     emojiIcon: nil,
                     symbolIcon: enabled ? "play.fill" : "lock.fill",
                     iconBg: providerAvailable ? iconColor : UIColor(hex: "#CBD5E1"),
                     iconTint: .white,
                     title: String(localized: "Watch Ad"),
                     subtitle: providerAvailable
                        ? (enabled ? Monetization.rewardedAdSubtitle : "Next ad in \(countdown)")
                        : Monetization.rewardedAdUnavailableSubtitle,
                     buttonText: providerAvailable
                        ? (enabled ? Monetization.rewardedAdButtonText : countdown)
                        : Monetization.rewardedAdUnavailableButtonText,
                     buttonColor: iconColor,
                     buttonTextColor: .white,
                     enabled: enabled,
                     tab: .earn,
                     isFeatured: true,
                     progress: providerAvailable && !enabled ? gate.progress : nil,
                     meterText: providerAvailable && !enabled ? "Cooldown" : nil)
    }

    func makeDailyBonusShopItem(iconColor: UIColor) -> ShopCard.Item {
        let dateKey = Levels.dailyChallenge().dateKey
        let claimed = Persistence.hasClaimedDailyAdBonus(dateKey)
        let providerAvailable = Monetization.rewardedAdsAvailable
        let enabled = providerAvailable && !claimed
        let countdown = Persistence.dailyResetCountdownText()
        return .init(id: "dailyBonusAd",
                     emojiIcon: nil,
                     symbolIcon: enabled ? "gift.fill" : "lock.fill",
                     iconBg: iconColor,
                     iconTint: .white,
                     title: String(localized: "Daily Bonus"),
                     subtitle: providerAvailable
                        ? (claimed ? String(localized: "Resets in \(countdown)") : String(localized: "One bonus chest per day"))
                        : Monetization.rewardedAdUnavailableSubtitle,
                     buttonText: providerAvailable
                        ? (claimed ? countdown : Monetization.rewardedAdButtonText)
                        : Monetization.rewardedAdUnavailableButtonText,
                     buttonColor: UIColor(hex: "#F59E0B"),
                     buttonTextColor: .white,
                     enabled: enabled,
                     tab: .earn,
                     isFeatured: true,
                     progress: claimed ? Persistence.dailyResetProgress() : nil,
                     meterText: claimed ? String(localized: "Daily reset") : nil)
    }

    func openShop() {
        // Dismiss any existing card first
        shopCard?.dismiss()
        shopCard = nil

        let pink   = UIColor(hex: "#F472B6")
        let teal   = UIColor(hex: "#10B981")
        let blue   = UIColor(hex: "#60A5FA")
        let orange = UIColor(hex: "#F97316")
        let yellow = UIColor(hex: "#FACC15")
        let piggyCoins = Persistence.piggyCoins
        let piggyProgress = CGFloat(piggyCoins) / CGFloat(max(1, Economy.piggyMax))
        let doublerActive = Persistence.coinDoublerActive
        let doublerCountdown = Persistence.coinDoublerCountdownText

        func buildItems() -> [ShopCard.Item] {
            return [
            makeRewardedAdShopItem(iconColor: teal),
            makeDailyBonusShopItem(iconColor: UIColor(hex: "#FACC15")),
            .init(id: "starterBundle",
                  emojiIcon: "🎁", symbolIcon: nil,
                  iconBg: UIColor(hex: "#DDD6FE"), iconTint: .white,
                  title: String(localized: "Beginner Pack"),
                  subtitle: String(localized: "Lives + shuffles for learning"),
                  buttonText: "💰 \(Economy.starterBundleCost)",
                  buttonColor: UIColor(hex: "#8B5CF6"), buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "comboBundle",
                  emojiIcon: "✨", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FDE68A"), iconTint: .white,
                  title: String(localized: "Combo Pack"),
                  subtitle: String(localized: "Hammers + swaps for big chains"),
                  buttonText: "💰 \(Economy.comboBundleCost)",
                  buttonColor: UIColor(hex: "#F59E0B"), buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "hardBundle",
                  emojiIcon: "🏆", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FBCFE8"), iconTint: .white,
                  title: String(localized: "Hard Level Pack"),
                  subtitle: String(localized: "Best value for blocker levels"),
                  buttonText: "💰 \(Economy.hardLevelBundleCost)",
                  buttonColor: UIColor(hex: "#E11D48"), buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "lives3",
                  emojiIcon: "❤️", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FBCFE8"), iconTint: .white,
                  title: String(localized: "+3 Lives"),
                  subtitle: String(localized: "Keep a streak going"),
                  buttonText: "💰 \(Economy.livesBundleCost)",
                  buttonColor: pink, buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "shuffles5",
                  emojiIcon: "🔀", symbolIcon: nil,
                  iconBg: UIColor(hex: "#BAE6FD"), iconTint: .white,
                  title: String(localized: "+5 Shuffles"),
                  subtitle: String(localized: "Fix a stuck board"),
                  buttonText: "💰 \(Economy.shuffleBundleCost)",
                  buttonColor: blue, buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "hammers5",
                  emojiIcon: "🔨", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FED7AA"), iconTint: .white,
                  title: String(localized: "+5 Hammers"),
                  subtitle: String(localized: "Break blockers or finish a combo"),
                  buttonText: "💰 \(Economy.hammerBundleCost)",
                  buttonColor: orange, buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "swaps5",
                  emojiIcon: "✋", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FEF08A"), iconTint: .white,
                  title: String(localized: "+5 Swaps"),
                  subtitle: String(localized: "Create specials on demand"),
                  buttonText: "💰 \(Economy.swapBundleCost)",
                  buttonColor: yellow, buttonTextColor: UIColor(hex: "#0F172A"),
                  enabled: true,
                  tab: .boosts),
            .init(id: "piggyCrack",
                  emojiIcon: "🐷", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FBCFE8"), iconTint: .white,
                  title: String(localized: "Piggy Bank"),
                  subtitle: Persistence.piggyIsFull ? String(localized: "Ready to crack") : String(localized: "Fills as you play"),
                  buttonText: Persistence.piggyIsFull ? "Crack" : "Filling",
                  buttonColor: UIColor(hex: "#EC4899"), buttonTextColor: .white,
                  enabled: Persistence.piggyIsFull,
                  tab: .special,
                  isFeatured: true,
                  progress: piggyProgress,
                  meterText: Persistence.piggyIsFull ? "Full" : "\(piggyCoins)/\(Economy.piggyMax) saved"),
            .init(id: "coinDoubler",
                  emojiIcon: nil, symbolIcon: "bolt.circle.fill",
                  iconBg: UIColor(hex: "#DCFCE7"), iconTint: UIColor(hex: "#16A34A"),
                  title: String(localized: "Coin Doubler"),
                  subtitle: doublerActive ? "Active \(doublerCountdown)" : "Double play rewards for 24h",
                  buttonText: doublerActive ? "Extend" : "💰 \(Economy.coinDoublerCost)",
                  buttonColor: UIColor(hex: "#16A34A"), buttonTextColor: .white,
                  enabled: true,
                  tab: .special,
                  isFeatured: true),
            .init(id: "cashS",
                  emojiIcon: "💰", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FEF3C7"), iconTint: .white,
                  title: String(localized: "Small Coin Pack"),
                  subtitle: Monetization.coinPackSubtitle(.small),
                  buttonText: Monetization.coinPackButtonText(.small,
                                                              displayPrice: StoreKitService.shared.displayPrice(for: .small)),
                  buttonColor: pink, buttonTextColor: .white,
                  enabled: true,
                  tab: .coins),
            .init(id: "cashL",
                  emojiIcon: "💰", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FEF3C7"), iconTint: .white,
                  title: String(localized: "Large Coin Pack"),
                  subtitle: Monetization.coinPackSubtitle(.large),
                  buttonText: Monetization.coinPackButtonText(.large,
                                                              displayPrice: StoreKitService.shared.displayPrice(for: .large)),
                  buttonColor: pink, buttonTextColor: .white,
                  enabled: true,
                  tab: .coins)
            ]
        }

        let items = buildItems()

        let card = ShopCard(items: items, walletCash: cash, sceneSize: size, refreshItems: buildItems)
        card.position = .zero
        card.alpha = 0
        addChild(card)
        card.run(.fadeIn(withDuration: 0.18))
        shopCard = card

        card.onBuy = { [weak self] id in self?.handleShopBuy(id) }
        card.onClose = { [weak self] in
            self?.shopCard?.dismiss()
            self?.shopCard = nil
        }
    }

    func handleShopBuy(_ id: String) {
        switch id {
        case "ad100":
            grantRewardedAdCoins()
        case "dailyBonusAd":
            grantDailyAdBonus()
        case "starterBundle":
            buyBoosterBundle(id: id,
                             cost: Economy.starterBundleCost,
                             livesAdded: 2,
                             shufflesAdded: 3,
                             hammersAdded: 1,
                             swapsAdded: 1)
        case "comboBundle":
            buyBoosterBundle(id: id,
                             cost: Economy.comboBundleCost,
                             livesAdded: 0,
                             shufflesAdded: 3,
                             hammersAdded: 5,
                             swapsAdded: 5)
        case "hardBundle":
            buyBoosterBundle(id: id,
                             cost: Economy.hardLevelBundleCost,
                             livesAdded: 3,
                             shufflesAdded: 5,
                             hammersAdded: 6,
                             swapsAdded: 6)
        case "lives3":
            guard cash >= Economy.livesBundleCost else { insufficientCashFeedback(); return }
            cash -= Economy.livesBundleCost
            lives = min(livesMax, lives + 3)
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.livesBundleCost)"])
            Effects.notify(.success)
        case "shuffles5":
            guard cash >= Economy.shuffleBundleCost else { insufficientCashFeedback(); return }
            cash -= Economy.shuffleBundleCost
            shuffleCount += 5
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.shuffleBundleCost)"])
            Effects.notify(.success)
        case "hammers5":
            guard cash >= Economy.hammerBundleCost else { insufficientCashFeedback(); return }
            cash -= Economy.hammerBundleCost
            hammerCount += 5
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.hammerBundleCost)"])
            Effects.notify(.success)
        case "swaps5":
            guard cash >= Economy.swapBundleCost else { insufficientCashFeedback(); return }
            cash -= Economy.swapBundleCost
            swapCount += 5
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.swapBundleCost)"])
            Effects.notify(.success)
        case "piggyCrack":
            crackPiggyBank()
            return
        case "coinDoubler":
            buyCoinDoubler()
            return
        case "cashS":
            purchaseCoinPack(.small)
        case "cashL":
            purchaseCoinPack(.large)
        default:
            break
        }
        shopCard?.setWallet(cash)
    }

    func crackPiggyBank() {
        guard Persistence.piggyIsFull else { insufficientCashFeedback(); return }
        let pot = Persistence.emptyPiggy()
        guard pot > 0 else { return }
        let credited = Persistence.applyCoinDoubler(pot)
        cash += credited
        Analytics.track("piggy_bank_cracked",
                        properties: ["level": "\(levelNumber)",
                                     "coins": "\(credited)",
                                     "base": "\(pot)"])
        Effects.showComboBanner(text: "+\(credited) COINS",
                                color: UIColor(hex: "#FACC15"),
                                in: self)
        Effects.notify(.success)
        shopCard?.setWallet(cash)
        openShop()
    }

    func buyCoinDoubler() {
        guard cash >= Economy.coinDoublerCost else { insufficientCashFeedback(); return }
        cash -= Economy.coinDoublerCost
        Persistence.extendCoinDoubler()
        Analytics.track("coin_spend",
                        properties: ["item": "coinDoubler",
                                     "coins": "\(Economy.coinDoublerCost)",
                                     "level": "\(levelNumber)"])
        Effects.showComboBanner(text: String(localized: "COINS DOUBLED"),
                                color: UIColor(hex: "#16A34A"),
                                in: self)
        Effects.notify(.success)
        shopCard?.setWallet(cash)
        openShop()
    }

    func buyBoosterBundle(id: String,
                                  cost: Int,
                                  livesAdded: Int,
                                  shufflesAdded: Int,
                                  hammersAdded: Int,
                                  swapsAdded: Int) {
        guard cash >= cost else { insufficientCashFeedback(); return }
        cash -= cost
        lives = min(Economy.livesMax, lives + livesAdded)
        shuffleCount += shufflesAdded
        hammerCount += hammersAdded
        swapCount += swapsAdded
        Analytics.track("coin_spend", properties: ["item": id, "coins": "\(cost)"])
        Effects.notify(.success)
    }

    func purchaseCoinPack(_ product: CoinProduct) {
        Task { @MainActor in
            switch await StoreKitService.shared.purchase(product) {
            case .delivered(_):
                cash = Persistence.cash
                Effects.notify(.success)
            case .cancelled:
                break
            case .pending:
                Effects.notify(.warning)
            case .failed:
                #if DEBUG
                cash += product.coins
                Analytics.track("coin_pack_test_grant_fallback",
                                properties: ["product": product.analyticsName,
                                             "coins": "\(product.coins)"])
                Effects.notify(.success)
                #else
                insufficientCashFeedback()
                #endif
            }
            shopCard?.setWallet(cash)
        }
    }

    func grantRewardedAdCoins() {
        guard Monetization.rewardedAdsAvailable, Persistence.rewardedAdGate().isAvailable else {
            Effects.notify(.warning)
            return
        }
        RewardedAdService.showRewardedAd(reason: "coins") { [weak self] completed in
            guard completed else {
                Effects.notify(.warning)
                return
            }
            guard let self else {
                return
            }
            Persistence.recordRewardedAdWatched()
            self.cash += Monetization.rewardedAdCoins
            Analytics.track("rewarded_ad_completed",
                            properties: ["reason": "coins",
                                         "coins": "\(Monetization.rewardedAdCoins)"])
            Effects.haptic(.medium)
            Effects.notify(.success)
            self.shopCard?.setWallet(self.cash)
            if let label = self.cashLabel {
                let pos = label.parent?.convert(label.position, to: self) ?? .zero
                Effects.showScorePopup(Monetization.rewardedAdCoins,
                                       at: CGPoint(x: pos.x, y: pos.y + 34),
                                       in: self,
                                       color: UIColor(hex: "#FBBF24"))
            }
        }
    }

    func grantDailyAdBonus() {
        let dateKey = Levels.dailyChallenge().dateKey
        guard !Persistence.hasClaimedDailyAdBonus(dateKey) else { return }
        RewardedAdService.showRewardedAd(reason: "daily_bonus") { [weak self] completed in
            guard let self else { return }
            guard completed else {
                Effects.notify(.warning)
                return
            }
            let reward = LevelReward(title: String(localized: "Daily ad bonus"),
                                     coins: 140,
                                     lives: 0,
                                     shuffles: 1,
                                     hammers: 1,
                                     swaps: 0)
            self.applyReward(reward)
            Persistence.markDailyAdBonusClaimed(dateKey)
            Analytics.track("rewarded_ad_completed",
                            properties: ["reason": "daily_bonus",
                                         "date": dateKey])
            Effects.showComboBanner(text: reward.summary,
                                    color: UIColor(hex: "#FACC15"),
                                    in: self)
            Effects.notify(.success)
            self.shopCard?.setWallet(self.cash)
        }
    }

    func showModal(title: String, message: String, primary: String, primaryAction: (() -> Void)?) {
        dismissModal()

        let scrim = SKShapeNode(rectOf: size)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        scrim.zPosition = 1500
        scrim.alpha = 0
        scrim.name = "modalScrim"

        let cardW = min(size.width - 60, 320)
        let cardH: CGFloat = 240
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.6)
        card.lineWidth = 1
        card.zPosition = 1501
        card.position = .zero
        card.alpha = 0
        card.setScale(0.7)

        let titleL = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleL.text = title
        titleL.fontSize = 24
        titleL.fontColor = UIColor(hex: "#0F172A")
        titleL.verticalAlignmentMode = .center
        titleL.horizontalAlignmentMode = .center
        titleL.position = CGPoint(x: 0, y: cardH / 2 - 36)
        card.addChild(titleL)

        // Multi-line message via two labels (simple)
        let lines = message.components(separatedBy: "\n")
        var y: CGFloat = cardH / 2 - 80
        for line in lines {
            let l = SKLabelNode(fontNamed: "AvenirNext-Medium")
            l.text = line
            l.fontSize = 13
            l.fontColor = UIColor(hex: "#475569")
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            l.position = CGPoint(x: 0, y: y)
            card.addChild(l)
            y -= 18
        }

        let btn = SKShapeNode(rectOf: CGSize(width: cardW - 56, height: 46), cornerRadius: 23)
        btn.fillColor = UIColor(hex: "#F472B6")
        btn.strokeColor = .clear
        btn.position = CGPoint(x: 0, y: -cardH / 2 + 50)
        btn.name = "modalAction"
        let btnL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btnL.text = primary
        btnL.fontSize = 16
        btnL.fontColor = .white
        btnL.verticalAlignmentMode = .center
        btnL.horizontalAlignmentMode = .center
        btn.addChild(btnL)
        card.addChild(btn)

        let close = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        close.text = String(localized: "Close")
        close.fontSize = 13
        close.fontColor = UIColor(hex: "#475569")
        close.verticalAlignmentMode = .center
        close.horizontalAlignmentMode = .center
        close.position = CGPoint(x: 0, y: -cardH / 2 + 18)
        close.name = "modalClose"
        card.addChild(close)

        let container = SKNode()
        container.zPosition = 1500
        container.addChild(scrim)
        container.addChild(card)
        addChild(container)
        modalCard = container
        modalPrimaryAction = primaryAction

        scrim.run(.fadeAlpha(to: 1.0, duration: 0.18))
        card.run(.group([
            .fadeIn(withDuration: 0.18),
            .scale(to: 1.0, duration: 0.22)
        ]))
    }

    func dismissModal() {
        guard let modal = modalCard else { return }
        let action = modalPrimaryAction
        modalCard = nil
        modalPrimaryAction = nil
        modal.run(.sequence([
            .fadeOut(withDuration: 0.15),
            .removeFromParent(),
            .run { action?() }
        ]))
    }

    func showLevelTesterOverlay() {
        #if DEBUG
        levelTesterOverlay?.removeFromParent()

        let stats = Analytics.levelStats(for: levelNumber)
        let attempts = stats["attempts"] ?? 0
        let wins = stats["wins"] ?? 0
        let winRate = attempts > 0
            ? Double(wins) / Double(max(1, attempts))
            : LevelBalanceAnalyzer.estimatedWinRate(for: levelConfig)
        let avgStars = wins > 0
            ? Double(stats["stars_total"] ?? 0) / Double(max(1, wins))
            : LevelBalanceAnalyzer.estimatedAverageStars(for: levelConfig)
        let avgMoves = wins > 0
            ? Double(stats["moves_left_total"] ?? 0) / Double(max(1, wins))
            : Double(levelConfig.moves) * 0.22
        let label = LevelBalanceAnalyzer.balanceLabel(winRate: winRate, averageStars: avgStars)
        let snapshot = LevelBalanceAnalyzer.snapshot(for: levelConfig)

        let overlay = SKNode()
        overlay.zPosition = 1400

        let scrim = SKShapeNode(rectOf: size)
        scrim.fillColor = UIColor(white: 0, alpha: 0.42)
        scrim.strokeColor = .clear
        scrim.name = "testerClose"
        overlay.addChild(scrim)

        let cardW = min(size.width - 36, 340)
        let cardH: CGFloat = 292
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 20)
        card.fillColor = UIColor(white: 1, alpha: 0.98)
        card.strokeColor = UIColor(hex: "#CBD5E1")
        card.lineWidth = 1
        card.position = CGPoint(x: 0, y: 10)
        overlay.addChild(card)

        func addLabel(_ text: String,
                      x: CGFloat,
                      y: CGFloat,
                      size: CGFloat,
                      color: UIColor,
                      align: SKLabelHorizontalAlignmentMode = .left,
                      weight: String = "AvenirNext-DemiBold") {
            let l = SKLabelNode(fontNamed: weight)
            l.text = text
            l.fontSize = size
            l.fontColor = color
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = align
            l.position = CGPoint(x: x, y: y)
            card.addChild(l)
        }

        let left = -cardW / 2 + 22
        let right = cardW / 2 - 22
        let top = cardH / 2
        addLabel(String(localized: "Level Tester"), x: left, y: top - 28, size: 20,
                 color: UIColor(hex: "#0F172A"), weight: "AvenirNext-Heavy")
        addLabel("Level \(levelNumber)", x: right, y: top - 28, size: 13,
                 color: UIColor(hex: "#64748B"), align: .right)

        let statusColor: UIColor = {
            switch label {
            case "Too hard": return UIColor(hex: "#EF4444")
            case "Too easy": return UIColor(hex: "#F59E0B")
            default: return UIColor(hex: "#10B981")
            }
        }()
        let status = makePill(width: 106, height: 28,
                              fill: statusColor.withAlphaComponent(0.16),
                              stroke: statusColor.withAlphaComponent(0.55))
        status.position = CGPoint(x: 0, y: top - 68)
        card.addChild(status)
        addLabel(label, x: 0, y: top - 68, size: 13,
                 color: statusColor, align: .center, weight: "AvenirNext-Heavy")

        let source = attempts > 0 ? String(localized: "\(attempts) played attempts") : String(localized: "catalog estimate")
        let percent = Int((winRate * 100).rounded())
        let rows: [(String, String)] = [
            (String(localized: "Win rate"), String(localized: "\(percent)%  \(source)")),
            (String(localized: "Average stars"), String(format: "%.1f", avgStars)),
            (String(localized: "Avg moves left"), String(format: "%.1f", avgMoves)),
            (levelConfig.goal == .score ? "Capacity" : "Stars",
             levelConfig.goal == .score
                ? "\(snapshot.estimatedScoreCapacity) vs \(levelConfig.target)"
                : LevelScoring.previewSummary(for: levelConfig)),
            ("Goal", levelConfig.goal.title)
        ]
        var y = top - 108
        for row in rows {
            addLabel(row.0, x: left, y: y, size: 12, color: UIColor(hex: "#64748B"))
            addLabel(row.1, x: right, y: y, size: 12, color: UIColor(hex: "#0F172A"), align: .right,
                     weight: "AvenirNext-Heavy")
            y -= 28
        }

        let warningText = snapshot.warnings.isEmpty ? String(localized: "No balance warnings") : snapshot.warnings.joined(separator: ", ")
        addLabel(warningText, x: 0, y: -cardH / 2 + 78, size: 10.5,
                 color: snapshot.warnings.isEmpty ? UIColor(hex: "#10B981") : UIColor(hex: "#B45309"),
                 align: .center)

        let prev = testerButton(title: String(localized: "Prev"), name: levelNumber > 1 ? "testerPrev" : "testerDisabled",
                                fill: levelNumber > 1 ? UIColor(hex: "#E0F2FE") : UIColor(white: 0, alpha: 0.06),
                                textColor: levelNumber > 1 ? UIColor(hex: "#0369A1") : UIColor(hex: "#94A3B8"),
                                width: 82)
        prev.position = CGPoint(x: -94, y: -cardH / 2 + 36)
        card.addChild(prev)

        let close = testerButton(title: String(localized: "Close"), name: "testerClose",
                                 fill: UIColor(hex: "#F1F5F9"),
                                 textColor: UIColor(hex: "#334155"),
                                 width: 82)
        close.position = CGPoint(x: 0, y: -cardH / 2 + 36)
        card.addChild(close)

        let next = testerButton(title: String(localized: "Next"), name: levelNumber < Levels.count ? "testerNext" : "testerDisabled",
                                fill: levelNumber < Levels.count ? UIColor(hex: "#DCFCE7") : UIColor(white: 0, alpha: 0.06),
                                textColor: levelNumber < Levels.count ? UIColor(hex: "#047857") : UIColor(hex: "#94A3B8"),
                                width: 82)
        next.position = CGPoint(x: 94, y: -cardH / 2 + 36)
        card.addChild(next)

        addChild(overlay)
        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.14))
        levelTesterOverlay = overlay
        #endif
    }

    func testerButton(title: String,
                              name: String,
                              fill: UIColor,
                              textColor: UIColor,
                              width: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 34), cornerRadius: 17)
        button.fillColor = fill
        button.strokeColor = .clear
        button.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = title
        label.fontSize = 13
        label.fontColor = textColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        button.addChild(label)
        return button
    }

    func handleLevelTesterTap(at point: CGPoint) {
        guard let overlay = levelTesterOverlay else { return }
        let local = overlay.convert(point, from: self)
        var hit: SKNode? = overlay.atPoint(local)
        while let node = hit {
            switch node.name {
            case "testerPrev":
                jumpToTesterLevel(levelNumber - 1)
                return
            case "testerNext":
                jumpToTesterLevel(levelNumber + 1)
                return
            case "testerClose":
                overlay.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
                levelTesterOverlay = nil
                return
            case "testerDisabled":
                Effects.haptic(.soft)
                return
            default:
                hit = node.parent
            }
        }
    }

    func jumpToTesterLevel(_ level: Int) {
        #if DEBUG
        levelTesterOverlay?.removeFromParent()
        levelTesterOverlay = nil
        endLevelCard?.dismiss()
        endLevelCard = nil
        levelEnded = false
        isResolving = false
        cascadeDepth = 0
        pendingLifeLoss = false
        continueUsedThisAttempt = false
        pendingDoubleRewards = []
        deselect()
        levelConfig = Levels.config(for: level)
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        startNewGame()
        showLevelTesterOverlay()
        #endif
    }

    func spawnConfetti() {
        let confetti = Effects.makeConfetti(width: size.width)
        confetti.position = CGPoint(x: 0, y: size.height / 2 + 20)
        addChild(confetti)
        confetti.run(.sequence([.wait(forDuration: 2.6), .removeFromParent()]))
    }

    func applyCollapseAndRefill() {
        let oldGrid = grid
        let idToNode = nodeIdMap(in: oldGrid)
        let settledGrid = Engine.collapseAndRefill(grid,
                                                   colors: palette,
                                                   mask: levelConfig.layout.mask,
                                                   cascadeBoost: currentCascadeBoost,
                                                   rng: &gameplayRNG)
        var newGrid = Engine.applyPortals(settledGrid,
                                          pairs: levelConfig.layout.portalPairs)
        newGrid = Engine.applyConveyors(newGrid,
                                        belts: levelConfig.layout.conveyorBelts)
        var collectedDropNodeIDs = Set<String>()

        // Ingredient rescue: any baskets that have settled to the bottom of
        // their column are collected.
        let (afterIngredients, collectedPositions) = Engine.collectIngredientsAtBottom(
            newGrid,
            mask: levelConfig.layout.mask)
        if !collectedPositions.isEmpty {
            collectedIngredients += collectedPositions.count
            for p in collectedPositions {
                if let cell = newGrid[p.r][p.c] {
                    collectedDropNodeIDs.insert(cell.id)
                }
                if let id = newGrid[p.r][p.c]?.id, let n = idToNode[id] {
                    let burst = Effects.makeStarSparkle(count: 10)
                    burst.position = n.position
                    burst.zPosition = 750
                    worldNode.addChild(burst)
                }
            }
            Audio.shared.play(.combo(depth: 2))
            Effects.haptic(.medium)
            Analytics.track("ingredient_collected",
                            properties: ["level": "\(levelNumber)",
                                         "count": "\(collectedPositions.count)"])
            newGrid = afterIngredients
        }
        let (afterKeys, collectedKeyPositions) = Engine.collectKeysAtBottom(
            newGrid,
            mask: levelConfig.layout.mask)
        var openedByKeys: Set<Pos> = []
        if !collectedKeyPositions.isEmpty {
            collectedKeys += collectedKeyPositions.count
            newGrid = afterKeys
            for _ in collectedKeyPositions {
                if let opened = Engine.openFirstChest(&newGrid) {
                    openedByKeys.insert(opened)
                }
            }
            if !openedByKeys.isEmpty {
                openedChests += openedByKeys.count
                awardChestRewards(opened: openedByKeys)
            }
            for p in collectedKeyPositions {
                if let cell = afterIngredients[p.r][p.c] {
                    collectedDropNodeIDs.insert(cell.id)
                }
                if let id = afterIngredients[p.r][p.c]?.id, let n = idToNode[id] {
                    let burst = Effects.makeStarSparkle(count: 12)
                    burst.position = n.position
                    burst.zPosition = 750
                    worldNode.addChild(burst)
                }
            }
            Audio.shared.play(.combo(depth: 2))
            Effects.haptic(.medium)
            Analytics.track("key_collected",
                            properties: ["level": "\(levelNumber)",
                                         "count": "\(collectedKeyPositions.count)",
                                         "opened_chests": "\(openedByKeys.count)"])
            showObjectiveCompleteIfNeeded()
        }
        for id in collectedDropNodeIDs {
            guard let node = idToNode[id] else { continue }
            node.run(.sequence([
                .group([
                    .scale(to: 1.22, duration: 0.10),
                    .fadeOut(withDuration: 0.14)
                ]),
                .removeFromParent()
            ]))
        }
        grid = newGrid
        if !levelConfig.layout.portalPairs.isEmpty || !levelConfig.layout.conveyorBelts.isEmpty {
            Analytics.track("board_mechanic_tick",
                            properties: ["level": "\(levelNumber)",
                                         "portals": "\(levelConfig.layout.portalPairs.count)",
                                         "conveyors": "\(levelConfig.layout.conveyorBelts.count)"])
            animateBoardMechanicsTick()
        }

        var newNodes: [[SKNode?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)

        let fallDur: TimeInterval = 0.22

        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = newGrid[r][c] else { continue }
                if let existing = idToNode[cell.id] {
                    newNodes[r][c] = existing
                    existing.run(.move(to: point(forRow: r, col: c), duration: fallDur))
                } else {
                    let node = makeTileNode(for: cell)
                    let spawnY = size.height / 2 + tileSize
                    let dest = point(forRow: r, col: c)
                    node.position = CGPoint(x: dest.x, y: spawnY)
                    worldNode.addChild(node)

                    // Stardust trail behind the falling tile — turns the refill
                    // into the "tiles raining in" feel from the references.
                    let trail = Effects.makeFallTrail(tint: UIColor(hex: cell.color))
                    trail.position = .zero
                    trail.zPosition = -0.5
                    node.addChild(trail)

                    node.run(.sequence([
                        .move(to: dest, duration: fallDur),
                        .run { [weak trail] in
                            // Stop emitting on landing, then fade the lingering particles.
                            trail?.particleBirthRate = 0
                            trail?.run(.sequence([.wait(forDuration: 0.5),
                                                  .removeFromParent()]))
                        }
                    ]))
                    newNodes[r][c] = node
                }
            }
        }
        nodes = newNodes
        for p in openedByKeys {
            refreshNode(at: p)
        }

        run(.wait(forDuration: fallDur + 0.02)) { [weak self] in
            self?.resolveCascade()
        }
    }

    func animateBoardMechanicsTick() {
        for pair in levelConfig.layout.portalPairs {
            for pos in [pair.from, pair.to] where pos.r >= 0 && pos.r < rows && pos.c >= 0 && pos.c < cols {
                let ring = SKShapeNode(circleOfRadius: tileSize * 0.38)
                ring.fillColor = UIColor(hex: "#A78BFA").withAlphaComponent(0.16)
                ring.strokeColor = UIColor(hex: "#22D3EE")
                ring.lineWidth = 2
                ring.glowWidth = 6
                ring.position = point(forRow: pos.r, col: pos.c)
                ring.zPosition = 820
                worldNode.addChild(ring)
                ring.run(.sequence([
                    .group([.scale(to: 1.55, duration: 0.28),
                            .fadeOut(withDuration: 0.28)]),
                    .removeFromParent()
                ]))
            }
        }
        if !levelConfig.layout.portalPairs.isEmpty { Audio.shared.play(.portal) }

        for belt in levelConfig.layout.conveyorBelts where belt.row >= 0 && belt.row < rows {
            let y = point(forRow: belt.row, col: 0).y
            let sweep = SKShapeNode(rectOf: CGSize(width: tileSize * CGFloat(cols), height: tileSize * 0.18),
                                    cornerRadius: tileSize * 0.08)
            sweep.fillColor = UIColor(hex: "#67E8F9").withAlphaComponent(0.42)
            sweep.strokeColor = .clear
            sweep.position = CGPoint(x: belt.direction >= 0 ? -size.width / 2 : size.width / 2, y: y)
            sweep.zPosition = 810
            worldNode.addChild(sweep)
            sweep.run(.sequence([
                .moveTo(x: belt.direction >= 0 ? size.width / 2 : -size.width / 2, duration: 0.30),
                .fadeOut(withDuration: 0.12),
                .removeFromParent()
            ]))
        }
        if !levelConfig.layout.conveyorBelts.isEmpty { Audio.shared.play(.conveyor) }
    }
}
