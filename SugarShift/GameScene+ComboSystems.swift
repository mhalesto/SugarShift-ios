import SpriteKit

enum PlayerSmashTier: String, CaseIterable, Equatable {
    case focused
    case cross
    case mega

    static func tier(for charge: Int) -> PlayerSmashTier? {
        switch charge {
        case 100...: return .mega
        case 75...:  return .cross
        case 50...:  return .focused
        default:      return nil
        }
    }

    /// Tiers the player can afford, ordered from strongest to most efficient.
    /// Keeping the ordering pure makes meter cycling and simulation agree.
    static func available(for charge: Int) -> [PlayerSmashTier] {
        [.mega, .cross, .focused].filter { charge >= $0.chargeCost }
    }

    static func nextAvailable(after current: PlayerSmashTier,
                              charge: Int) -> PlayerSmashTier? {
        let tiers = available(for: charge)
        guard let index = tiers.firstIndex(of: current), index + 1 < tiers.count else {
            return nil
        }
        return tiers[index + 1]
    }

    var chargeCost: Int {
        switch self {
        case .focused: return 50
        case .cross:   return 75
        case .mega:    return 100
        }
    }

    var compactTitle: String {
        switch self {
        case .focused: return String(localized: "FOCUS")
        case .cross:   return String(localized: "CROSS")
        case .mega:    return String(localized: "MEGA")
        }
    }

    var title: String {
        switch self {
        case .focused: return String(localized: "FOCUSED SMASH!")
        case .cross:   return String(localized: "CROSS SMASH!")
        case .mega:    return String(localized: "MEGA SMASH!")
        }
    }

    var scorePerTile: Int {
        switch self {
        case .focused: return 42
        case .cross:   return 50
        case .mega:    return 58
        }
    }

    var bossDamage: Int { self == .mega ? 2 : 1 }
}

/// A pure timing description for a resolved manual clear. Gameplay state is
/// still committed immediately; this plan only controls when each already-known
/// impact is shown, keeping previews, simulation, and the rules engine in sync.
struct ClearPresentationPlan: Equatable {
    enum Kind: Equatable {
        case combo(SpecialComboKind)
        case colorBomb
        case playerSmash(PlayerSmashTier)
    }

    let kind: Kind
    let origin: Pos
    let secondary: Pos?
    let firstSpecial: Special?
    let secondSpecial: Special?
    let fishTargets: [Pos]
    let colorTargets: [Pos]

    var isMajor: Bool {
        switch kind {
        case .playerSmash, .combo(.colorColor), .combo(.bombWrapped),
             .combo(.bombBomb), .combo(.colorWrapped), .combo(.colorBomb):
            return true
        default:
            return false
        }
    }

    func delay(for position: Pos) -> TimeInterval {
        let rowDistance = abs(position.r - origin.r)
        let columnDistance = abs(position.c - origin.c)
        let radial = TimeInterval(max(rowDistance, columnDistance)) * 0.032

        switch kind {
        case .colorBomb:
            if let index = colorTargets.firstIndex(of: position) {
                return 0.10 + TimeInterval(index % 8) * 0.018
            }
            return 0.08 + radial

        case .playerSmash(let tier):
            switch tier {
            case .focused:
                return radial * 0.75
            case .cross:
                let laneDistance = position.r == origin.r ? columnDistance : rowDistance
                return TimeInterval(laneDistance) * 0.020
            case .mega:
                let laneDistance: Int
                if position.r == origin.r {
                    laneDistance = columnDistance
                } else if position.c == origin.c {
                    laneDistance = rowDistance
                } else {
                    laneDistance = min(rowDistance, columnDistance)
                }
                return TimeInterval(laneDistance) * 0.016 + radial * 0.28
            }

        case .combo(let combo):
            switch combo {
            case .stripeStripe, .wrappedStripe, .bombStripe:
                return TimeInterval(min(rowDistance, columnDistance)) * 0.024
            case .colorStripe:
                if let index = colorTargets.firstIndex(of: position) {
                    return 0.08 + TimeInterval(index % 10) * 0.014
                }
                return 0.10 + radial * 0.45
            case .colorWrapped, .colorBomb:
                if let nearest = colorTargets.map({ max(abs(position.r - $0.r), abs(position.c - $0.c)) }).min() {
                    return 0.10 + TimeInterval(nearest) * 0.026
                }
                return 0.10 + radial
            case .colorColor, .advanced:
                return radial
            case .bombBomb, .wrappedWrapped, .bombWrapped:
                return radial
            case .colorFish, .fishStripe, .fishWrapped, .fishBomb, .fishFish:
                if let index = fishTargets.firstIndex(of: position) {
                    return 0.18 + TimeInterval(index) * 0.055
                }
                let targetDelay = fishTargets.enumerated().map { index, target in
                    0.18 + TimeInterval(index) * 0.055
                        + TimeInterval(max(abs(position.r - target.r), abs(position.c - target.c))) * 0.018
                }.min()
                return targetDelay ?? (0.10 + radial)
            }
        }
    }

    func maximumDelay(in positions: Set<Pos>) -> TimeInterval {
        positions.map(delay(for:)).max() ?? 0
    }
}

enum ComboContractKind: String {
    case triggerSpecials
    case damageBlockers
    case combinePowerUps
}

struct ComboContract {
    let kind: ComboContractKind
    let target: Int
    let reward: Int
    let title: String

    static func contract(for config: LevelConfig) -> ComboContract? {
        let level = config.number
        guard level >= 4 else { return nil }
        let reward = min(150, 35 + min(level, Levels.count) / 2)
        if config.isBoss {
            return ComboContract(kind: .combinePowerUps,
                                 target: 1,
                                 reward: reward,
                                 title: String(localized: "Combine 2 power-ups"))
        }
        switch level % 3 {
        case 0:
            let target = level < 40 ? 2 : 3
            return ComboContract(kind: .triggerSpecials,
                                 target: target,
                                 reward: reward,
                                 title: String(localized: "Trigger \(target) specials"))
        case 1:
            guard config.layout.blockerCount > 0 else {
                return ComboContract(kind: .triggerSpecials,
                                     target: 2,
                                     reward: reward,
                                     title: String(localized: "Trigger 2 specials"))
            }
            let target = level < 60 ? 4 : 6
            return ComboContract(kind: .damageBlockers,
                                 target: target,
                                 reward: reward,
                                 title: String(localized: "Hit \(target) blockers in one chain"))
        default:
            return ComboContract(kind: .combinePowerUps,
                                 target: 1,
                                 reward: reward,
                                 title: String(localized: "Combine 2 power-ups"))
        }
    }
}

extension GameScene {
    // MARK: - Turn mastery / Flow

    func finishTurnMastery() {
        let scoreEarned = max(0, score - turnScoreAtStart)
        let outcome = TurnMasteryPolicy.evaluate(
            flow: flowLevel,
            intent: turnIntent,
            tilesCleared: chainTilesCleared,
            blockersDamaged: chainBlockersDamaged,
            specialsTriggered: chainSpecialsTriggered,
            specialsCreated: turnCreatedSpecials,
            objectiveHits: chainObjectiveHits,
            cascadeDepth: cascadeDepth,
            scoreEarned: scoreEarned)

        flowLevel = outcome.flowAfter
        bestFlowLevel = max(bestFlowLevel, flowLevel)
        if outcome.scoreBonus > 0 {
            score += outcome.scoreBonus
            feedPiggyBank(scoreEarned: outcome.scoreBonus)
        }
        if outcome.smashBonus > 0 {
            addSmashCharge(outcome.smashBonus, source: "turn_mastery")
        }
        if outcome.chargesSugarRush {
            chargeSugarRush(source: "flow", depth: cascadeDepth)
        }
        if outcome.flowBefore == 0, outcome.flowAfter > 0 {
            showTeachingToast(
                key: "flow_intro",
                text: String(localized: "Goal-focused moves build Flow. Reach Flow 3 to aim a Sugar Rush cross."),
                delay: 0.75)
        }

        let flowSuffix = flowLevel > 0 ? "  FLOW \(flowLevel)" : ""
        switch outcome.grade {
        case .masterful:
            Effects.showComboBanner(text: String(localized: "MASTERFUL!") + flowSuffix,
                                    color: UIColor(hex: "#A855F7"), in: self)
            Audio.shared.play(.combo(depth: 5))
        case .powerful:
            Effects.showComboBanner(text: String(localized: "POWER PLAY!") + flowSuffix,
                                    color: UIColor(hex: "#F97316"), in: self)
        case .purposeful:
            showStatusToast(String(localized: "PURPOSEFUL!") + flowSuffix)
        case .routine:
            if outcome.flowChanged {
                showStatusToast(String(localized: "FLOW COOLED TO \(flowLevel)"))
            }
        }
        if outcome.scoreBonus > 0 {
            Effects.showScorePopup(outcome.scoreBonus,
                                   at: CGPoint(x: 0, y: boardOrigin.y + tileSize * 0.72),
                                   in: self,
                                   color: UIColor(hex: "#FDE68A"))
        }

        Analytics.track("turn_mastery", properties: [
            "level": "\(levelNumber)",
            "grade": "\(outcome.grade.rawValue)",
            "intent": turnIntent.rawValue,
            "flow_before": "\(outcome.flowBefore)",
            "flow_after": "\(outcome.flowAfter)",
            "score_bonus": "\(outcome.scoreBonus)",
            "smash_bonus": "\(outcome.smashBonus)",
            "objective_hits": "\(chainObjectiveHits)"
        ])
        updateComboMeter()
        showObjectiveCompleteIfNeeded()
    }

    // MARK: - Optional combo contracts

    /// A deterministic optional bonus objective layered on top of the existing
    /// level goal. Contracts add variety without changing campaign completion
    /// or invalidating the balance simulator's established goal model.
    var activeComboContract: ComboContract? {
        ComboContract.contract(for: levelConfig)
    }

    func showComboContractIntroIfNeeded() {
        guard let contract = activeComboContract else { return }
        run(.sequence([
            .wait(forDuration: 1.35),
            .run { [weak self] in
                self?.showStatusToast(String(localized: "Bonus: \(contract.title)  +\(contract.reward)"))
            }
        ]), withKey: "comboContractIntro")
    }

    func updateComboContract(tilesCleared: Int,
                             blockersDamaged: Int,
                             specialsTriggered: Int) {
        guard let contract = activeComboContract, !comboContractCompleted else { return }
        switch contract.kind {
        case .triggerSpecials:
            comboContractProgress += specialsTriggered
        case .damageBlockers:
            comboContractProgress = max(comboContractProgress, chainBlockersDamaged)
        case .combinePowerUps:
            break
        }
        updateComboMeter()
        completeComboContractIfNeeded(contract)
    }

    func recordSpecialComboForContract(kind: SpecialComboKind) {
        if let contract = activeComboContract,
           contract.kind == .combinePowerUps,
           !comboContractCompleted {
            comboContractProgress += 1
            completeComboContractIfNeeded(contract)
        }
        damageBossShield(by: 2, source: kind.rawValue)
        bossDamageAppliedThisTurn = true
    }

    private func completeComboContractIfNeeded(_ contract: ComboContract) {
        guard comboContractProgress >= contract.target, !comboContractCompleted else { return }
        comboContractCompleted = true
        cash += contract.reward
        addSmashCharge(20, source: "contract")
        Effects.showComboBanner(text: String(localized: "BONUS COMPLETE!"),
                                color: UIColor(hex: "#34D399"),
                                in: self)
        Effects.showScorePopup(contract.reward,
                               at: CGPoint(x: 0, y: size.height * 0.18),
                               in: self,
                               color: UIColor(hex: "#FACC15"))
        Effects.notify(.success)
        Analytics.track("combo_contract_completed",
                        properties: ["level": "\(levelNumber)",
                                     "kind": contract.kind.rawValue,
                                     "target": "\(contract.target)",
                                     "reward": "\(contract.reward)"])
    }

    // MARK: - Persistent Smash meter

    func addSmashCharge(_ amount: Int, source: String) {
        guard amount > 0 else { return }
        let old = smashCharge
        smashCharge = min(GameScene.smashChargeMaximum, smashCharge + amount)
        var highestNewTier: Int?
        for (index, tier) in GameScene.comboTiers.enumerated()
            where smashCharge >= tier.count && index + 1 > lastChainTierFired {
            highestNewTier = index
        }
        if let highestNewTier {
            lastChainTierFired = highestNewTier + 1
            fireComboTier(highestNewTier)
        }
        updateComboMeter()
        if old < 50, smashCharge >= 50 {
            Audio.shared.play(.smashReady)
            Effects.haptic(.rigid, intensity: 0.72)
            Analytics.track("smash_available",
                            properties: ["level": "\(levelNumber)",
                                         "source": source,
                                         "charge": "\(smashCharge)"])
        }
        if old < GameScene.smashChargeMaximum,
           smashCharge == GameScene.smashChargeMaximum {
            Analytics.track("smash_ready",
                            properties: ["level": "\(levelNumber)", "source": source])
        }
    }

    func handleSmashMeterTap() {
        guard !levelEnded, !isResolving, movesLeft > 0 else { return }
        if smashTargeting {
            let current = selectedSmashTier ?? PlayerSmashTier.tier(for: smashCharge)
            if let current,
               let next = PlayerSmashTier.nextAvailable(after: current,
                                                        charge: smashCharge) {
                selectedSmashTier = next
                let previewTarget = smashPreviewTarget
                clearPlayerSmashPreview()
                if let previewTarget { showPlayerSmashPreview(at: previewTarget) }
                updateComboMeter()
                Effects.haptic(.light)
                showStatusToast(next.title + " " + String(localized: "TAP A TILE"))
                Analytics.track("smash_tier_changed",
                                properties: ["level": "\(levelNumber)",
                                             "tier": next.rawValue,
                                             "charge": "\(smashCharge)"])
                return
            }
            cancelPlayerSmashTargeting()
            showStatusToast(String(localized: "Smash cancelled"))
            return
        }
        guard let tier = PlayerSmashTier.tier(for: smashCharge) else {
            Effects.haptic(.soft)
            showStatusToast(String(localized: "Build Smash to 50 — \(smashCharge)%"))
            return
        }
        cancelBoosterMode()
        deselect()
        clearGhostPreview()
        selectedSmashTier = tier
        smashPreviewTarget = nil
        smashTargeting = true
        updateComboMeter()
        Effects.haptic(.heavy, intensity: tier == .mega ? 1.0 : 0.78)
        showStatusToast(tier.title + " " + String(localized: "TAP A TILE"))
        Analytics.track("smash_targeting_started",
                        properties: ["level": "\(levelNumber)",
                                     "tier": tier.rawValue,
                                     "charge": "\(smashCharge)"])
    }

    func cancelPlayerSmashTargeting() {
        smashTargeting = false
        selectedSmashTier = nil
        clearPlayerSmashPreview()
        updateComboMeter()
    }

    func activatePlayerSmash(at target: Pos) {
        guard smashTargeting,
              let tier = selectedSmashTier ?? PlayerSmashTier.tier(for: smashCharge),
              smashCharge >= tier.chargeCost,
              !isResolving,
              movesLeft > 0,
              grid[target.r][target.c]?.kind == .normal else { return }

        takeUndoSnapshot()
        clearPlayerSmashPreview()
        turnIntent = .playerSmash
        turnScoreAtStart = score
        turnPrimaryAnchor = target
        smashTargeting = false
        selectedSmashTier = nil
        isResolving = true
        cascadeDepth = 0
        chainTilesCleared = 0
        chainSpecialsTriggered = 0
        chainBlockersDamaged = 0
        chainObjectiveHits = 0
        turnCreatedSpecials = 0
        let spentCharge = tier.chargeCost
        smashCharge = max(0, smashCharge - spentCharge)
        lastChainTierFired = GameScene.comboTiers.filter { smashCharge >= $0.count }.count
        preferredSpecialSpawnPositions.removeAll()
        turnConsumesMove = true
        bossDamageAppliedThisTurn = false
        movesLeft -= 1
        commitTowerFloorIfNeeded()
        updateComboMeter()

        var affected = Engine.playerSmashFootprint(in: grid,
                                                   centeredAt: target,
                                                   tier: tier)
        affected = Engine.expandMatchesWithSpecials(grid,
                                                    affected,
                                                    bigger: specialBlastIsExpanded)
        damageBossShield(by: tier.bossDamage, source: "player_smash_\(tier.rawValue)")
        bossDamageAppliedThisTurn = true
        Analytics.track("player_smash_used",
                        properties: ["level": "\(levelNumber)",
                                     "row": "\(target.r)",
                                     "column": "\(target.c)",
                                     "affected": "\(affected.count)",
                                     "tier": tier.rawValue,
                                     "charge_spent": "\(spentCharge)",
                                     "charge_remaining": "\(smashCharge)"])
        let plan = ClearPresentationPlan(kind: .playerSmash(tier),
                                         origin: target,
                                         secondary: nil,
                                         firstSpecial: nil,
                                         secondSpecial: nil,
                                         fishTargets: [],
                                         colorTargets: [])
        resolveManualClear(affected,
                           banner: tier.title,
                           tint: UIColor(hex: "#A855F7"),
                           scorePerTile: tier.scorePerTile,
                           center: point(forRow: target.r, col: target.c),
                           presentation: plan)
    }

    // MARK: - Boss shield + pressure phase

    func configureBossForNewAttempt() {
        guard levelConfig.isBoss else {
            bossShieldMaximum = 0
            bossShieldRemaining = 0
            bossTurnsUntilPressure = 0
            return
        }
        bossShieldMaximum = levelNumber >= 100 ? 3 : 2
        bossShieldRemaining = bossShieldMaximum
        bossTurnsUntilPressure = 4
    }

    var isBossShieldBroken: Bool {
        !levelConfig.isBoss || bossShieldRemaining <= 0
    }

    func damageBossShield(by amount: Int, source: String) {
        guard levelConfig.isBoss, bossShieldRemaining > 0, amount > 0 else { return }
        let old = bossShieldRemaining
        bossShieldRemaining = max(0, bossShieldRemaining - amount)
        objectiveTracker.consume(.bossShieldDamaged(count: old - bossShieldRemaining))
        guard bossShieldRemaining != old else { return }
        updateHUD()
        updateComboMeter()
        if bossShieldRemaining == 0 {
            Effects.showComboBanner(text: String(localized: "CROWN BROKEN!"),
                                    color: UIColor(hex: "#FACC15"), in: self)
            Effects.notify(.success)
        } else {
            showStatusToast(String(localized: "Crown shield \(bossShieldRemaining)/\(bossShieldMaximum)"))
            Effects.haptic(.heavy)
        }
        Analytics.track("boss_shield_damaged",
                        properties: ["level": "\(levelNumber)",
                                     "amount": "\(old - bossShieldRemaining)",
                                     "remaining": "\(bossShieldRemaining)",
                                     "source": source])
    }

    func tickBossPressureIfNeeded() {
        guard levelConfig.isBoss,
              bossShieldRemaining > 0,
              turnConsumesMove,
              !isPrimaryGoalComplete,
              movesLeft > 0 else { return }
        bossTurnsUntilPressure -= 1
        guard bossTurnsUntilPressure <= 0 else { return }
        bossTurnsUntilPressure = bossShieldRemaining == bossShieldMaximum ? 4 : 3

        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c],
                      cell.blocker == nil,
                      cell.kind == .normal,
                      cell.special == nil else { continue }
                candidates.append(Pos(r: r, c: c))
            }
        }
        guard let target = candidates.randomElement(using: &gameplayRNG) else { return }
        grid[target.r][target.c]?.blocker = Blocker(type: .vine, hits: 1)
        if case .clearBlockers = levelConfig.goal {
            startingBlockers += 1
        }
        refreshNode(at: target)
        nodes[target.r][target.c]?.run(.sequence([
            .scale(to: 1.16, duration: 0.10),
            .scale(to: 1.0, duration: 0.14)
        ]))
        Effects.showComboBanner(text: String(localized: "CROWN STRIKE!"),
                                color: UIColor(hex: "#EF4444"), in: self)
        Audio.shared.play(.crate)
        Analytics.track("boss_pressure_tick",
                        properties: ["level": "\(levelNumber)",
                                     "row": "\(target.r)",
                                     "column": "\(target.c)",
                                     "shield": "\(bossShieldRemaining)"])
    }

    // MARK: - Deterministic combo targeting and previews

    func fishTargets(count: Int, excluding: Set<Pos>) -> [Pos] {
        guard count > 0 else { return [] }
        return Array(TacticalMoveEvaluator.rankedTargets(in: grid,
                                                         config: levelConfig,
                                                         excluding: excluding)
            .prefix(count))
    }

    func addingObjectiveFishTargets(to matches: Set<Pos>, in sourceGrid: Grid? = nil) -> Set<Pos> {
        matches.union(objectiveFishDestinations(for: matches, in: sourceGrid).values)
    }

    func objectiveFishDestinations(for matches: Set<Pos>, in sourceGrid: Grid? = nil) -> [Pos: Pos] {
        let source = sourceGrid ?? grid
        let origins = matches.filter { source[$0.r][$0.c]?.special == .fish }.sorted {
            $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r
        }
        guard !origins.isEmpty else { return [:] }
        let targets = TacticalMoveEvaluator.rankedTargets(in: source, config: levelConfig, excluding: matches)
        return Dictionary(uniqueKeysWithValues: zip(origins, targets.prefix(origins.count)))
    }

    func specialComboAffectedPositions(kind: SpecialComboKind,
                                       first: Special,
                                       second: Special,
                                       positions: (Pos, Pos),
                                       targetColor: String?,
                                       in sourceGrid: Grid? = nil) -> Set<Pos> {
        let source = sourceGrid ?? grid
        let rankedTargets = fishTargets(count: 16,
                                        excluding: [positions.0, positions.1])
        return Engine.resolveSpecialCombo(source,
                                          kind: kind,
                                          first: first,
                                          second: second,
                                          positions: positions,
                                          targetColor: targetColor,
                                          rankedFishTargets: rankedTargets,
                                          bigger: specialBlastIsExpanded)
    }

    func presentationPlan(kind: SpecialComboKind,
                          first: Special,
                          second: Special,
                          positions: (Pos, Pos),
                          targetColor: String?) -> ClearPresentationPlan {
        let ranked = fishTargets(count: 16, excluding: [positions.0, positions.1])
        let colorTargets: [Pos]
        if let targetColor {
            colorTargets = (0..<rows).flatMap { r in
                (0..<cols).compactMap { c in
                    grid[r][c]?.color == targetColor ? Pos(r: r, c: c) : nil
                }
            }
        } else {
            colorTargets = []
        }

        let fishCount: Int
        switch kind {
        case .colorFish:   fishCount = min(8, max(4, colorTargets.count / 2))
        case .fishStripe: fishCount = 4
        case .fishWrapped: fishCount = 3
        case .fishBomb: fishCount = 5
        case .fishFish: fishCount = 4
        default: fishCount = 0
        }

        return ClearPresentationPlan(kind: .combo(kind),
                                     origin: positions.1,
                                     secondary: positions.0,
                                     firstSpecial: first,
                                     secondSpecial: second,
                                     fishTargets: Array(ranked.prefix(fishCount)),
                                     colorTargets: colorTargets)
    }

    func playClearPresentation(_ plan: ClearPresentationPlan, tint: UIColor) {
        let origin = point(forRow: plan.origin.r, col: plan.origin.c)
        let pan = soundPan(at: origin)
        if plan.isMajor { Audio.shared.duckMusic(for: 0.55) }
        Effects.prepareHaptics()

        func add(_ effect: SKNode, after delay: TimeInterval = 0) {
            if delay <= 0 {
                worldNode.addChild(effect)
            } else {
                run(.sequence([
                    .wait(forDuration: delay),
                    .run { [weak self] in self?.worldNode.addChild(effect) }
                ]))
            }
        }
        func rowSweep(_ row: Int, delay: TimeInterval = 0) {
            guard row >= 0, row < rows else { return }
            let start = point(forRow: row, col: 0)
            let end = point(forRow: row, col: cols - 1)
            add(Effects.makeEnergySweep(from: start, to: end,
                                        tint: tint, width: 13,
                                        delay: delay))
        }
        func columnSweep(_ column: Int, delay: TimeInterval = 0) {
            guard column >= 0, column < cols else { return }
            let start = point(forRow: rows - 1, col: column)
            let end = point(forRow: 0, col: column)
            add(Effects.makeEnergySweep(from: start, to: end,
                                        tint: tint, width: 13,
                                        delay: delay))
        }
        func threeRows(around row: Int) {
            for (index, value) in (-1...1).enumerated() {
                rowSweep(row + value, delay: TimeInterval(index) * 0.035)
            }
        }
        func threeColumns(around column: Int) {
            for (index, value) in (-1...1).enumerated() {
                columnSweep(column + value, delay: TimeInterval(index) * 0.035)
            }
        }
        func radial(at position: Pos,
                    delay: TimeInterval = 0,
                    scale: CGFloat = 1) {
            let blast = Effects.makeBombBlast(at: point(forRow: position.r, col: position.c))
            blast.setScale(scale)
            add(blast, after: delay)
        }
        func wrappedPulse(at position: Pos, delay: TimeInterval = 0) {
            radial(at: position, delay: delay, scale: 0.72)
            radial(at: position, delay: delay + 0.09, scale: 1.02)
        }
        func targetSparkle(at position: Pos, delay: TimeInterval) {
            let sparkle = Effects.makeStarSparkle(count: 9)
            sparkle.position = point(forRow: position.r, col: position.c)
            sparkle.zPosition = 775
            add(sparkle, after: delay)
        }
        func colorLinks(limit: Int = 12) {
            for (index, target) in plan.colorTargets.prefix(limit).enumerated() {
                let end = point(forRow: target.r, col: target.c)
                add(Effects.makeEnergySweep(from: origin,
                                            to: end,
                                            tint: tint,
                                            width: 5,
                                            delay: TimeInterval(index) * 0.014))
            }
        }
        func fishFlights() {
            for (index, target) in plan.fishTargets.enumerated() {
                let end = point(forRow: target.r, col: target.c)
                add(Effects.makeFishFlight(from: origin,
                                           to: end,
                                           tint: tint,
                                           delay: TimeInterval(index) * 0.055))
            }
        }

        switch plan.kind {
        case .colorBomb:
            Audio.shared.play(.colorCharge, pan: pan)
            colorLinks(limit: 14)
            radial(at: plan.origin, delay: 0.08)

        case .playerSmash(let tier):
            Audio.shared.play(.smash, pan: pan)
            switch tier {
            case .focused:
                radial(at: plan.origin)
            case .cross:
                rowSweep(plan.origin.r)
                columnSweep(plan.origin.c, delay: 0.035)
            case .mega:
                rowSweep(plan.origin.r)
                columnSweep(plan.origin.c, delay: 0.025)
                radial(at: plan.origin, delay: 0.04)
            }

        case .combo(let kind):
            let secondary = plan.secondary ?? plan.origin
            let firstPosition = plan.origin
            let secondPosition = secondary
            switch kind {
            case .stripeStripe:
                Audio.shared.play(.stripe, pan: pan)
                rowSweep(plan.origin.r)
                columnSweep(plan.origin.c)
            case .wrappedStripe:
                Audio.shared.play(.wrapped, pan: pan)
                Audio.shared.play(.stripe, pan: pan)
                wrappedPulse(at: plan.origin)
                threeRows(around: plan.origin.r)
                threeColumns(around: plan.origin.c)
            case .bombStripe:
                Audio.shared.play(.bomb, pan: pan)
                Audio.shared.play(.stripe, pan: pan)
                radial(at: plan.origin)
                if plan.firstSpecial == .stripedRow || plan.secondSpecial == .stripedRow {
                    threeRows(around: plan.origin.r)
                } else {
                    threeColumns(around: plan.origin.c)
                }
            case .colorStripe:
                Audio.shared.play(.colorCharge, pan: pan)
                Audio.shared.play(.stripe, pan: pan)
                colorLinks()
                let rowsToClear = Set(plan.colorTargets.map(\.r)).sorted()
                let columnsToClear = Set(plan.colorTargets.map(\.c)).sorted()
                if plan.firstSpecial == .stripedRow || plan.secondSpecial == .stripedRow {
                    for (index, row) in rowsToClear.enumerated() {
                        rowSweep(row, delay: 0.08 + TimeInterval(index) * 0.018)
                    }
                } else {
                    for (index, column) in columnsToClear.enumerated() {
                        columnSweep(column, delay: 0.08 + TimeInterval(index) * 0.018)
                    }
                }
            case .colorWrapped:
                Audio.shared.play(.colorCharge, pan: pan)
                Audio.shared.play(.wrapped, pan: pan)
                colorLinks()
                for (index, target) in plan.colorTargets.prefix(8).enumerated() {
                    wrappedPulse(at: target, delay: 0.09 + TimeInterval(index) * 0.022)
                }
            case .colorBomb:
                Audio.shared.play(.colorCharge, pan: pan)
                Audio.shared.play(.bomb, pan: pan)
                colorLinks()
                for (index, target) in plan.colorTargets.prefix(8).enumerated() {
                    radial(at: target,
                           delay: 0.09 + TimeInterval(index) * 0.022,
                           scale: 0.88)
                }
            case .colorColor, .advanced:
                Audio.shared.play(.colorCharge, pan: pan)
                Audio.shared.play(.smash, pan: pan)
                radial(at: plan.origin)
                flashScreenTint(tint.withAlphaComponent(0.24), duration: 0.46)
            case .bombBomb:
                Audio.shared.play(.smash, pan: pan)
                radial(at: plan.origin, scale: 1.12)
                radial(at: plan.origin, delay: 0.09, scale: 0.86)
            case .bombWrapped:
                Audio.shared.play(.bomb, pan: pan)
                Audio.shared.play(.wrapped, pan: pan)
                radial(at: plan.origin, scale: 0.92)
                wrappedPulse(at: plan.origin, delay: 0.10)
            case .wrappedWrapped:
                Audio.shared.play(.wrapped, pan: pan)
                wrappedPulse(at: firstPosition)
                wrappedPulse(at: secondPosition, delay: 0.10)
            case .colorFish:
                Audio.shared.play(.colorCharge, pan: pan)
                Audio.shared.play(.fish, pan: pan)
                colorLinks(limit: 10)
                fishFlights()
            case .fishStripe:
                Audio.shared.play(.fish, pan: pan)
                Audio.shared.play(.stripe, pan: pan)
                fishFlights()
                for (index, target) in plan.fishTargets.enumerated() {
                    if plan.firstSpecial == .stripedRow || plan.secondSpecial == .stripedRow {
                        rowSweep(target.r, delay: 0.18 + TimeInterval(index) * 0.055)
                    } else {
                        columnSweep(target.c, delay: 0.18 + TimeInterval(index) * 0.055)
                    }
                }
            case .fishWrapped:
                Audio.shared.play(.fish, pan: pan)
                Audio.shared.play(.wrapped, pan: pan)
                fishFlights()
                for (index, target) in plan.fishTargets.enumerated() {
                    wrappedPulse(at: target,
                                 delay: 0.18 + TimeInterval(index) * 0.055)
                }
            case .fishBomb:
                Audio.shared.play(.fish, pan: pan)
                Audio.shared.play(.bomb, pan: pan)
                fishFlights()
                for (index, target) in plan.fishTargets.enumerated() {
                    radial(at: target,
                           delay: 0.18 + TimeInterval(index) * 0.055,
                           scale: 0.76)
                }
            case .fishFish:
                Audio.shared.play(.fish, pan: pan)
                fishFlights()
                for (index, target) in plan.fishTargets.enumerated() {
                    targetSparkle(at: target,
                                  delay: 0.20 + TimeInterval(index) * 0.055)
                }
            }
        }

        Effects.haptic(plan.isMajor ? .heavy : .medium,
                       intensity: plan.isMajor ? 1.0 : 0.76)
        switch plan.kind {
        case .playerSmash(.mega), .combo(.colorColor):
            spawnConfetti()
        default:
            break
        }
        if plan.isMajor {
            run(.sequence([.wait(forDuration: 0.11),
                           .run { Effects.haptic(.rigid, intensity: 0.88) }]))
        }
    }

    func soundPan(at point: CGPoint) -> Float {
        guard size.width > 0 else { return 0 }
        return Float(max(-1, min(1, point.x / (size.width * 0.44))))
    }

    func specialComboPresentation(for kind: SpecialComboKind) -> (String, UIColor) {
        switch kind {
        case .advanced: return (worldTheme.comboTitle, worldTheme.glowColor)
        case .colorColor: return (String(localized: "BOARD CLEAR!"), UIColor(hex: "#F472B6"))
        case .stripeStripe: return (String(localized: "DOUBLE STRIPE!"), UIColor(hex: "#60A5FA"))
        case .wrappedStripe: return (String(localized: "WRAPPED STRIPE!"), UIColor(hex: "#F97316"))
        case .bombStripe: return (String(localized: "BOMB LINES!"), UIColor(hex: "#EF4444"))
        case .colorStripe: return (String(localized: "RAINBOW STRIPES!"), UIColor(hex: "#A78BFA"))
        case .colorWrapped: return (String(localized: "RAINBOW WRAP!"), UIColor(hex: "#F472B6"))
        case .colorBomb: return (String(localized: "RAINBOW BOOM!"), UIColor(hex: "#FACC15"))
        case .colorFish: return (String(localized: "RAINBOW SCHOOL!"), UIColor(hex: "#22D3EE"))
        case .bombBomb: return (String(localized: "MEGA BOOM!"), UIColor(hex: "#EF4444"))
        case .wrappedWrapped: return (String(localized: "DOUBLE WRAP!"), UIColor(hex: "#FB923C"))
        case .bombWrapped: return (String(localized: "SUPER BLAST!"), UIColor(hex: "#F97316"))
        case .fishStripe: return (String(localized: "STRIPED SCHOOL!"), UIColor(hex: "#38BDF8"))
        case .fishWrapped: return (String(localized: "WRAPPED SCHOOL!"), UIColor(hex: "#2DD4BF"))
        case .fishBomb: return (String(localized: "BOMB SCHOOL!"), UIColor(hex: "#FACC15"))
        case .fishFish: return (String(localized: "FISH FRENZY!"), UIColor(hex: "#22D3EE"))
        }
    }

}
