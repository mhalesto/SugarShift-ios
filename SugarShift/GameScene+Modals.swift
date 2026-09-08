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
            case .gameplayAppearanceChanged:
                self.applyGameplayTransparency()
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
            String(localized: "T or L → Wrapped (5x5 blast)"),
            String(localized: "2x2 square → Fish (seeks your goal)"),
            String(localized: "Every power-up pair has a unique combo"),
            String(localized: "Smash costs 50, 75, or 100 — choose a tier, preview, then confirm"),
            String(localized: "Goal moves build Flow; Flow 3 earns an aimed Sugar Rush cross")
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
            guard Persistence.lives < livesMax else { return }
            guard cash >= Economy.livesBundleCost else { insufficientCashFeedback(); return }
            cash -= Economy.livesBundleCost
            lives = min(livesMax, Persistence.lives + 3)
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
        guard canAcceptBoardInput, let controller = testerPresentingController,
              controller.viewIfLoaded?.window != nil,
              !controller.isBeingPresented, !controller.isBeingDismissed else { return }
        cancelIdleHint()
        cancelBoosterMode()
        deselect()

        // Keep the existing scene input gate active through the UIKit dismissal.
        // The native sheet is the only visible tester; there is no second card.
        let blocker = SKNode()
        blocker.name = "levelExplorerInputGuard"
        addChild(blocker)
        levelTesterOverlay = blocker
        let explorer = LevelExplorerViewController(config: levelConfig, openingSeed: levelAttemptSeed)
        explorer.onDismiss = { [weak self, weak blocker] in
            guard let self, let blocker, self.levelTesterOverlay === blocker else { return }
            blocker.removeFromParent()
            self.levelTesterOverlay = nil
        }
        explorer.onSelect = { [weak self] level, seed in
            guard let self, (1...Levels.count).contains(level), !self.isResolving,
                  self.gamePhase.acceptsBoardInput else { return }
            if let seed { self.debugReplaySeed = seed }
            self.jumpToTesterLevel(level)
        }
        controller.present(explorer, animated: !UIAccessibility.isReduceMotionEnabled)
        #endif
    }

    func handleLevelTesterTap(at _: CGPoint) {
        // GameScene+Touch consumes scene touches while the native sheet or its
        // dismissal is active. Every tester action is handled in UIKit.
    }

    /// Debug-only: replay the current level with an opening seed from analytics.
    func promptForReplaySeed() {
        #if DEBUG
        (testerPresentingController as? LevelExplorerViewController)?.showSeedReplay()
        #endif
    }

    func jumpToTesterLevel(_ level: Int) {
        #if DEBUG
        guard (1...Levels.count).contains(level), !isResolving,
              gamePhase.acceptsBoardInput else { return }
        LevelExplorerViewController.recordVisit(level)
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
        initialDailyChallenge = nil
        dailyChallengeRun = nil
        isDailyChallengeRun = false
        cancelIdleHint()
        cancelBoosterMode()
        deselect()
        levelConfig = Levels.config(for: level)
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        startNewGame()
        #endif
    }

    func promptForTesterLevel() {
        #if DEBUG
        (testerPresentingController as? LevelExplorerViewController)?.focusLevelEntry()
        #endif
    }

    func promptForTesterWorld() {
        #if DEBUG
        (testerPresentingController as? LevelExplorerViewController)?.showWorlds()
        #endif
    }

    #if DEBUG
    private var testerPresentingController: UIViewController? {
        var controller = view?.window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
    #endif

    func spawnConfetti() {
        let now = CACurrentMediaTime()
        guard now - lastConfettiAt > 3.0 else { return }
        lastConfettiAt = now
        let confetti = Effects.makeConfetti(width: size.width)
        confetti.position = CGPoint(x: 0, y: size.height / 2 + 20)
        addChild(confetti)
        confetti.run(.sequence([.wait(forDuration: 2.6), .removeFromParent()]))
    }

    func applyCollapseAndRefill() {
        let objectiveBefore = worldEffects.beginObjectives()
        gamePhase = .falling
        let oldGrid = grid
        let idToNode = nodeIdMap(in: oldGrid)
        var idToOldPosition: [String: Pos] = [:]
        for r in 0..<oldGrid.count {
            for c in 0..<oldGrid[r].count {
                if let id = oldGrid[r][c]?.id {
                    idToOldPosition[id] = Pos(r: r, c: c)
                }
            }
        }
        let refill = Engine.collapseAndRefillResult(grid,
                                                   colors: palette,
                                                   mask: levelConfig.layout.mask,
                                                   cascadeBoost: currentCascadeBoost,
                                                   portals: levelConfig.layout.portalPairs,
                                                   spawnWeights: levelConfig.spawnWeights,
                                                   rng: &gameplayRNG)
        var newGrid = refill.grid
        var transfers = refill.portalTransfers
        var refillEvents = refill.presentationEvents
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
                objectiveTracker.consume(.blockerDestroyed(type: .chest, count: openedByKeys.count))
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
        if !collectedPositions.isEmpty || !collectedKeyPositions.isEmpty {
            let nextRefill = Engine.collapseAndRefillResult(newGrid, colors: palette,
                mask: levelConfig.layout.mask, portals: levelConfig.layout.portalPairs,
                spawnWeights: levelConfig.spawnWeights, rng: &gameplayRNG)
            newGrid = nextRefill.grid
            transfers += nextRefill.portalTransfers
            refillEvents += nextRefill.presentationEvents
        }
        grid = newGrid
        var objectiveSources: [Int: [Pos]] = [:]
        func presentationOrder(_ a: Pos, _ b: Pos) -> Bool {
            a.r == b.r ? a.c < b.c : a.r < b.r
        }
        for (index, objective) in displayedHUDObjectives.enumerated() {
            switch objective {
            case .collectIngredients: objectiveSources[index] = collectedPositions.sorted(by: presentationOrder)
            case .collectKeys: objectiveSources[index] = collectedKeyPositions.sorted(by: presentationOrder)
            case .destroySpecificBlocker(.chest, _): objectiveSources[index] = openedByKeys.sorted(by: presentationOrder)
            default: break
            }
        }
        worldEffects.finishObjectives(objectiveBefore, events: refillEvents, collected: objectiveSources)
        if !transfers.isEmpty { Audio.shared.play(.portal) }
        if !levelConfig.layout.portalPairs.isEmpty || !levelConfig.layout.conveyorBelts.isEmpty {
            Analytics.track("board_mechanic_tick",
                            properties: ["level": "\(levelNumber)",
                                         "portals": "\(levelConfig.layout.portalPairs.count)",
                                         "conveyors": "\(levelConfig.layout.conveyorBelts.count)"])
            animateBoardMechanicsTick()
        }

        var newNodes: [[SKNode?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)

        let cascadeSpeed = min(1.45, 1.0 + Double(max(0, cascadeDepth - 1)) * 0.09)
        var latestLanding: TimeInterval = 0
        var landingPan: Float = 0

        func fallDuration(rows distance: Int, isNew: Bool) -> TimeInterval {
            let base = isNew ? 0.14 : 0.10
            let perRow = isNew ? 0.027 : 0.023
            return min(0.36, base + Double(max(1, distance)) * perRow) / cascadeSpeed
        }

        func landingAction(to destination: CGPoint, duration: TimeInterval, delay: TimeInterval) -> SKAction {
            SignatureMotion.landingAction(to: destination, duration: duration, delay: delay)
        }

        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = newGrid[r][c] else { continue }
                let columnDelay = Persistence.reduceMotion ? 0 : TimeInterval(c) * 0.012
                let destination = point(forRow: r, col: c)
                if !cell.hasPiece {
                    nodes[r][c]?.removeFromParent()
                    let fixedNode = makeTileNode(for: cell)
                    fixedNode.position = destination
                    worldNode.addChild(fixedNode)
                    newNodes[r][c] = fixedNode
                } else if let existing = idToNode[cell.id],
                          idToOldPosition[cell.id].flatMap({ oldGrid[$0.r][$0.c]?.tile }) == cell.tile {
                    newNodes[r][c] = existing
                    let old = idToOldPosition[cell.id] ?? Pos(r: 0, c: c)
                    let distance = abs(r - old.r) + abs(c - old.c)
                    if distance == 0 {
                        existing.position = destination
                    } else if transfers.contains(where: { $0.pieceID == cell.id }) {
                        let duration = worldEffects.travelThroughPortals(transfers.filter { $0.pieceID == cell.id },
                            node: existing, destination: destination, delay: columnDelay)
                        latestLanding = max(latestLanding, duration)
                        landingPan = soundPan(at: destination)
                    } else {
                        let duration = fallDuration(rows: distance, isNew: false)
                        existing.run(landingAction(to: destination,
                                                   duration: duration,
                                                   delay: columnDelay))
                        if columnDelay + duration > latestLanding {
                            latestLanding = columnDelay + duration
                            landingPan = soundPan(at: destination)
                        }
                    }
                } else {
                    idToNode[cell.id]?.removeFromParent()
                    let node = makeTileNode(for: cell)
                    let spawnY = gameplayLayout.board.maxY + tileSize * (1.2 + CGFloat(c % 3) * 0.12)
                    node.position = CGPoint(x: destination.x, y: spawnY)
                    worldNode.addChild(node)
                    if transfers.contains(where: { $0.pieceID == cell.id }) {
                        node.position = idToOldPosition[cell.id].map { point(forRow: $0.r, col: $0.c) } ?? destination
                        let duration = worldEffects.travelThroughPortals(transfers.filter { $0.pieceID == cell.id },
                            node: node, destination: destination, delay: columnDelay)
                        newNodes[r][c] = node
                        latestLanding = max(latestLanding, duration)
                        landingPan = soundPan(at: destination)
                        continue
                    }

                    // Stardust trail behind the falling tile — turns the refill
                    // into the "tiles raining in" feel from the references.
                    let trail = Effects.makeFallTrail(tint: UIColor(hex: cell.color))
                    trail.position = .zero
                    trail.zPosition = -0.5
                    node.addChild(trail)

                    let duration = fallDuration(rows: r + 2, isNew: true)
                    node.run(.sequence([
                        landingAction(to: destination,
                                      duration: duration,
                                      delay: columnDelay),
                        .run { [weak trail] in
                            // Stop emitting on landing, then fade the lingering particles.
                            trail?.particleBirthRate = 0
                            trail?.run(.sequence([.wait(forDuration: 0.5),
                                                  .removeFromParent()]))
                        }
                    ]))
                    newNodes[r][c] = node
                    if columnDelay + duration > latestLanding {
                        latestLanding = columnDelay + duration
                        landingPan = soundPan(at: destination)
                    }
                }
            }
        }
        nodes = newNodes
        for p in openedByKeys {
            refreshNode(at: p)
        }

        scheduleBoardResolution(after: latestLanding + (SignatureMotion.isReduced ? 0.02 : SignatureMotion.landingSettleDuration + 0.02)) { scene in
            Audio.shared.play(.landing, pan: landingPan)
            Effects.haptic(.soft, intensity: 0.24)
            scene.resolveCascade()
        }
    }

    func animateBoardMechanicsTick() {
        // Portal cues are emitted only for actual engine-recorded transfers.
        guard !SignatureMotion.isReduced else { return }
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
