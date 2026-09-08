import SpriteKit

// Map modals + public refresh
extension LevelMapScene {
    // MARK: - Map modals

    func openSettings() {
        settingsCard?.dismiss()
        let card = SettingsCard(sceneSize: size)
        card.position = .zero
        addChild(card)
        settingsCard = card

        card.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .close:
                self.settingsCard?.dismiss()
                self.settingsCard = nil
            case .restartLevel:
                self.settingsCard?.dismiss { [weak self] in
                    guard let self else { return }
                    self.settingsCard = nil
                    self.onLevelSelected?(Persistence.currentLevel, nil)
                }
            case .resetProgress:
                self.settingsCard?.dismiss { [weak self] in
                    guard let self else { return }
                    self.settingsCard = nil
                    Persistence.resetAll()
                    self.reloadProgress(animated: true)
                    Effects.notify(.warning)
                }
            case .firebaseSignIn:
                self.signInToFirebaseFromSettings()
            case .firebaseSync:
                self.syncFirebaseFromSettings()
            case .firebaseSignOut:
                FirebaseBackendService.shared.signOut()
                self.reopenSettingsAfterFirebaseAction()
            case .shapedBoardChanged:
                break
            case .visualAccessibilityChanged:
                self.reloadProgress(animated: false)
            case .gameplayAppearanceChanged:
                break
            case .showCombos:
                break
            }
        }
    }

    func signInToFirebaseFromSettings() {
        FirebaseBackendService.shared.signInWithApple(presentationAnchor: view?.window) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.reloadProgress(animated: true)
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
                    self.reloadProgress(animated: true)
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
        shopCard?.dismiss()
        shopCard = nil
        let piggyCoins = Persistence.piggyCoins
        let piggyProgress = CGFloat(piggyCoins) / CGFloat(max(1, Economy.piggyMax))
        let doublerActive = Persistence.coinDoublerActive
        let doublerCountdown = Persistence.coinDoublerCountdownText

        func buildItems() -> [ShopCard.Item] {
            return [
            makeRewardedAdShopItem(iconColor: UIColor(hex: "#10B981")),
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
                  buttonColor: UIColor(hex: "#F472B6"), buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "shuffles5",
                  emojiIcon: "🔀", symbolIcon: nil,
                  iconBg: UIColor(hex: "#BAE6FD"), iconTint: .white,
                  title: String(localized: "+5 Shuffles"),
                  subtitle: String(localized: "Fix a stuck board"),
                  buttonText: "💰 \(Economy.shuffleBundleCost)",
                  buttonColor: UIColor(hex: "#60A5FA"), buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "hammers5",
                  emojiIcon: "🔨", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FED7AA"), iconTint: .white,
                  title: String(localized: "+5 Hammers"),
                  subtitle: String(localized: "Break blockers or finish a combo"),
                  buttonText: "💰 \(Economy.hammerBundleCost)",
                  buttonColor: UIColor(hex: "#F97316"), buttonTextColor: .white,
                  enabled: true,
                  tab: .boosts),
            .init(id: "swaps5",
                  emojiIcon: "✋", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FEF08A"), iconTint: .white,
                  title: String(localized: "+5 Swaps"),
                  subtitle: String(localized: "Create specials on demand"),
                  buttonText: "💰 \(Economy.swapBundleCost)",
                  buttonColor: UIColor(hex: "#FACC15"), buttonTextColor: UIColor(hex: "#0F172A"),
                  enabled: true,
                  tab: .boosts),
            .init(id: "piggyCrack",
                  emojiIcon: "🐷", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FBCFE8"), iconTint: .white,
                  title: String(localized: "Piggy Bank"),
                  subtitle: Persistence.piggyIsFull ? String(localized: "Ready to crack") : String(localized: "Fills as you play"),
                  buttonText: Persistence.piggyIsFull ? String(localized: "Crack") : String(localized: "Filling"),
                  buttonColor: UIColor(hex: "#EC4899"),
                  buttonTextColor: .white,
                  enabled: Persistence.piggyIsFull,
                  tab: .special,
                  isFeatured: true,
                  progress: piggyProgress,
                  meterText: Persistence.piggyIsFull ? String(localized: "Full") : String(localized: "\(piggyCoins)/\(Economy.piggyMax) saved")),
            .init(id: "coinDoubler",
                  emojiIcon: nil, symbolIcon: "bolt.circle.fill",
                  iconBg: UIColor(hex: "#DCFCE7"),
                  iconTint: UIColor(hex: "#16A34A"),
                  title: String(localized: "Coin Doubler"),
                  subtitle: doublerActive ? String(localized: "Active \(doublerCountdown)") : String(localized: "Double play rewards for 24h"),
                  buttonText: doublerActive ? String(localized: "Extend") : "💰 \(Economy.coinDoublerCost)",
                  buttonColor: UIColor(hex: "#16A34A"),
                  buttonTextColor: .white,
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
                  buttonColor: UIColor(hex: "#F472B6"),
                  buttonTextColor: .white,
                  enabled: true,
                  tab: .coins),
            .init(id: "cashL",
                  emojiIcon: "💰", symbolIcon: nil,
                  iconBg: UIColor(hex: "#FEF3C7"), iconTint: .white,
                  title: String(localized: "Large Coin Pack"),
                  subtitle: Monetization.coinPackSubtitle(.large),
                  buttonText: Monetization.coinPackButtonText(.large,
                                                              displayPrice: StoreKitService.shared.displayPrice(for: .large)),
                  buttonColor: UIColor(hex: "#F472B6"),
                  buttonTextColor: .white,
                  enabled: true,
                  tab: .coins)
            ]
        }

        let items = buildItems()

        let card = ShopCard(items: items, walletCash: Persistence.cash, sceneSize: size, refreshItems: buildItems)
        card.position = .zero
        addChild(card)
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
            guard Monetization.rewardedAdsAvailable, Persistence.rewardedAdGate().isAvailable else {
                Effects.notify(.warning)
                return
            }
            RewardedAdService.showRewardedAd(reason: "coins_map") { completed in
                guard completed else { Effects.notify(.warning); return }
                Persistence.recordRewardedAdWatched()
                Persistence.cash += Monetization.rewardedAdCoins
                Analytics.track("rewarded_ad_completed",
                                properties: ["reason": "coins_map",
                                             "coins": "\(Monetization.rewardedAdCoins)"])
                Effects.notify(.success)
                self.refreshHUD()
                self.shopCard?.setWallet(Persistence.cash)
            }
            return
        case "dailyBonusAd":
            let dateKey = Levels.dailyChallenge().dateKey
            guard !Persistence.hasClaimedDailyAdBonus(dateKey) else { return }
            RewardedAdService.showRewardedAd(reason: "daily_bonus_map") { completed in
                guard completed else { Effects.notify(.warning); return }
                Persistence.cash += 140
                Persistence.shuffleCount += 1
                Persistence.hammerCount += 1
                Persistence.markDailyAdBonusClaimed(dateKey)
                Analytics.track("rewarded_ad_completed",
                                properties: ["reason": "daily_bonus_map",
                                             "date": dateKey])
                Effects.notify(.success)
                self.refreshHUD()
                self.shopCard?.setWallet(Persistence.cash)
            }
            return
        case "starterBundle":
            buyBoosterBundle(id: id,
                             cost: Economy.starterBundleCost,
                             livesAdded: 2,
                             shufflesAdded: 3,
                             hammersAdded: 1,
                             swapsAdded: 1)
            return
        case "comboBundle":
            buyBoosterBundle(id: id,
                             cost: Economy.comboBundleCost,
                             livesAdded: 0,
                             shufflesAdded: 3,
                             hammersAdded: 5,
                             swapsAdded: 5)
            return
        case "hardBundle":
            buyBoosterBundle(id: id,
                             cost: Economy.hardLevelBundleCost,
                             livesAdded: 3,
                             shufflesAdded: 5,
                             hammersAdded: 6,
                             swapsAdded: 6)
            return
        case "lives3":
            guard Persistence.lives < Economy.livesMax else { return }
            guard Persistence.cash >= Economy.livesBundleCost else { Effects.notify(.warning); return }
            Persistence.cash -= Economy.livesBundleCost
            Persistence.lives = min(Economy.livesMax, Persistence.lives + 3)
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.livesBundleCost)"])
        case "shuffles5":
            guard Persistence.cash >= Economy.shuffleBundleCost else { Effects.notify(.warning); return }
            Persistence.cash -= Economy.shuffleBundleCost
            Persistence.shuffleCount += 5
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.shuffleBundleCost)"])
        case "hammers5":
            guard Persistence.cash >= Economy.hammerBundleCost else { Effects.notify(.warning); return }
            Persistence.cash -= Economy.hammerBundleCost
            Persistence.hammerCount += 5
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.hammerBundleCost)"])
        case "swaps5":
            guard Persistence.cash >= Economy.swapBundleCost else { Effects.notify(.warning); return }
            Persistence.cash -= Economy.swapBundleCost
            Persistence.swapCount += 5
            Analytics.track("coin_spend", properties: ["item": id, "coins": "\(Economy.swapBundleCost)"])
        case "piggyCrack":
            crackPiggyBank()
            return
        case "coinDoubler":
            buyCoinDoubler()
            return
        case "cashS":
            purchaseCoinPack(.small)
            return
        case "cashL":
            purchaseCoinPack(.large)
            return
        default:
            return
        }
        Effects.notify(.success)
        refreshHUD()
        shopCard?.setWallet(Persistence.cash)
    }

    func crackPiggyBank() {
        guard Persistence.piggyIsFull else { Effects.notify(.warning); return }
        let pot = Persistence.emptyPiggy()
        guard pot > 0 else { return }
        let credited = Persistence.applyCoinDoubler(pot)
        Persistence.cash += credited
        Analytics.track("piggy_bank_cracked",
                        properties: ["coins": "\(credited)",
                                     "base": "\(pot)",
                                     "source": "map"])
        Effects.notify(.success)
        refreshHUD()
        shopCard?.setWallet(Persistence.cash)
        openShop()
    }

    func buyCoinDoubler() {
        guard Persistence.cash >= Economy.coinDoublerCost else { Effects.notify(.warning); return }
        Persistence.cash -= Economy.coinDoublerCost
        Persistence.extendCoinDoubler()
        Analytics.track("coin_spend",
                        properties: ["item": "coinDoubler",
                                     "coins": "\(Economy.coinDoublerCost)",
                                     "source": "map"])
        Effects.notify(.success)
        refreshHUD()
        shopCard?.setWallet(Persistence.cash)
        openShop()
    }

    func buyBoosterBundle(id: String,
                                  cost: Int,
                                  livesAdded: Int,
                                  shufflesAdded: Int,
                                  hammersAdded: Int,
                                  swapsAdded: Int) {
        guard Persistence.cash >= cost else { Effects.notify(.warning); return }
        Persistence.cash -= cost
        Persistence.lives = min(Economy.livesMax, Persistence.lives + livesAdded)
        Persistence.shuffleCount += shufflesAdded
        Persistence.hammerCount += hammersAdded
        Persistence.swapCount += swapsAdded
        Analytics.track("coin_spend", properties: ["item": id, "coins": "\(cost)"])
        Effects.notify(.success)
        refreshHUD()
        shopCard?.setWallet(Persistence.cash)
    }

    func purchaseCoinPack(_ product: CoinProduct) {
        Task { @MainActor in
            switch await StoreKitService.shared.purchase(product) {
            case .delivered(_):
                Effects.notify(.success)
            case .cancelled:
                break
            case .pending:
                Effects.notify(.warning)
            case .failed:
                #if DEBUG
                Persistence.cash += product.coins
                Analytics.track("coin_pack_test_grant_fallback",
                                properties: ["product": product.analyticsName,
                                             "coins": "\(product.coins)"])
                Effects.notify(.success)
                #else
                Effects.notify(.warning)
                #endif
            }
            refreshHUD()
            shopCard?.setWallet(Persistence.cash)
        }
    }

    // MARK: - Public refresh after returning from a level

    /// Re-reads progress from Persistence and updates the map (stars, current level, HUD).
    func reloadProgress(animated: Bool = true) {
        // Rebuild level nodes (stars/lock state may have changed)
        for (_, node) in levelNodes { node.removeFromParent() }
        levelNodes.removeAll()
        avatarMarker?.removeFromParent()
        avatarMarker = nil
        buildLevelNodes()
        placeAvatarMarker()

        refreshHUD()
        scrollToLevel(Persistence.currentLevel, animated: animated)
    }
}
