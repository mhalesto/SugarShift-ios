import SpriteKit

// Level end
extension GameScene {
    // MARK: - Level end

    func checkLevelEnd() {
        guard !levelEnded else { return }
        if isLevelGoalComplete {
            if movesLeft > 0 {
                completeLevelWithRemainingMoveBonus()
            } else {
                endLevel(won: true)
            }
        } else if movesLeft <= 0 {
            endLevel(won: false)
        }
    }

    var isLevelGoalComplete: Bool {
        switch levelConfig.goal {
        case .score:
            return score >= scoreTarget
        case .clearBlockers:
            return remainingBlockerCount() == 0
        case .collectColor(_, let count):
            return collectedGoalTiles >= count
        case .createSpecials(let count):
            return createdSpecials >= count
        case .detonateBombs(let count):
            return detonatedBombs >= count
        case .collectIngredients(let count):
            return collectedIngredients >= count
        case .collectKeys(let count):
            return collectedKeys >= count
        case .openChests(let count):
            return openedChests >= count
        case .collectIngredientsAndKeys(let ingredients, let keys):
            return collectedIngredients >= ingredients && collectedKeys >= keys
        }
    }

    func failureFeedback() -> String {
        switch levelConfig.goal {
        case .score:
            return "You were \(max(0, scoreTarget - score)) points short."
        case .clearBlockers:
            return "\(remainingBlockerCount()) blockers left."
        case .collectColor(let index, let count):
            let missing = max(0, count - collectedGoalTiles)
            return "\(missing) \(LevelGoal.fruitName(for: index)) pieces left."
        case .createSpecials(let count):
            return "Create \(max(0, count - createdSpecials)) more specials."
        case .detonateBombs(let count):
            return "Detonate \(max(0, count - detonatedBombs)) more bombs."
        case .collectIngredients(let count):
            return "Drop \(max(0, count - collectedIngredients)) more baskets."
        case .collectKeys(let count):
            return "Collect \(max(0, count - collectedKeys)) more keys."
        case .openChests(let count):
            return "Open \(max(0, count - openedChests)) more chests."
        case .collectIngredientsAndKeys(let ingredients, let keys):
            let baskets = max(0, ingredients - collectedIngredients)
            let missingKeys = max(0, keys - collectedKeys)
            return "Drop \(baskets) baskets and \(missingKeys) keys."
        }
    }

    func failureRecommendation() -> String {
        switch levelConfig.goal {
        case .score:
            return levelConfig.difficulty == .normal ? String(localized: "Save specials for one cascade.") : String(localized: "Try a shuffle before the last moves.")
        case .clearBlockers:
            return "Hammer or striped blasts finish blockers."
        case .collectColor(let index, _):
            return "Start near \(LevelGoal.fruitName(for: index)) clusters."
        case .createSpecials:
            return "Look for 4-match and T-shape setups."
        case .detonateBombs:
            return "Swap or hammer bombs near blockers."
        case .collectIngredients:
            return "Clear the column under each basket so it falls faster."
        case .collectKeys:
            return "Clear a path under each key."
        case .openChests:
            return "Match next to chests or drop keys to open them."
        case .collectIngredientsAndKeys:
            return "Work under baskets and keys before spending the last moves."
        }
    }

    func endLevelTargetText() -> String {
        if case .score = levelConfig.goal {
            return "Target  \(scoreTarget)"
        }
        return "Goal  \(levelConfig.goal.title)"
    }

    func showObjectiveCompleteIfNeeded() {
        guard !objectiveCompletionShown, isLevelGoalComplete else { return }
        objectiveCompletionShown = true
        Effects.showComboBanner(text: String(localized: "OBJECTIVE CLEAR!"),
                                color: UIColor(hex: "#34D399"),
                                in: self)
        Effects.notify(.success)
        Audio.shared.play(.combo(depth: 3))
    }

    /// Pays out the long-term star milestone track. Claims every milestone the
    /// player's total stars have reached (so existing saves catch up in one go)
    /// and celebrates with a coin bonus + banner — a reason to 3-star levels.
    func grantStarMilestoneRewardIfDue() {
        let total = Persistence.totalStars
        let step = Persistence.starMilestoneStep
        var claimed = Persistence.claimedStarMilestone
        var totalReward = 0
        while claimed + step <= total {
            claimed += step
            totalReward += 100 + (claimed / step) * 25
        }
        guard totalReward > 0 else { return }
        Persistence.claimedStarMilestone = claimed
        cash += totalReward
        Analytics.track("star_milestone",
                        properties: ["total_stars": "\(claimed)", "reward": "\(totalReward)"])
        let milestone = claimed
        let reward = totalReward
        run(.wait(forDuration: 0.5)) { [weak self] in
            guard let self else { return }
            Effects.showComboBanner(text: String(localized: "\(milestone) STARS!  +\(reward)"),
                                    color: UIColor(hex: "#FACC15"), in: self)
            Effects.notify(.success)
        }
    }

    func completeLevelWithRemainingMoveBonus() {
        let remainingMoves = max(0, movesLeft)
        guard remainingMoves > 0 else {
            endLevel(won: true)
            return
        }

        levelEnded = true
        isResolving = true
        let bonusPoints = remainingMoves * scorePerUnusedMove
        let moveBonus = EndLevelCard.MoveBonus(moves: remainingMoves, points: bonusPoints)

        movesLeft = 0
        score += bonusPoints
        Analytics.track("unused_moves_bonus",
                        properties: ["level": "\(levelNumber)",
                                     "moves": "\(remainingMoves)",
                                     "points": "\(bonusPoints)"])

        Effects.showComboBanner(text: String(localized: "MOVES BONUS!"),
                                color: UIColor(hex: "#FACC15"),
                                in: self)
        Effects.showScorePopup(bonusPoints,
                               at: CGPoint(x: 0, y: size.height * 0.22),
                               in: self,
                               color: UIColor(hex: "#FBBF24"))
        Effects.haptic(.heavy)

        runSugarCrushFinale(seedCount: remainingMoves) { [weak self] in
            self?.endLevel(won: true, moveBonus: moveBonus)
        }
    }

    /// "Sugar Crush" finale: plant a special for each leftover move (capped), then
    /// detonate them together in one spectacular blast before the end card. Fully
    /// self-contained — it does not refill or resume play, so it cannot disturb
    /// the already-decided win state.
    func runSugarCrushFinale(seedCount: Int, completion: @escaping () -> Void) {
        let cap = min(seedCount, 8)
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c], cell.blocker == nil,
                      cell.kind == .normal else { continue }
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle(using: &gameplayRNG)
        let planted = Array(candidates.prefix(cap))
        guard cap > 0, !planted.isEmpty else {
            run(.wait(forDuration: 0.6)) { completion() }
            return
        }

        let specials: [Special] = [.stripedRow, .stripedCol, .wrapped, .bomb]
        for (i, p) in planted.enumerated() {
            grid[p.r][p.c]?.special = specials[i % specials.count]
            refreshNode(at: p)
            nodes[p.r][p.c]?.run(.sequence([
                .wait(forDuration: 0.05 * Double(i)),
                .scale(to: 1.25, duration: 0.10),
                .scale(to: 1.0, duration: 0.12)
            ]))
        }
        Effects.showComboBanner(text: String(localized: "SUGAR CRUSH!"),
                                color: UIColor(hex: "#F472B6"), in: self)
        Effects.haptic(.heavy)

        run(.wait(forDuration: 0.5)) { [weak self] in
            guard let self else { return }
            let plantedSet = Set(planted)
            var affected = Engine.expandMatchesWithSpecials(self.grid, plantedSet, bigger: true)
            affected.formUnion(plantedSet)
            let clearResult = Engine.clearMatches(&self.grid, matches: affected)
            let points = clearResult.affectedCount * 120
            self.score += points
            for q in clearResult.cleared {
                guard let n = self.nodes[q.r][q.c] else { continue }
                let burst = Effects.makeTileBurst(tint: UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF"))
                burst.position = n.position
                self.worldNode.addChild(burst)
                burst.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
                n.run(.sequence([.group([.scale(to: 1.5, duration: 0.12),
                                         .fadeOut(withDuration: 0.18)]),
                                 .removeFromParent()]))
                self.nodes[q.r][q.c] = nil
            }
            Effects.showScorePopup(points,
                                   at: CGPoint(x: 0, y: self.size.height * 0.18),
                                   in: self, color: UIColor(hex: "#FBBF24"))
            Effects.shake(self.worldNode, intensity: 14, duration: 0.4)
            Effects.haptic(.heavy)
            Audio.shared.play(.bomb)
            self.run(.wait(forDuration: 0.7)) { completion() }
        }
    }

    func endLevel(won: Bool, moveBonus: EndLevelCard.MoveBonus? = nil) {
        levelEnded = true
        isResolving = true
        clearGhostPreview()

        let starMovesLeft = moveBonus?.moves ?? max(0, movesLeft)
        let stars = LevelScoring.stars(for: levelConfig,
                                       performance: currentPerformance(effectiveMovesLeft: starMovesLeft),
                                       won: won)

        var rewardResult = CompletionRewardResult()
        let continueBonusOffer = won ? nil : continueOffer()
        var earnedMedals: Persistence.MedalSet = .none

        // Banked total score grows when you win — survives relaunches.
        if won {
            pendingLifeLoss = false
            totalScore += score
            Persistence.recordStars(stars, for: levelNumber)
            grantStarMilestoneRewardIfDue()
            earnedMedals = computeMedals(effectiveMovesLeft: starMovesLeft)
            if earnedMedals != .none {
                Persistence.recordMedals(earnedMedals, for: levelNumber)
                Analytics.track("medals_earned",
                                properties: ["level": "\(levelNumber)",
                                             "no_booster": "\(earnedMedals.noBoosters)",
                                             "moves_spare": "\(earnedMedals.movesToSpare)",
                                             "overshoot": "\(earnedMedals.overshotGoal)"])
            }
            rewardResult = claimCompletionRewardsIfNeeded(stars: stars)
            for reward in rewardResult.all where !reward.summary.isEmpty {
                Effects.showComboBanner(text: reward.summary,
                                        color: UIColor(hex: "#FACC15"),
                                        in: self)
            }
            // Once cleared, the next level becomes the "current" one so the map
            // centres on it and unlocks future tiles via highestUnlockedLevel.
            if levelNumber < Levels.count {
                Persistence.currentLevel = max(Persistence.currentLevel, levelNumber + 1)
            }
            GameCenterService.shared.submitCampaignProgress(
                totalScore: totalScore,
                highestLevel: Persistence.highestUnlockedLevel,
                threeStarLevels: Persistence.threeStarLevelCount(),
                dailyStreak: Persistence.dailyStreak)
        } else if continueBonusOffer == nil {
            pendingLifeLoss = false
            lives = max(0, lives - 1)
        } else {
            pendingLifeLoss = true
        }
        pendingDoubleRewards = won ? rewardResult.all.filter { !$0.isEmpty } : []

        let bonusOffer = won ? doubleRewardOffer(for: pendingDoubleRewards) : continueBonusOffer

        let targetText = endLevelTargetText()
        let outcome: EndLevelCard.Outcome = won
            ? .win(stars: stars, score: score, targetText: targetText, moveBonus: moveBonus)
            : .lose(score: score,
                    targetText: targetText,
                    message: failureFeedback(),
                    recommendation: failureRecommendation())
        Analytics.track(won ? "level_win" : "level_fail",
                        properties: ["level": "\(levelNumber)",
                                     "score": "\(score)",
                                     "target": "\(scoreTarget)",
                                     "moves_left": "\(movesLeft)",
                                     "stars": "\(stars)",
                                     "goal": levelConfig.goal.title,
                                     "goal_progress": goalProgressText()])

        let breakdown = EndLevelCard.Breakdown(
            score: score,
            moveBonus: moveBonus,
            objective: levelConfig.goal.title,
            rewards: rewardResult.general.map(\.summary).filter { !$0.isEmpty }
                + rewardResult.daily.map(\.summary).filter { !$0.isEmpty }
                + rewardResult.event.map(\.summary).filter { !$0.isEmpty },
            threeStarReward: rewardResult.threeStar?.summary,
            newUnlock: Levels.mechanicUnlock(for: min(levelNumber + 1, Levels.count))
        )
        let existingRating = Persistence.ratingForLevel(levelNumber)
        let displayedMedals = won
            ? Persistence.medalsForLevel(levelNumber)
            : Persistence.MedalSet.none
        let card = EndLevelCard(outcome: outcome,
                                sceneSize: size,
                                bonusOffer: bonusOffer,
                                breakdown: won ? breakdown : nil,
                                canRetryForStars: won && stars < 3,
                                showRatingRow: existingRating == nil,
                                existingRating: existingRating,
                                medals: displayedMedals)
        card.position = .zero
        card.alpha = 0
        card.setScale(0.7)
        addChild(card)
        card.run(.group([
            .fadeIn(withDuration: 0.2),
            .scale(to: 1.0, duration: 0.2)
        ]))
        endLevelCard = card
        let ratedLevel = levelNumber
        card.onRating = { [weak self] rating in
            Persistence.recordRating(rating, for: ratedLevel)
            Analytics.track("level_rating",
                            properties: ["level": "\(ratedLevel)",
                                         "rating": rating == .thumbsUp ? "up" : "down",
                                         "won": "\(won)",
                                         "stars": "\(stars)"])
            Effects.haptic(.light)
            _ = self
        }

        card.onPrimary = { [weak self] in
            guard let self = self else { return }
            if won, self.levelNumber < Levels.count {
                self.advanceToLevel(self.levelNumber + 1)
            } else {
                self.settlePendingLifeLoss()
                self.resetLevel()
            }
        }
        card.onSecondary = { [weak self] in
            guard let self = self else { return }
            self.settlePendingLifeLoss()
            // "Choose level" returns to the level map. If no host is wired up,
            // fall back to a local restart so the button is never a dead-end.
            if let onChoose = self.onChooseLevel {
                self.endLevelCard?.dismiss()
                self.endLevelCard = nil
                onChoose()
            } else {
                self.resetLevel()
            }
        }
        card.onBonus = { [weak self] in
            guard let self else { return }
            if won {
                self.doubleRewardsAfterAd()
            } else {
                self.continueAfterRewardedAd()
            }
        }
        card.onRetryForStars = { [weak self] in
            guard let self else { return }
            self.endLevelCard?.dismiss { [weak self] in
                self?.endLevelCard = nil
                self?.resetLevel()
            }
        }

        if won {
            Effects.notify(.success)
            Audio.shared.play(.win)
        } else {
            Effects.notify(.error)
            Audio.shared.play(.lose)
        }
    }

    func advanceToLevel(_ n: Int) {
        endLevelCard?.dismiss()
        endLevelCard = nil
        levelEnded = false
        isResolving = false
        cascadeDepth = 0
        pendingLifeLoss = false
        continueUsedThisAttempt = false
        pendingDoubleRewards = []
        deselect()
        levelConfig = Levels.config(for: n)
        Persistence.currentLevel = max(Persistence.currentLevel, n)
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        startNewGame()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        if let storeKitDeliveryObserver {
            NotificationCenter.default.removeObserver(storeKitDeliveryObserver)
            self.storeKitDeliveryObserver = nil
        }
        if let storeKitProductObserver {
            NotificationCenter.default.removeObserver(storeKitProductObserver)
            self.storeKitProductObserver = nil
        }
        if !levelEnded, score > 0 {
            Analytics.track("level_abandon",
                            properties: ["level": "\(levelNumber)",
                                         "score": "\(score)",
                                         "target": "\(scoreTarget)",
                                         "moves_left": "\(movesLeft)"])
        }
    }

    func observeStoreKitDeliveries() {
        guard storeKitDeliveryObserver == nil else { return }
        storeKitDeliveryObserver = NotificationCenter.default.addObserver(forName: .storeKitCoinsDelivered,
                                                                          object: nil,
                                                                          queue: .main) { [weak self] _ in
            guard let self else { return }
            self.cash = Persistence.cash
            self.shopCard?.setWallet(self.cash)
            Effects.notify(.success)
        }
        storeKitProductObserver = NotificationCenter.default.addObserver(forName: .storeKitProductsLoaded,
                                                                         object: nil,
                                                                         queue: .main) { [weak self] _ in
            guard let self, self.shopCard != nil else { return }
            self.openShop()
        }
    }

    func resetLevel() {
        endLevelCard?.dismiss()
        endLevelCard = nil
        levelEnded = false
        isResolving = false
        cascadeDepth = 0
        pendingLifeLoss = false
        continueUsedThisAttempt = false
        pendingDoubleRewards = []
        deselect()
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        startNewGame()
    }

    func settlePendingLifeLoss() {
        guard pendingLifeLoss else { return }
        pendingLifeLoss = false
        lives = max(0, lives - 1)
    }

    func claimCompletionRewardsIfNeeded(stars: Int) -> CompletionRewardResult {
        var result = CompletionRewardResult()
        if let milestone = Levels.milestoneReward(for: levelNumber),
           !Persistence.hasClaimedMilestoneReward(for: levelNumber) {
            applyReward(milestone)
            Persistence.markMilestoneRewardClaimed(for: levelNumber)
            Analytics.track("milestone_reward_claimed",
                            properties: ["level": "\(levelNumber)",
                                         "reward": milestone.title])
            result.general.append(milestone)
        }

        if levelConfig.isBoss,
           let bossBonus = Levels.bossReward(for: levelNumber),
           !Persistence.hasClaimedBossReward(for: levelNumber) {
            applyReward(bossBonus)
            Persistence.markBossRewardClaimed(for: levelNumber)
            Analytics.track("boss_reward_claimed",
                            properties: ["level": "\(levelNumber)",
                                         "reward": bossBonus.title])
            result.general.append(bossBonus)
        }

        if stars == 3,
           let perfect = Levels.threeStarReward(for: levelNumber),
           !Persistence.hasClaimedThreeStarReward(for: levelNumber) {
            applyReward(perfect)
            Persistence.markThreeStarRewardClaimed(for: levelNumber)
            Analytics.track("three_star_reward_claimed",
                            properties: ["level": "\(levelNumber)",
                                         "reward": perfect.title])
            result.threeStar = perfect
        }

        let daily = Levels.dailyChallenge()
        if levelNumber == daily.level,
           !Persistence.hasClaimedDailyReward(daily.dateKey) {
            applyReward(daily.reward)
            Persistence.markDailyRewardClaimed(daily.dateKey)
            Analytics.track("daily_reward_claimed",
                            properties: ["level": "\(levelNumber)",
                                         "date": daily.dateKey])
            result.daily.append(daily.reward)

            if let streakReward = Levels.dailyStreakReward(streak: Persistence.dailyStreak) {
                applyReward(streakReward)
                Analytics.track("daily_streak_reward_claimed",
                                properties: ["level": "\(levelNumber)",
                                             "streak": "\(Persistence.dailyStreak)"])
                result.daily.append(streakReward)
            }
        }

        for event in Levels.activeEvents() where event.level == levelNumber {
            guard !Persistence.hasClaimedEventReward(event.id) else { continue }
            applyReward(event.reward)
            Persistence.markEventRewardClaimed(event.id)
            Analytics.track("event_reward_claimed",
                            properties: ["level": "\(levelNumber)",
                                         "event": event.title,
                                         "date": event.dateKey])
            result.event.append(event.reward)
        }
        return result
    }

    func applyReward(_ reward: LevelReward) {
        guard !reward.isEmpty else { return }
        cash += Persistence.applyCoinDoubler(reward.coins)
        lives = min(Economy.livesMax, lives + reward.lives)
        shuffleCount += reward.shuffles
        hammerCount += reward.hammers
        swapCount += reward.swaps
        if let themeName = reward.themeName {
            Persistence.unlockTheme(themeName)
        }
    }

    func rewardSummaryText(for rewards: [LevelReward]) -> String {
        let coins = rewards.reduce(0) { $0 + $1.coins }
        let lives = rewards.reduce(0) { $0 + $1.lives }
        let shuffles = rewards.reduce(0) { $0 + $1.shuffles }
        let hammers = rewards.reduce(0) { $0 + $1.hammers }
        let swaps = rewards.reduce(0) { $0 + $1.swaps }
        var parts: [String] = []
        if coins > 0 { parts.append("+\(Persistence.applyCoinDoubler(coins)) coins") }
        if lives > 0 { parts.append("+\(lives) lives") }
        if shuffles > 0 { parts.append("+\(shuffles) shuffles") }
        if hammers > 0 { parts.append("+\(hammers) hammers") }
        if swaps > 0 { parts.append("+\(swaps) swaps") }
        if parts.count > 2 {
            return "Added \(parts[0]), \(parts[1]) + more"
        }
        return parts.isEmpty ? String(localized: "Added to your total") : String(localized: "Added \(parts.joined(separator: " + "))")
    }

    /// Funnels a slice of every match into the piggy bank. `scoreEarned` is
    /// the points added by the match; we add ~1 coin per 100 points, capped
    /// at the piggy max. Call this everywhere the player is credited score
    /// so the bank fills with play, not with rewards.
    func feedPiggyBank(scoreEarned: Int) {
        guard scoreEarned > 0 else { return }
        let portion = max(1, scoreEarned / 100)
        Persistence.addToPiggy(portion)
    }

    func awardCascadeCoinBonus(depth: Int, cleared: Int, at point: CGPoint) {
        guard depth >= 2 else { return }
        let base = min(28, max(3, depth * 2 + cleared / 3))
        let coins = Persistence.applyCoinDoubler(base)
        cash += coins
        Analytics.track("combo_coin_bonus",
                        properties: ["level": "\(levelNumber)",
                                     "depth": "\(depth)",
                                     "cleared": "\(cleared)",
                                     "coins": "\(coins)"])

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "+\(coins) coins"
        label.fontSize = max(13, tileSize * 0.22)
        label.fontColor = UIColor(hex: "#FACC15")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: point.x, y: point.y - tileSize * 0.45)
        label.zPosition = 860
        worldNode.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.14),
                    .moveBy(x: 0, y: tileSize * 0.42, duration: 0.50)]),
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
    }

    func doubleRewardOffer(for rewards: [LevelReward]) -> EndLevelCard.BonusOffer? {
        guard Monetization.rewardedAdsAvailable, !rewards.isEmpty else { return nil }
        return EndLevelCard.BonusOffer(title: String(localized: "Double rewards"),
                                       subtitle: String(localized: "Claim the chest again"),
                                       buttonText: Monetization.rewardedAdButtonText,
                                       enabled: true)
    }

    func doubleRewardsAfterAd() {
        let rewards = pendingDoubleRewards
        guard !rewards.isEmpty else { return }
        RewardedAdService.showRewardedAd(reason: "double_rewards") { [weak self] completed in
            guard let self else { return }
            guard completed else {
                self.endLevelCard?.markBonusFailed()
                Effects.notify(.warning)
                return
            }
            let doubledSummary = self.rewardSummaryText(for: rewards)
            for reward in rewards { self.applyReward(reward) }
            self.pendingDoubleRewards = []
            self.endLevelCard?.markBonusCompleted(title: String(localized: "Rewards doubled"),
                                                  subtitle: doubledSummary)
            Analytics.track("rewarded_ad_completed",
                            properties: ["reason": "double_rewards",
                                         "level": "\(self.levelNumber)",
                                         "reward_count": "\(rewards.count)"])
            Effects.showComboBanner(text: String(localized: "REWARDS DOUBLED!"),
                                    color: UIColor(hex: "#FACC15"),
                                    in: self)
            Effects.notify(.success)
        }
    }

    func continueOffer() -> EndLevelCard.BonusOffer? {
        guard Monetization.rewardedAdsAvailable, !continueUsedThisAttempt else {
            return nil
        }
        let qualifies: Bool
        if case .score = levelConfig.goal {
            qualifies = Monetization.qualifiesForContinueOffer(level: levelNumber,
                                                               score: score,
                                                               target: scoreTarget,
                                                               alreadyUsed: continueUsedThisAttempt)
        } else {
            qualifies = levelNumber >= Monetization.continueOfferMinLevel
                && currentObjectiveProgress() >= Monetization.continueOfferMinScoreRatio
        }
        guard qualifies else { return nil }
        Analytics.track("rewarded_continue_offered",
                        properties: ["level": "\(levelNumber)",
                                     "score": "\(score)",
                                     "target": "\(scoreTarget)",
                                     "goal_progress": goalProgressText()])
        return EndLevelCard.BonusOffer(
            title: "Continue +\(Monetization.rewardedContinueMoves) moves",
            subtitle: String(localized: "One ad, once per try"),
            buttonText: Monetization.rewardedAdButtonText,
            enabled: true
        )
    }

    func continueAfterRewardedAd() {
        RewardedAdService.showRewardedAd(reason: "continue") { [weak self] completed in
            guard let self else { return }
            guard completed else {
                self.endLevelCard?.markBonusFailed()
                Effects.notify(.warning)
                return
            }
            self.continueUsedThisAttempt = true
            self.pendingLifeLoss = false
            self.levelEnded = false
            self.isResolving = false
            self.endLevelCard?.dismiss()
            self.endLevelCard = nil
            self.movesLeft += Monetization.rewardedContinueMoves
            Analytics.track("rewarded_ad_completed",
                            properties: ["reason": "continue",
                                         "level": "\(self.levelNumber)",
                                         "moves": "\(Monetization.rewardedContinueMoves)"])
            Effects.haptic(.medium)
            Effects.notify(.success)
            Effects.showComboBanner(text: "+\(Monetization.rewardedContinueMoves) MOVES",
                                     color: UIColor(hex: "#10B981"),
                                     in: self)
            self.scheduleIdleHint()
        }
    }
}
