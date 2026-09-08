import SpriteKit

final class GameScene: SKScene {

    /// Set by GameViewController. Fired when the player taps "Choose level"
    /// on the end-of-level card so the host VC can dismiss back to the map.
    var onChooseLevel: (() -> Void)?
    var initialLevel: Int?
    var initialDailyChallenge: DailyChallenge?

    // MARK: - Config (driven by Levels catalog)

    var levelConfig: LevelConfig = Levels.config(for: 1)
    /// Probability that a refilled tile is forced to a colour that completes a
    /// match, manufacturing cascades. High in early levels so the game feels
    /// generous and cinematic, then ramps down as the campaign expects skill.
    var cascadeBoostForLevel: Double {
        let rangeBase: Double
        switch levelNumber {
        case 1...5:     rangeBase = 0.12
        case 6...10:    rangeBase = 0.10
        case 11...25:   rangeBase = 0.07
        case 26...50:   rangeBase = 0.05
        case 51...100:  rangeBase = 0.035
        case 101...150: rangeBase = 0.025
        default:        rangeBase = 0.02
        }

        let archetypeBoost: Double
        switch levelConfig.archetype {
        case .starter: archetypeBoost = 0.01
        case .combo: archetypeBoost = 0.02
        case .bombRush: archetypeBoost = 0.01
        case .crowded: archetypeBoost = 0.005
        case .ice, .lock, .finale: archetypeBoost = 0
        }

        let difficultyDrag: Double
        switch levelConfig.difficulty {
        case .normal: difficultyDrag = 0
        case .hard: difficultyDrag = 0.03
        case .superHard: difficultyDrag = 0.05
        case .crownChallenge: difficultyDrag = 0.06
        }

        let failCount = Analytics.levelStats(for: levelNumber)["fails"] ?? 0
        let earnedAssist: Double = failCount >= 4 ? 0.07 : (failCount >= 2 ? 0.035 : 0)
        return min(0.20, max(0, rangeBase + archetypeBoost + earnedAssist - difficultyDrag))
    }

    /// Boost only applies for the first few automatic cascades; after that we
    /// refill with pure random colors so the chain has to terminate. Keeps
    /// early levels punchy without spinning into an infinite combo loop.
    var currentCascadeBoost: Double {
        cascadeDepth <= 2 ? cascadeBoostForLevel : 0
    }
    var specialBlastIsExpanded: Bool {
        levelConfig.modifiers.contains(.specialsExplodeBigger)
    }
    var rows: Int { levelConfig.rows }
    var cols: Int { levelConfig.cols }
    var palette: [String] { levelConfig.pieceTypes.map(\.legacyToken) }
    var skin: BoardSkin { levelConfig.skin }

    var levelNumber: Int { levelConfig.number }
    var movesAtStart: Int { levelConfig.moves }
    var scoreTarget: Int { levelConfig.target }
    let scorePerUnusedMove = 100
    /// Turns a detonated countdown fuse re-arms to.
    let countdownFuseRearm = 5

    // Persistent economy state — loaded from UserDefaults on scene init
    let livesMax = Economy.livesMax
    var lives = 5            { didSet { Persistence.lives = lives; PushService.shared.scheduleLifeRegenNotificationIfNeeded(); updateHUD() } }
    var totalScore = 0       { didSet { Persistence.totalScore = totalScore;  updateHUD() } }
    var cash = Economy.startingCash { didSet { Persistence.cash = cash;       updateHUD() } }

    var endLevelCard: EndLevelCard?
    var levelEnded = false
    var pendingLifeLoss = false
    var continueUsedThisAttempt = false
    var coinPromptShownThisAttempt = false
    var pendingDoubleRewards: [LevelReward] = []

    struct CompletionRewardResult {
        var general: [LevelReward] = []
        var threeStar: LevelReward?
        var daily: [LevelReward] = []
        var event: [LevelReward] = []

        var all: [LevelReward] {
            general + [threeStar].compactMap { $0 } + daily + event
        }
    }

    // MARK: - Game state

    var grid: Grid = []
    var nodes: [[SKNode?]] = []
    var tileSize: CGFloat = 0
    var gap: CGFloat = 0
    var boardOrigin: CGPoint = .zero
    var safeTop: CGFloat = 0
    var safeBottom: CGFloat = 0

    var firstSelection: Pos?
    var firstSelectionNode: SKNode?
    var dragStartPoint: CGPoint?
    var gamePhase: GamePhase = .waitingForInput
    var isResolving = false {
        didSet {
            if isResolving {
                if gamePhase.acceptsBoardInput { gamePhase = .resolvingMatches }
            } else if !levelEnded {
                gamePhase = .waitingForInput
            }
        }
    }
    var canAcceptBoardInput: Bool {
        !isResolving && !levelEnded && gamePhase.acceptsBoardInput
            && settingsCard == nil && shopCard == nil && modalCard == nil
            && preLevelPerkOverlay == nil && towerOverlay == nil
            && levelTesterOverlay == nil
    }
    var gameplayLayout: GameplayLayout {
        GameplayLayout(size: size, safeTop: safeTop, safeBottom: safeBottom,
                       rows: rows, columns: cols)
    }
    var conveyorAdvancedThisTurn = false
    var cascadeDepth = 0
    /// Once a deep cascade crosses the confetti threshold, every later step
    /// crosses it too; this keeps one chain from stacking emitters.
    var lastConfettiAt: TimeInterval = 0
    /// The destination tile of the player's latest swap is preferred when the
    /// first cascade creates a special, making placement intentional instead of
    /// always choosing the geometric middle of the match.
    var preferredSpecialSpawnPositions: [Pos] = []
    var levelAttemptSeed = LevelSeed.make(level: 1)
    #if DEBUG
    /// One-shot seed override for the next `startNewGame()` — the tester
    /// overlay's "Replay seed" entry. Paste the `seed` value logged in
    /// `level_start` analytics to relaunch that exact opening board.
    var debugReplaySeed: UInt64?
    #endif
    var gameplayRNG = SeededRandomNumberGenerator(seed: LevelSeed.make(level: 1, salt: 0x51F7))
    /// True when this attempt is today's daily challenge. The board comes from
    /// the shared date seed (identical for every player worldwide), and the
    /// per-player board mutations (pre-level perks, fail-streak assist) are
    /// disabled so the leaderboard compares the same puzzle.
    var isDailyChallengeRun = false
    /// Exact challenge captured when this attempt was launched. Never
    /// recomputed at completion because the run can span local midnight.
    var dailyChallengeRun: DailyChallenge?
    /// Snapshot of the daily board before the first move — rendered into the
    /// emoji share grid. Same for everyone, so it spoils nothing.
    var dailyStartGrid: Grid = []
    /// True when the player damaged a chocolate tile during the current turn.
    /// Reset at the start of each swap; checked at the end of the cascade so
    /// "adjacent matching" actually keeps the spread under control.
    var chocolateDamagedThisTurn = false

    // Idle-hint state — when the board sits idle for `idleHintDelay` seconds we
    // pulse a valid swap to nudge the player.
    let idleHintDelay: TimeInterval = 5.0
    var hintRings: [SKNode] = []
    var hintTiles: [SKNode] = []
    var hintArrow: SKNode?
    var hintShownThisLevel = 0
    var freeStuckReshufflesThisLevel = 0

    // +Moves booster: quantity selector state
    let quantityOptions: [Int] = [1, 5, 10, 25, 50]
    var movesQuantity: Int = 5 { didSet { Persistence.movesQuantity = movesQuantity } }
    var movesBuyCost: Int { Economy.costForMoves(quantity: movesQuantity) }
    weak var movesBoosterCircle: SKShapeNode?
    weak var movesQuantityBadge: SKShapeNode?
    weak var movesQuantityBadgeLabel: SKLabelNode?
    var quantityPopup: SKNode?

    // Other booster state
    enum BoosterMode { case none, hammer, swap }
    var boosterMode: BoosterMode = .none
    var swapFirstPick: Pos?
    var swapFirstNode: SKNode?
    var boosterCircles: [String: SKShapeNode] = [:]
    var boosterHintLabel: SKLabelNode?
    var shuffleCount = 2 { didSet { Persistence.shuffleCount = shuffleCount } }
    var hammerCount = 0 { didSet { Persistence.hammerCount = hammerCount } }
    var swapCount = 0   { didSet { Persistence.swapCount = swapCount } }
    var shopCard: ShopCard?
    var settingsCard: SettingsCard?
    let hammerCost = Economy.hammerCost
    let swapCost = Economy.swapCost
    let lifeCost = Economy.lifeCost
    var modalCard: SKNode?
    var modalPrimaryAction: (() -> Void)?
    var storeKitDeliveryObserver: NSObjectProtocol?
    var storeKitProductObserver: NSObjectProtocol?
    var levelTesterOverlay: SKNode?
    /// Active Sugar Tower run when this scene is playing a tower floor
    /// (`levelNumber == Levels.towerLevel`); nil for every other mode.
    var towerRun: TowerRun?
    var towerOverlay: SKNode?
    var preLevelPerkOverlay: SKNode?
    var preLevelPerkApplied = false
    enum PreLevelPerk: String {
        case bomb
        case moves
        case blockers
    }

    var score: Int = 0 { didSet { objectiveTracker.consume(.scoreEarned(max(0, score - oldValue))); updateHUD() } }
    var movesLeft: Int = 0 { didSet { updateHUD(); maybeLowMovesTension(old: oldValue) } }
    var startingBlockers = 0 { didSet { updateHUD() } }
    var collectedGoalTiles = 0 { didSet { updateHUD() } }
    var createdSpecials = 0 { didSet { objectiveTracker.consume(.specialsCreated(count: max(0, createdSpecials - oldValue))); updateHUD() } }
    var detonatedBombs = 0 { didSet { objectiveTracker.consume(.bombsDetonated(count: max(0, detonatedBombs - oldValue))); updateHUD() } }
    var collectedIngredients = 0 { didSet { objectiveTracker.consume(.ingredientsCollected(count: max(0, collectedIngredients - oldValue))); updateHUD() } }
    var collectedKeys = 0 { didSet { objectiveTracker.consume(.keysCollected(count: max(0, collectedKeys - oldValue))); updateHUD() } }
    var openedChests = 0 { didSet { updateHUD() } }
    var maxCascadeDepth = 0
    var totalCascadeClears = 0
    var objectiveCompletionShown = false
    var mercySpecialGrantedThisAttempt = false

    // MARK: - Mastery medals tracking
    /// Flipped to true whenever the player spends a paid booster or burns a
    /// stocked one during this attempt. Resets in `startNewGame()`.
    var boosterUsedThisAttempt = false

    // MARK: - Undo last move
    /// One-move snapshot taken at the start of every player swap. Overwritten
    /// on each new swap so only the most recent move is undoable.
    struct UndoSnapshot {
        let objectiveTracker: ObjectiveTracker
        let grid: Grid
        let nodes: [[SKNode?]]
        let score: Int
        let movesLeft: Int
        let collectedGoalTiles: Int
        let createdSpecials: Int
        let detonatedBombs: Int
        let collectedIngredients: Int
        let collectedKeys: Int
        let openedChests: Int
        let cash: Int
        let shuffleCount: Int
        let hammerCount: Int
        let swapCount: Int
        let piggyCoins: Int
        let maxCascadeDepth: Int
        let totalCascadeClears: Int
        let objectiveCompletionShown: Bool
        let boosterUsedThisAttempt: Bool
        let chainTilesCleared: Int
        let chainSpecialsTriggered: Int
        let chainBlockersDamaged: Int
        let chainObjectiveHits: Int
        let lastChainTierFired: Int
        let smashCharge: Int
        let smashTargeting: Bool
        let selectedSmashTier: PlayerSmashTier?
        let comboContractProgress: Int
        let comboContractCompleted: Bool
        let bossShieldRemaining: Int
        let bossTurnsUntilPressure: Int
        let chocolateDamagedThisTurn: Bool
        let syrupRow: Int
        let syrupMovesSinceTick: Int
        let sugarRushCharged: Bool
        let mercySpecialGrantedThisAttempt: Bool
        let flowLevel: Int
        let bestFlowLevel: Int
    }
    var undoSnapshot: UndoSnapshot?
    var freeUndoUsedThisLevel = false
    weak var undoButton: SKNode?
    weak var undoBadge: SKLabelNode?

    // MARK: - Combo / Smash systems
    /// Per-turn chain statistics feed one shared value formula. `smashCharge`
    /// persists across turns so strong play builds toward a player-timed move.
    var chainTilesCleared = 0
    var chainSpecialsTriggered = 0
    var chainBlockersDamaged = 0
    var chainObjectiveHits = 0
    var turnCreatedSpecials = 0
    var turnIntent: TurnIntent = .match
    var turnScoreAtStart = 0
    var turnPrimaryAnchor: Pos?
    var flowLevel = 0
    var bestFlowLevel = 0
    var lastChainTierFired = 0
    static let smashChargeMaximum = 100
    static func smashChargeGain(tilesCleared: Int,
                                blockersDamaged: Int,
                                specialsTriggered: Int,
                                multiplier: Double = 1.0,
                                objectiveHits: Int = 0) -> Int {
        let base = max(0, tilesCleared) * 2
            + max(0, blockersDamaged) * 5
            + max(0, specialsTriggered) * 12
        let credit = max(0, multiplier)
        guard credit > 0 else { return 0 }
        return max(0, Int((Double(base) * credit).rounded()))
            + min(12, max(0, objectiveHits) * 2)
    }
    var smashCharge = 0
    var smashTargeting = false
    var selectedSmashTier: PlayerSmashTier?
    var sugarRushCharged = false
    var comboContractProgress = 0
    var comboContractCompleted = false
    var bossShieldRemaining = 0
    var bossShieldMaximum = 0
    var bossTurnsUntilPressure = 0
    var turnConsumesMove = false
    var bossDamageAppliedThisTurn = false
    weak var comboMeterFill: SKShapeNode?
    weak var comboMeterTrack: SKShapeNode?
    weak var comboMeterLabel: SKLabelNode?
    weak var comboMeterCaption: SKLabelNode?
    weak var flowMeterLabel: SKLabelNode?

    // MARK: - Syrup line (rising pressure mechanic)
    /// Row index of the next tile-row that will get coated when the syrup tick
    /// fires. -1 means the level has no syrup mechanic.
    var syrupRow: Int = -1
    var syrupMovesSinceTick: Int = 0
    weak var syrupBand: SKNode?

    // MARK: - Pre-swap ghost preview
    var ghostNodes: [SKNode] = []
    var specialPreviewNodes: [SKNode] = []
    var ghostTarget: Pos?
    var smashPreviewNodes: [SKNode] = []
    var smashPreviewTarget: Pos?

    // Container for shake (we move this instead of self.position)
    var worldNode: SKNode!
    lazy var worldEffects = WorldEffectAnimator(scene: self)

    // HUD nodes
    var headerCard: SKShapeNode!
    var footerCard: SKShapeNode!
    var livesLabel: SKLabelNode!
    var levelLabel: SKLabelNode!
    var goalLabel: SKLabelNode!
    var starHintLabel: SKLabelNode!
    var totalLabel: SKLabelNode!
    var movesValueLabel: SKLabelNode!
    var progressFill: SKShapeNode!
    var progressTrack: SKShapeNode!
    var cashLabel: SKLabelNode!
    var objectiveTracker = ObjectiveTracker(objectives: [])
    var objectiveLabels: [SKLabelNode] = []
    var premiumStarNodes: [SKNode] = []
    var lastDisplayedStars = 0
    var boosterPriceLabels: [String: SKLabelNode] = [:]

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        safeTop = view.safeAreaInsets.top
        safeBottom = view.safeAreaInsets.bottom

        worldNode = SKNode()
        addChild(worldNode)
        GameArt.preload()

        // Load persisted progress BEFORE building the HUD so the level number,
        // skin, and counts all match what we left off on.
        levelConfig = Levels.config(for: initialDailyChallenge?.level
                                    ?? initialLevel
                                    ?? Persistence.currentLevel)
        rebuildChapterBackdrop()

        buildHeaderCard()
        buildFooterCard()
        buildUndoButton()
        buildComboMeter()

        // Now that the HUD nodes exist, hydrate the stored values via didSet —
        // each assignment will run updateHUD() and refresh its label.
        lives         = Persistence.lives
        totalScore    = Persistence.totalScore
        cash          = Persistence.cash
        shuffleCount  = Persistence.shuffleCount
        hammerCount   = Persistence.hammerCount
        swapCount     = Persistence.swapCount
        movesQuantity = Persistence.movesQuantity
        movesQuantityBadgeLabel?.text = "+\(movesQuantity)"

        updateHUD()
        layoutBoard()
        startNewGame()
        observeStoreKitDeliveries()
        startHUDRefreshTimer()

        // Kick off ambient music if it's enabled
        Audio.shared.syncWithPreferences()
    }

    func startHUDRefreshTimer() {
        removeAction(forKey: "hudRefreshTimer")
        run(.repeatForever(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.updateHUD() }
        ])), withKey: "hudRefreshTimer")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, !grid.isEmpty else { return }
        clearPlayerSmashPreview()
        worldEffects.reset(cancelResolution: false)
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        rebuildAllNodes()
        rebuildSyrupBand()
        worldEffects.present([.boardSettled])
    }

    func rebuildChapterBackdrop() {
        buildWorldBackdrop()
    }

    // MARK: - Combo / momentum meter

    /// Persistent Smash thresholds. The exact same value drives the visible
    /// meter and milestone feedback, avoiding the old mismatch where specials
    /// counted for tiers but not for the bar.
    struct ComboTier {
        let count: Int
        let label: String
        let color: UIColor
    }

    static let comboTiers: [ComboTier] = [
        ComboTier(count: 25,  label: "NICE!",        color: UIColor(hex: "#FACC15")),
        ComboTier(count: 50,  label: "COMBO!",       color: UIColor(hex: "#FB923C")),
        ComboTier(count: 75,  label: "ALMOST READY!", color: UIColor(hex: "#EC4899")),
        ComboTier(count: 100, label: "SMASH READY!",  color: UIColor(hex: "#A855F7"))
    ]

    var comboMeterContainer: SKNode? { comboMeterTrack?.parent }
    static let comboMeterTrackWidth: CGFloat = 200

    func buildComboMeter() {
        comboMeterContainer?.removeFromParent()
        let container = SKNode()
        container.name = "smashMeterButton"
        container.position = CGPoint(x: -20, y: gameplayLayout.utility.midY)
        container.setScale(min(0.85, gameplayLayout.scale))
        container.zPosition = 58
        container.alpha = 0
        addChild(container)

        let trackW: CGFloat = GameScene.comboMeterTrackWidth
        let trackH: CGFloat = 14
        let track = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: trackH / 2)
        track.name = "smashMeterButton"
        track.fillColor = UIColor(white: 0, alpha: 0.45)
        track.strokeColor = UIColor.white.withAlphaComponent(0.45)
        track.lineWidth = 1
        container.addChild(track)
        comboMeterTrack = track

        let innerW = trackW - 4
        let innerH = trackH - 4
        let fill = SKShapeNode(rectOf: CGSize(width: innerW, height: innerH), cornerRadius: innerH / 2)
        fill.name = "smashMeterButton"
        fill.fillColor = UIColor(hex: "#FACC15")
        fill.strokeColor = .clear
        fill.position = CGPoint(x: -innerW / 2, y: 0)
        fill.xScale = 0.0001
        container.addChild(fill)
        comboMeterFill = fill

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.name = "smashMeterButton"
        label.fontSize = 9.5
        label.fontColor = .white
        label.text = "0"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)
        comboMeterLabel = label

        let caption = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        caption.name = "smashMeterButton"
        caption.fontSize = 9
        caption.fontColor = .white
        caption.verticalAlignmentMode = .center
        caption.horizontalAlignmentMode = .center
        caption.position = CGPoint(x: 0, y: -13)
        container.addChild(caption)
        comboMeterCaption = caption

        let flow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        flow.fontSize = 9.5
        flow.fontColor = UIColor(hex: "#FDE68A")
        flow.verticalAlignmentMode = .center
        flow.horizontalAlignmentMode = .center
        flow.position = CGPoint(x: -150, y: 0)
        flow.alpha = 0
        container.addChild(flow)
        flowMeterLabel = flow
    }

    func updateComboMeter() {
        guard let fill = comboMeterFill,
              let label = comboMeterLabel,
              let container = comboMeterContainer else { return }
        let charge = max(0, min(GameScene.smashChargeMaximum, smashCharge))
        let frac = CGFloat(charge) / CGFloat(GameScene.smashChargeMaximum)
        let innerW = GameScene.comboMeterTrackWidth - 4
        fill.removeAllActions()
        fill.run(.scaleX(to: max(0.0001, frac), duration: 0.12))
        fill.position.x = -innerW / 2 + innerW * frac / 2

        // Pick the highest tier we've reached for color
        var tierColor = UIColor(hex: "#FACC15")
        for tier in GameScene.comboTiers where charge >= tier.count {
            tierColor = tier.color
        }
        fill.fillColor = tierColor
        if sugarRushCharged {
            comboMeterTrack?.strokeColor = UIColor(hex: "#EC4899")
            comboMeterTrack?.glowWidth = 5
            flowMeterLabel?.text = String(localized: "SUGAR RUSH READY")
                + (flowLevel > 0 ? " • " + String(localized: "FLOW \(flowLevel)/\(TurnMasteryPolicy.maximumFlow)") : "")
            flowMeterLabel?.fontColor = UIColor(hex: "#F9A8D4")
            flowMeterLabel?.alpha = 1
        } else if flowLevel > 0 {
            comboMeterTrack?.strokeColor = UIColor.white.withAlphaComponent(0.55)
            comboMeterTrack?.glowWidth = 0
            flowMeterLabel?.text = String(localized: "FLOW \(flowLevel)/\(TurnMasteryPolicy.maximumFlow)")
            flowMeterLabel?.fontColor = UIColor(hex: "#FDE68A")
            flowMeterLabel?.alpha = 1
        } else {
            comboMeterTrack?.strokeColor = UIColor.white.withAlphaComponent(0.45)
            comboMeterTrack?.glowWidth = 0
            flowMeterLabel?.text = nil
            flowMeterLabel?.alpha = 0
        }
        if smashTargeting, let tier = selectedSmashTier {
            label.text = tier.compactTitle
        } else if let tier = PlayerSmashTier.tier(for: charge) {
            label.text = tier.compactTitle
        } else {
            label.text = "\(charge)%"
        }
        if smashTargeting {
            comboMeterCaption?.text = smashPreviewTarget == nil
                ? String(localized: "TAP A TILE")
                : String(localized: "TAP AGAIN TO SMASH")
        } else if let tier = PlayerSmashTier.tier(for: charge) {
            switch tier {
            case .focused: comboMeterCaption?.text = String(localized: "TAP FOR BURST")
            case .cross: comboMeterCaption?.text = String(localized: "TAP FOR CROSS")
            case .mega: comboMeterCaption?.text = String(localized: "TAP FOR MEGA")
            }
        } else if levelConfig.isBoss {
            comboMeterCaption?.text = bossShieldRemaining > 0
                ? String(localized: "CROWN \(bossShieldRemaining)/\(bossShieldMaximum)")
                : String(localized: "CROWN BROKEN")
        } else if let contract = activeComboContract {
            comboMeterCaption?.text = comboContractCompleted
                ? String(localized: "BONUS COMPLETE")
                : String(localized: "BONUS \(min(comboContractProgress, contract.target))/\(contract.target)")
        } else {
            comboMeterCaption?.text = String(localized: "SMASH")
        }
        container.alpha = charge > 0 || smashTargeting || flowLevel > 0 || sugarRushCharged ? 1.0 : 0.42
        container.setScale(smashTargeting ? 1.08 : 1.0)
    }

    func resetComboMeter() {
        chainTilesCleared = 0
        chainSpecialsTriggered = 0
        chainBlockersDamaged = 0
        chainObjectiveHits = 0
        turnCreatedSpecials = 0
        lastChainTierFired = 0
        smashCharge = 0
        smashTargeting = false
        selectedSmashTier = nil
        clearPlayerSmashPreview()
        updateComboMeter()
    }

    /// Builds tension on a tight finish: when 3 or fewer moves remain, pulse the
    /// moves badge and fire an escalating haptic. Only triggers on the step that
    /// crosses the threshold downward so it doesn't spam during cascades.
    func maybeLowMovesTension(old: Int) {
        guard !levelEnded, movesLeft > 0, movesLeft <= 3, movesLeft < old else { return }
        let badge = movesValueLabel?.parent ?? movesValueLabel
        badge?.removeAction(forKey: "lowMovesPulse")
        badge?.run(.sequence([
            .scale(to: 1.18, duration: 0.10),
            .scale(to: 1.0, duration: 0.16)
        ]), withKey: "lowMovesPulse")
        Effects.haptic(movesLeft == 1 ? .heavy : .medium)
    }

    /// Records this resolution step in the chain stats and fires the next tier
    /// of visual + haptic feedback if a milestone was crossed.
    func recordChainProgress(tilesCleared: Int,
                                     blockersDamaged: Int,
                                     specialsTriggered: Int,
                                     chargeMultiplier: Double = 1.0,
                                     objectiveHits: Int = 0) {
        chainTilesCleared += tilesCleared
        chainBlockersDamaged += blockersDamaged
        chainSpecialsTriggered += specialsTriggered
        chainObjectiveHits += objectiveHits
        var missionEvents: [DailyMissions.Event] = [.tilesCleared(tilesCleared)]
        if specialsTriggered > 0 {
            missionEvents.append(.specialsTriggered(specialsTriggered))
        }
        DailyMissions.record(missionEvents)
        let gain = GameScene.smashChargeGain(tilesCleared: tilesCleared,
                                             blockersDamaged: blockersDamaged,
                                             specialsTriggered: specialsTriggered,
                                             multiplier: chargeMultiplier,
                                             objectiveHits: objectiveHits)
        addSmashCharge(gain, source: "chain")
        updateComboContract(tilesCleared: tilesCleared,
                            blockersDamaged: blockersDamaged,
                            specialsTriggered: specialsTriggered)
    }

    func fireComboTier(_ index: Int) {
        guard index < GameScene.comboTiers.count else { return }
        let tier = GameScene.comboTiers[index]
        flashScreenTint(tier.color.withAlphaComponent(0.32), duration: 0.32 + Double(index) * 0.05)
        switch index {
        case 0:
            Effects.haptic(.light)
        case 1:
            Effects.haptic(.medium)
            Audio.shared.play(.combo(depth: 3))
        case 2:
            Effects.haptic(.heavy)
            Audio.shared.play(.combo(depth: 5))
            applyTimeDilation(scale: 0.55, duration: 0.45)
        default:
            Effects.notify(.success)
            Audio.shared.play(.combo(depth: 8))
            applyTimeDilation(scale: 0.45, duration: 0.6)
        }
        // Pulse the meter for emphasis
        comboMeterContainer?.run(.sequence([
            .scale(to: 1.15, duration: 0.10),
            .scale(to: 1.0, duration: 0.14)
        ]))
        // Light banner just above the meter so the streak gets its own moment.
        let popup = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        popup.text = tier.label
        popup.fontSize = 16
        popup.fontColor = tier.color
        popup.position = CGPoint(x: 0, y: 22)
        popup.alpha = 0
        popup.zPosition = 5
        comboMeterContainer?.addChild(popup)
        popup.run(.sequence([
            .fadeIn(withDuration: 0.10),
            .moveBy(x: 0, y: 12, duration: 0.5),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }

    func flashScreenTint(_ color: UIColor, duration: TimeInterval) {
        let tint = SKShapeNode(rectOf: size)
        tint.fillColor = color
        tint.strokeColor = .clear
        tint.zPosition = 1100
        tint.alpha = 0
        addChild(tint)
        tint.run(.sequence([
            .fadeAlpha(to: 0.6, duration: duration * 0.25),
            .fadeOut(withDuration: duration * 0.75),
            .removeFromParent()
        ]))
    }

    func applyTimeDilation(scale: CGFloat, duration: TimeInterval) {
        worldNode.speed = scale
        run(.sequence([
            .wait(forDuration: duration),
            .run { [weak self] in self?.worldNode.speed = 1.0 }
        ]), withKey: "boardTimeDilation")
    }

    // MARK: - Syrup line (rising pressure mechanic)

    func resetSyrupForLevel() {
        syrupBand?.removeFromParent()
        syrupBand = nil
        guard levelConfig.layout.syrupTickEvery != nil else {
            syrupRow = -1
            syrupMovesSinceTick = 0
            return
        }
        // Start one row below the bottom playable row so the first tick coats
        // the actual lowest row.
        syrupRow = rows
        syrupMovesSinceTick = 0
        rebuildSyrupBand()
    }

    func rebuildSyrupBand() {
        syrupBand?.removeFromParent()
        syrupBand = nil
        guard levelConfig.layout.syrupTickEvery != nil,
              syrupRow >= 0,
              syrupRow < rows else { return }
        let band = SKNode()
        band.zPosition = -3
        band.name = "syrupBand"

        // Find the y-position of the next-to-be-coated row. If the syrup is
        // already at the top of the board, anchor the band to the top edge.
        let row = max(0, min(rows - 1, syrupRow))
        let centerY = point(forRow: row, col: 0).y
        let totalW = tileSize * CGFloat(cols) + gap * CGFloat(cols + 1)

        let band1 = SKShapeNode(rectOf: CGSize(width: totalW + 24, height: tileSize * 0.6),
                                cornerRadius: tileSize * 0.3)
        band1.fillColor = UIColor(hex: "#EC4899").withAlphaComponent(0.20)
        band1.strokeColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.70)
        band1.lineWidth = 2
        band1.glowWidth = 4
        band1.blendMode = .add
        band1.position = CGPoint(x: 0, y: centerY)
        band.addChild(band1)

        band1.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 1.1),
            .fadeAlpha(to: 0.85, duration: 1.1)
        ])))

        worldNode.addChild(band)
        syrupBand = band
    }

    /// Called once per resolved player turn. When the tick counter hits the
    /// configured interval, every playable cell on the current syrup row gets
    /// coated with a single-hit syrup blocker, the line climbs one row, and
    /// the visual band slides up.
    func tickSyrupIfNeeded() {
        guard let interval = levelConfig.layout.syrupTickEvery,
              syrupRow >= 0,
              syrupRow < rows + 1 else { return }
        syrupMovesSinceTick += 1
        guard syrupMovesSinceTick >= interval else { return }
        syrupMovesSinceTick = 0

        // First tick of the level coats the bottom row (since syrupRow starts
        // at `rows`). Each subsequent tick climbs one more row.
        let nextRow = syrupRow - 1
        guard nextRow >= 0 else {
            // Syrup capped at the top — no more rows to coat.
            return
        }
        syrupRow = nextRow

        var coated: [Pos] = []
        for c in 0..<cols {
            if let m = levelConfig.layout.mask, !m[syrupRow][c] { continue }
            guard var cell = grid[syrupRow][c] else { continue }
            // Skip cells that already have a blocker (don't double-coat); skip
            // ingredient baskets so they stay drop-able.
            guard cell.blocker == nil, cell.kind == .normal else { continue }
            cell.blocker = Blocker(type: .syrup, hits: 1)
            cell.special = nil
            grid[syrupRow][c] = cell
            coated.append(Pos(r: syrupRow, c: c))
        }
        for p in coated { refreshNode(at: p) }
        rebuildSyrupBand()
        if !coated.isEmpty {
            Audio.shared.play(.jelly)
            Effects.haptic(.medium)
            Effects.showComboBanner(text: String(localized: "SYRUP RISING!"),
                                    color: UIColor(hex: "#EC4899"),
                                    in: self)
        }
        Analytics.track("syrup_tick",
                        properties: ["level": "\(levelNumber)",
                                     "row": "\(syrupRow)",
                                     "coated": "\(coated.count)"])
    }

    // MARK: - Undo last move

    func takeUndoSnapshot() {
        undoSnapshot = UndoSnapshot(objectiveTracker: objectiveTracker,
                                     grid: grid,
                                     nodes: nodes,
                                     score: score,
                                     movesLeft: movesLeft,
                                     collectedGoalTiles: collectedGoalTiles,
                                     createdSpecials: createdSpecials,
                                     detonatedBombs: detonatedBombs,
                                     collectedIngredients: collectedIngredients,
                                     collectedKeys: collectedKeys,
                                     openedChests: openedChests,
                                     cash: cash,
                                     shuffleCount: shuffleCount,
                                     hammerCount: hammerCount,
                                     swapCount: swapCount,
                                     piggyCoins: Persistence.piggyCoins,
                                     maxCascadeDepth: maxCascadeDepth,
                                     totalCascadeClears: totalCascadeClears,
                                     objectiveCompletionShown: objectiveCompletionShown,
                                     boosterUsedThisAttempt: boosterUsedThisAttempt,
                                     chainTilesCleared: chainTilesCleared,
                                     chainSpecialsTriggered: chainSpecialsTriggered,
                                     chainBlockersDamaged: chainBlockersDamaged,
                                     chainObjectiveHits: chainObjectiveHits,
                                     lastChainTierFired: lastChainTierFired,
                                     smashCharge: smashCharge,
                                     smashTargeting: smashTargeting,
                                     selectedSmashTier: selectedSmashTier,
                                     comboContractProgress: comboContractProgress,
                                     comboContractCompleted: comboContractCompleted,
                                     bossShieldRemaining: bossShieldRemaining,
                                     bossTurnsUntilPressure: bossTurnsUntilPressure,
                                     chocolateDamagedThisTurn: chocolateDamagedThisTurn,
                                     syrupRow: syrupRow,
                                     syrupMovesSinceTick: syrupMovesSinceTick,
                                     sugarRushCharged: sugarRushCharged,
                                     mercySpecialGrantedThisAttempt: mercySpecialGrantedThisAttempt,
                                     flowLevel: flowLevel,
                                     bestFlowLevel: bestFlowLevel)
        refreshUndoButton()
    }

    func invalidateUndoSnapshot() {
        guard undoSnapshot != nil else { return }
        undoSnapshot = nil
        refreshUndoButton()
    }

    /// Restore the most recent pre-swap snapshot. The first undo per level is
    /// free; subsequent undos cost `Economy.undoCost`. No-op when no snapshot
    /// is available, when the player can't afford the coin cost, or while a
    /// cascade is still resolving.
    func performUndo() {
        guard let snapshot = undoSnapshot, !levelEnded else { return }
        if isResolving { return }
        let usesFreeUndo = !freeUndoUsedThisLevel
        let undoCost = usesFreeUndo ? 0 : Economy.undoCost
        if !usesFreeUndo {
            guard snapshot.cash >= undoCost else {
                insufficientCashFeedback()
                return
            }
            Analytics.track("coin_spend",
                            properties: ["item": "undo",
                                         "coins": "\(undoCost)",
                                         "level": "\(levelNumber)"])
        } else {
            freeUndoUsedThisLevel = true
        }
        Analytics.track("undo_used",
                        properties: ["level": "\(levelNumber)",
                                     "free": "\(usesFreeUndo)"])

        // Remove every visual tile node currently on the board — the snapshot
        // nodes are stale references, so we rebuild from grid state.
        for r in 0..<nodes.count {
            for c in 0..<nodes[r].count {
                nodes[r][c]?.removeFromParent()
                nodes[r][c] = nil
            }
        }
        worldEffects.reset()
        grid = snapshot.grid
        score = snapshot.score
        movesLeft = snapshot.movesLeft
        collectedGoalTiles = snapshot.collectedGoalTiles
        createdSpecials = snapshot.createdSpecials
        detonatedBombs = snapshot.detonatedBombs
        collectedIngredients = snapshot.collectedIngredients
        collectedKeys = snapshot.collectedKeys
        openedChests = snapshot.openedChests
        cash = max(0, snapshot.cash - undoCost)
        shuffleCount = snapshot.shuffleCount
        hammerCount = snapshot.hammerCount
        swapCount = snapshot.swapCount
        Persistence.piggyCoins = snapshot.piggyCoins
        maxCascadeDepth = snapshot.maxCascadeDepth
        totalCascadeClears = snapshot.totalCascadeClears
        objectiveCompletionShown = snapshot.objectiveCompletionShown
        boosterUsedThisAttempt = snapshot.boosterUsedThisAttempt
        chainTilesCleared = snapshot.chainTilesCleared
        chainSpecialsTriggered = snapshot.chainSpecialsTriggered
        chainBlockersDamaged = snapshot.chainBlockersDamaged
        chainObjectiveHits = snapshot.chainObjectiveHits
        lastChainTierFired = snapshot.lastChainTierFired
        smashCharge = snapshot.smashCharge
        smashTargeting = snapshot.smashTargeting
        selectedSmashTier = snapshot.selectedSmashTier
        comboContractProgress = snapshot.comboContractProgress
        comboContractCompleted = snapshot.comboContractCompleted
        bossShieldRemaining = snapshot.bossShieldRemaining
        bossTurnsUntilPressure = snapshot.bossTurnsUntilPressure
        chocolateDamagedThisTurn = snapshot.chocolateDamagedThisTurn
        syrupRow = snapshot.syrupRow
        syrupMovesSinceTick = snapshot.syrupMovesSinceTick
        sugarRushCharged = snapshot.sugarRushCharged
        mercySpecialGrantedThisAttempt = snapshot.mercySpecialGrantedThisAttempt
        flowLevel = snapshot.flowLevel
        bestFlowLevel = snapshot.bestFlowLevel
        objectiveTracker = snapshot.objectiveTracker
        turnCreatedSpecials = 0
        turnPrimaryAnchor = nil
        turnScoreAtStart = score
        rebuildAllNodes()
        rebuildSyrupBand()
        updateComboMeter()
        undoSnapshot = nil
        refreshUndoButton()
        Effects.haptic(.medium)
        Effects.notify(.warning)
    }

    func buildUndoButton() {
        undoButton?.removeFromParent()
        let btn = SKNode()
        btn.position = CGPoint(x: gameplayLayout.utility.maxX - 25, y: gameplayLayout.utility.midY)
        btn.setScale(0.65)
        btn.zPosition = 59
        btn.name = "undoButton"

        let shadow = SKShapeNode(circleOfRadius: 22)
        shadow.fillColor = UIColor(white: 0, alpha: 0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = -1
        btn.addChild(shadow)

        let bg = SKShapeNode(circleOfRadius: 22)
        bg.fillColor = UIColor(white: 1, alpha: 0.95)
        bg.strokeColor = UIColor(hex: "#0F172A").withAlphaComponent(0.18)
        bg.lineWidth = 1
        bg.name = "undoButton"
        btn.addChild(bg)

        let arrow = Icons.sprite("arrow.uturn.backward",
                                 size: 19,
                                 weight: .heavy,
                                 tint: UIColor(hex: "#475569"))
        arrow.name = "undoButton"
        btn.addChild(arrow)

        let badgeBg = SKShapeNode(rectOf: CGSize(width: 30, height: 14), cornerRadius: 7)
        badgeBg.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.85)
        badgeBg.strokeColor = .white.withAlphaComponent(0.7)
        badgeBg.lineWidth = 0.8
        badgeBg.position = CGPoint(x: 8, y: -18)
        badgeBg.zPosition = 1
        btn.addChild(badgeBg)

        let badge = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        badge.fontSize = 9
        badge.verticalAlignmentMode = .center
        badge.horizontalAlignmentMode = .center
        badge.zPosition = 2
        badgeBg.addChild(badge)
        undoBadge = badge

        addChild(btn)
        undoButton = btn
        refreshUndoButton()
    }

    func refreshUndoButton() {
        guard let btn = undoButton else { return }
        let available = undoSnapshot != nil && !levelEnded
        btn.alpha = available ? 1.0 : 0.32
        if !available {
            undoBadge?.text = nil
            undoBadge?.parent?.alpha = 0
            return
        }
        undoBadge?.parent?.alpha = 1
        if freeUndoUsedThisLevel {
            undoBadge?.text = "\(Economy.undoCost)"
            undoBadge?.fontColor = UIColor(hex: "#FBBF24")
        } else {
            undoBadge?.text = String(localized: "FREE")
            undoBadge?.fontColor = UIColor(hex: "#34D399")
        }
    }

    /// Three orthogonal mastery medals computed at the end of a winning attempt.
    /// They reward distinct ways to play well — clean (no boosters), efficient
    /// (lots of moves spare), and dominant (overshoot the objective).
    func computeMedals(effectiveMovesLeft: Int) -> Persistence.MedalSet {
        let noBoosters = !boosterUsedThisAttempt
        let movesToSpare = movesAtStart > 0 &&
            Double(effectiveMovesLeft) >= Double(movesAtStart) * 0.30
        let overshotGoal: Bool
        switch levelConfig.goal {
        case .score:
            overshotGoal = score >= scoreTarget * 2
        case .clearBlockers:
            // No more blockers AND at least 40% of moves still in hand.
            overshotGoal = remainingBlockerCount() == 0 &&
                Double(effectiveMovesLeft) >= Double(movesAtStart) * 0.40
        case .collectColor(_, let count):
            overshotGoal = collectedGoalTiles >= count * 2
        case .createSpecials(let count):
            overshotGoal = createdSpecials >= count * 2
        case .detonateBombs(let count):
            overshotGoal = detonatedBombs >= count * 2
        case .collectIngredients(let count):
            overshotGoal = collectedIngredients >= count * 2
        case .collectKeys(let count):
            overshotGoal = collectedKeys >= count * 2
        case .openChests(let count):
            overshotGoal = openedChests >= count * 2
        case .collectIngredientsAndKeys(let ingredients, let keys):
            overshotGoal = collectedIngredients >= ingredients * 2 && collectedKeys >= keys * 2
        }
        return Persistence.MedalSet(noBoosters: noBoosters,
                                    movesToSpare: movesToSpare,
                                    overshotGoal: overshotGoal)
    }

    // MARK: - Board layout

    func layoutBoard() {
        let layout = gameplayLayout
        gap = layout.gap
        tileSize = layout.tileSize
        boardOrigin = CGPoint(x: layout.board.minX + tileSize / 2,
                              y: layout.board.maxY - tileSize / 2)

        worldNode.childNode(withName: "boardBackdrop")?.removeFromParent()
        worldNode.childNode(withName: "shapeMat")?.removeFromParent()
        worldNode.childNode(withName: "tileCornerFillers")?.removeFromParent()
        worldNode.childNode(withName: "mechanicsLayer")?.removeFromParent()
        buildShapeMat()
        buildMechanicsLayer()
    }

    func buildMechanicsLayer() {
        guard !levelConfig.layout.portalPairs.isEmpty || !levelConfig.layout.conveyorBelts.isEmpty else { return }
        let layer = SKNode()
        layer.name = "mechanicsLayer"
        layer.zPosition = -5

        for belt in levelConfig.layout.conveyorBelts {
            guard belt.row >= 0, belt.row < rows else { continue }
            for c in 0..<cols where levelConfig.layout.mask?[belt.row][c] ?? true {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize * 0.82, height: tileSize * 0.28),
                                       cornerRadius: tileSize * 0.12)
                tile.fillColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.20)
                tile.strokeColor = UIColor(hex: "#67E8F9").withAlphaComponent(0.42)
                tile.lineWidth = 1
                tile.position = point(forRow: belt.row, col: c)
                layer.addChild(tile)

                let arrow = Icons.sprite(belt.direction >= 0 ? "arrow.right" : "arrow.left",
                                         size: tileSize * 0.22,
                                         weight: .bold,
                                         tint: UIColor(hex: "#E0F2FE"))
                arrow.position = tile.position
                layer.addChild(arrow)
            }
        }

        for pair in levelConfig.layout.portalPairs {
            for (pos, tint) in [(pair.from, UIColor(hex: "#A78BFA")), (pair.to, UIColor(hex: "#22D3EE"))] {
                guard pos.r >= 0, pos.r < rows, pos.c >= 0, pos.c < cols else { continue }
                let ring = SKShapeNode(circleOfRadius: tileSize * 0.42)
                ring.fillColor = tint.withAlphaComponent(0.12)
                ring.strokeColor = tint.withAlphaComponent(0.85)
                ring.lineWidth = 2
                ring.glowWidth = 4
                ring.position = point(forRow: pos.r, col: pos.c)
                layer.addChild(ring)
                if !SignatureMotion.isReduced {
                    ring.run(.repeatForever(.sequence([
                        .scale(to: 1.10, duration: 0.8),
                        .scale(to: 1.0, duration: 0.8)
                    ])))
                }
            }
        }

        worldNode.addChild(layer)
    }

    var boardContourPath: CGPath {
        let mask = Persistence.shapedBoard ? levelConfig.layout.mask : nil
        return BoardContour.path(mask: mask ?? Array(repeating: Array(repeating: true, count: cols), count: rows),
                                 frame: gameplayLayout.board, tileSize: tileSize, gap: gap)
    }

    /// One continuous rim follows the real level mask, including interior holes.
    /// This avoids both the old rectangular backing and per-cell seam outlines.
    func buildShapeMat() {
        let mat = SKNode()
        mat.name = "boardBackdrop"
        mat.alpha = CGFloat(1 - Persistence.boardTransparency)
        mat.zPosition = -12
        mat.position = CGPoint(x: gameplayLayout.board.midX, y: gameplayLayout.board.midY)
        var transform = CGAffineTransform(translationX: -mat.position.x, y: -mat.position.y)
        let path = boardContourPath.copy(using: &transform)!
        let rim = worldTheme.boardRimColor
        let fill = SKShapeNode(path: path)
        fill.fillColor = UIColor(hex: "#122C4D")
        fill.strokeColor = .clear
        fill.zPosition = -1
        mat.addChild(fill)
        for (width, color, glow) in [(CGFloat(8), rim.withAlphaComponent(0.38), CGFloat(3)),
                                      (CGFloat(5), rim, CGFloat(0)),
                                      (CGFloat(2.5), UIColor(hex: worldTheme.id == "ice" ? "#ECFEFF" : "#FFF1CE"), CGFloat(0)),
                                      (CGFloat(0.7), rim.darker(by: 0.15), CGFloat(0))] {
            let edge = SKShapeNode(path: path)
            edge.fillColor = .clear
            edge.strokeColor = color
            edge.lineWidth = width
            edge.glowWidth = glow
            edge.lineJoin = .round
            mat.addChild(edge)
        }
        worldNode.addChild(mat)
    }

    /// Fill only the tiny internal junctions where four rounded playable tiles meet.
    /// This keeps shaped-board silhouettes intact while removing accidental-looking holes.
    func buildInteriorCornerFillers() {
        guard rows > 1, cols > 1 else { return }
        let layer = SKNode()
        layer.name = "tileCornerFillers"
        layer.alpha = CGFloat(1 - Persistence.boardTransparency)
        layer.zPosition = -1
        let mask = levelConfig.layout.mask
        let fill = Persistence.highContrast ? UIColor.white : skin.tileBorder
        let fillerSide = max(6, tileSize * 0.26)

        func isPlayable(_ r: Int, _ c: Int) -> Bool {
            mask?[r][c] ?? true
        }

        for r in 0..<(rows - 1) {
            for c in 0..<(cols - 1) {
                guard isPlayable(r, c),
                      isPlayable(r, c + 1),
                      isPlayable(r + 1, c),
                      isPlayable(r + 1, c + 1) else { continue }

                let topLeft = point(forRow: r, col: c)
                let bottomRight = point(forRow: r + 1, col: c + 1)
                let filler = SKShapeNode(rectOf: CGSize(width: fillerSide, height: fillerSide),
                                         cornerRadius: fillerSide * 0.18)
                filler.fillColor = fill
                filler.strokeColor = .clear
                filler.position = CGPoint(x: (topLeft.x + bottomRight.x) / 2,
                                          y: (topLeft.y + bottomRight.y) / 2)
                layer.addChild(filler)
            }
        }

        if !layer.children.isEmpty {
            worldNode.addChild(layer)
        }
    }

    func point(forRow r: Int, col c: Int) -> CGPoint {
        CGPoint(x: boardOrigin.x + CGFloat(c) * (tileSize + gap),
                y: boardOrigin.y - CGFloat(r) * (tileSize + gap))
    }

    func cellAt(_ point: CGPoint) -> Pos? {
        for r in 0..<rows {
            for c in 0..<cols {
                guard levelConfig.layout.mask?[r][c] ?? true else { continue }
                let p = self.point(forRow: r, col: c)
                let rect = CGRect(
                    x: p.x - tileSize / 2,
                    y: p.y - tileSize / 2,
                    width: tileSize,
                    height: tileSize
                )
                if rect.contains(point) { return Pos(r: r, c: c) }
            }
        }
        return nil
    }

    // MARK: - Game lifecycle

    func startNewGame() {
        worldEffects.reset()
        worldNode?.speed = 1
        removeAction(forKey: "boardTimeDilation")
        worldNode?.childNode(withName: "worldComboPresentation")?.removeFromParent()
        if let worldNode { Effects.cancelShake(worldNode) }
        gamePhase = .loading
        objectiveTracker = ObjectiveTracker(objectives: levelConfig.objectives)
        lastDisplayedStars = 0
        conveyorAdvancedThisTurn = false
        score = 0
        movesLeft = movesAtStart
        startingBlockers = 0
        collectedGoalTiles = 0
        createdSpecials = 0
        detonatedBombs = 0
        collectedIngredients = 0
        collectedKeys = 0
        openedChests = 0
        maxCascadeDepth = 0
        totalCascadeClears = 0
        objectiveCompletionShown = false
        mercySpecialGrantedThisAttempt = false
        hintShownThisLevel = 0
        freeStuckReshufflesThisLevel = 0
        pendingLifeLoss = false
        continueUsedThisAttempt = false
        coinPromptShownThisAttempt = false
        boosterUsedThisAttempt = false
        undoSnapshot = nil
        freeUndoUsedThisLevel = false
        chainTilesCleared = 0
        chainSpecialsTriggered = 0
        chainBlockersDamaged = 0
        chainObjectiveHits = 0
        turnCreatedSpecials = 0
        turnIntent = .match
        turnScoreAtStart = 0
        turnPrimaryAnchor = nil
        flowLevel = 0
        bestFlowLevel = 0
        lastChainTierFired = 0
        smashCharge = 0
        smashTargeting = false
        selectedSmashTier = nil
        sugarRushCharged = false
        comboContractProgress = 0
        comboContractCompleted = false
        configureBossForNewAttempt()
        turnConsumesMove = false
        bossDamageAppliedThisTurn = false
        preferredSpecialSpawnPositions.removeAll()
        preLevelPerkApplied = false
        preLevelPerkOverlay?.removeFromParent()
        preLevelPerkOverlay = nil
        clearGhostPreview()
        clearPlayerSmashPreview()
        resetSyrupForLevel()
        resetComboMeter()
        refreshUndoButton()
        let usefulMoveScore = openingMoveQualityTarget()
        dailyChallengeRun = initialDailyChallenge
        isDailyChallengeRun = dailyChallengeRun != nil
        // `resume` ends any run whose floor was walked out on, so a fresh climb
        // starts here rather than the abandoned floor being replayed for free.
        towerRun = levelNumber == Levels.towerLevel
            ? (TowerMode.resume().run ?? TowerMode.startNewRun())
            : nil
        var requestedSeed = dailyChallengeRun?.seed
            ?? LevelSeed.liveAttempt(level: levelNumber)
        if let run = towerRun {
            // Weekly shared boards — every player climbs the same tower.
            requestedSeed = TowerMode.floorSeed(weekKey: run.weekKey, floor: run.floor)
        }
        #if DEBUG
        if let replay = debugReplaySeed {
            requestedSeed = replay
            debugReplaySeed = nil
        }
        #endif
        let board = LevelBoardFactory.makeInitialBoard(config: levelConfig,
                                                       seed: requestedSeed,
                                                       minimumOpeningMoveScore: usefulMoveScore,
                                                       attempts: 24)
        levelAttemptSeed = board.seed
        gameplayRNG = SeededRandomNumberGenerator(seed: levelAttemptSeed ^ 0x7265706C6179)
        grid = board.grid
        dailyStartGrid = isDailyChallengeRun ? board.grid : []
        startingBlockers = remainingBlockerCount()
        rebuildAllNodes()
        Analytics.track("level_start",
                        properties: ["level": "\(levelNumber)",
                                     "moves": "\(movesAtStart)",
                                     "target": "\(scoreTarget)",
                                     "goal": "\(levelConfig.goal.title)",
                                     "difficulty": levelConfig.difficulty.rawValue,
                                     "modifiers": levelConfig.modifiers.map(\.rawValue).joined(separator: ","),
                                     "combo_contract": activeComboContract?.kind.rawValue ?? "none",
                                     "combo_contract_target": "\(activeComboContract?.target ?? 0)",
                                     "boss_shield": "\(bossShieldMaximum)",
                                     "seed": "\(levelAttemptSeed)",
                                     "opening_move_score": "\(board.openingMoveScore)"])
        showLevelIntroHints()
        showComboContractIntroIfNeeded()
        if isDailyChallengeRun {
            showTeachingToast(key: "daily_shared_board",
                              text: String(localized: "Daily Challenge — every player gets this exact board!"))
        } else if let run = towerRun {
            // Tower boards are also shared (weekly), so no per-player board
            // mutations. Drafted perks apply instead.
            Effects.showComboBanner(text: String(localized: "FLOOR \(run.floor)"),
                                    color: UIColor(hex: "#A855F7"),
                                    in: self)
            let headStacks = min(TowerPerk.maxStacks,
                                 run.perks.filter { $0 == .headStart }.count)
            if headStacks > 0 {
                addSmashCharge(min(100, 40 * headStacks), source: "tower_perk")
            }
        } else {
            // The daily board must stay byte-identical for everyone, so the
            // per-player perk and assist mutations only run on campaign attempts.
            showPreLevelPerkChoiceIfNeeded()
            applyFailStreakAssistIfNeeded()
        }
        scheduleIdleHint()
        gamePhase = .waitingForInput
        worldEffects.present([.boardSettled])
    }

    func openingMoveQualityTarget() -> Int {
        switch levelNumber {
        case 1...10:
            return 30
        case 11...25:
            return 35
        case 26...100:
            return levelConfig.difficulty == .normal ? 38 : 28
        default:
            return levelConfig.difficulty == .crownChallenge ? 22 : 30
        }
    }

    func showLevelIntroHints() {
        switch levelNumber {
        case 1:
            showTeachingToast(key: "match3", text: String(localized: "Swap candies to match 3."))
            showGuidedMoveHint(delay: 1.0, reason: "first_match")
        case 2:
            // Keep hand-guiding through the first session, not just level 1.
            showGuidedMoveHint(delay: 1.2, reason: "second_match")
        case 3:
            showTeachingToast(key: "combo_tip", text: String(localized: "Line up 4 or more for power-ups!"))
            showGuidedMoveHint(delay: 1.2, reason: "third_match")
        case 4:
            showTeachingToast(key: "striped_intro", text: String(localized: "Match 4 to create stripes."))
            showGuidedMoveHint(delay: 1.1, reason: "striped_intro")
        case 5:
            showTeachingToast(key: "blockers", text: String(localized: "Match beside frost and locks to break them."))
            showGuidedMoveHint(delay: 1.1, reason: "blockers")
        case 7:
            showTeachingToast(key: "color_bomb_intro", text: String(localized: "Match 5 straight for a color bomb."))
            showGuidedMoveHint(delay: 1.1, reason: "color_bomb_intro")
        case 11:
            showTeachingToast(key: "wrapped_intro", text: String(localized: "T and L matches create wrapped blasts."))
            showGuidedMoveHint(delay: 1.1, reason: "wrapped_intro")
        case 12:
            showTeachingToast(key: "booster_intro", text: String(localized: "Use boosters when one move can save the board."))
        case 13:
            showTeachingToast(key: "fish_intro", text: String(localized: "Make a 2x2 square to create a goal-seeking fish."))
        case 16:
            showTeachingToast(key: "smash_intro", text: String(localized: "Build Smash to 50 for a burst, 75 for a cross, or 100 for a mega smash."))
        case 21:
            showTeachingToast(key: "jelly_intro_level", text: String(localized: "Jelly clears only when you match on top."))
            showGuidedMoveHint(delay: 1.1, reason: "jelly_intro")
        default:
            if levelConfig.layout.jellyCount > 0 {
                showTeachingToast(key: "jelly_intro", text: String(localized: "Jelly needs a direct match on top."))
            } else if levelConfig.layout.crateCount > 0 {
                showTeachingToast(key: "crate_intro", text: String(localized: "Sugar crates take three direct hits."))
            } else if levelConfig.layout.colorLockCount > 0 {
                showTeachingToast(key: "color_lock_intro", text: String(localized: "Color locks open with their fruit."))
            } else if levelConfig.layout.chestCount > 0 || levelConfig.layout.keyCount > 0 {
                showTeachingToast(key: "chest_key_intro", text: String(localized: "Open chests with nearby matches or collected keys."))
            } else if levelConfig.layout.vineCount > 0 {
                showTeachingToast(key: "vine_intro", text: String(localized: "Cut vines with direct matches or hammers."))
            } else if !levelConfig.layout.portalPairs.isEmpty {
                showTeachingToast(key: "portal_intro", text: String(localized: "Portals swap candies after gravity."))
            } else if !levelConfig.layout.conveyorBelts.isEmpty {
                showTeachingToast(key: "conveyor_intro", text: String(localized: "Conveyors shift candies after gravity."))
            }
            if let modifier = levelConfig.modifiers.first {
                showTeachingToast(key: "modifier_\(modifier.rawValue)", text: modifier.summary)
            }
            if levelConfig.layout.countdownCount > 0 {
                showTeachingToast(key: "countdown_intro", text: String(localized: "Clear fuses before they hit zero — each blast costs a move!"))
            }
            if levelConfig.layout.blockerCount > 10 {
                showTeachingToast(key: "hard_blockers", text: String(localized: "Special combos are strongest against blockers."))
            }
        }
    }

    func showGuidedMoveHint(delay: TimeInterval, reason: String) {
        guard Engine.findHintMove(grid) != nil else { return }
        guard !Persistence.hasSeenHint("guided_\(reason)") else { return }
        Persistence.markHintSeen("guided_\(reason)")
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.showIdleHint(force: true) }
        ]))
    }

    func showSpecialHint(_ special: Special) {
        switch special {
        case .lineBlast, .rocket, .ufo:
            showTeachingToast(key: "advancedSpecial.\(special.rawValue)", text: String(localized: "Combine power-ups for a bigger blast!"))
        case .stripedRow, .stripedCol:
            showTeachingToast(key: "striped_created", text: String(localized: "Swap stripes into a match to clear a line."))
        case .wrapped:
            showTeachingToast(key: "wrapped_created", text: String(localized: "Wrapped candy clears a 5x5 blast."))
        case .colorBomb:
            showTeachingToast(key: "color_bomb_created", text: String(localized: "Swap a color bomb with any candy."))
        case .bomb:
            showTeachingToast(key: "bomb_created", text: String(localized: "Bombs clear a wide area. Save them for blockers."))
        case .fish:
            showTeachingToast(key: "fish_created", text: String(localized: "Fish swim to a blocker or goal tile and clear it."))
        }
    }

    func showTeachingToast(key: String, text: String, delay: TimeInterval = 0.45) {
        guard !Persistence.hasSeenHint(key) else { return }
        Persistence.markHintSeen(key)
        run(.wait(forDuration: delay)) { [weak self] in
            guard let self else { return }
            self.showStatusToast(text)
        }
    }

    func showStatusToast(_ text: String) {
        childNode(withName: "teachingToast")?.removeFromParent()

        let width = min(size.width - 34, max(258, CGFloat(text.count) * 6.8 + 34))
        let toast = SKNode()
        toast.name = "teachingToast"
        toast.zPosition = 1400
        toast.position = CGPoint(x: 0, y: size.height / 2 - safeTop - 124)
        toast.alpha = 0

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 40), cornerRadius: 20)
        bg.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.88)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.16)
        bg.lineWidth = 1
        toast.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        toast.addChild(label)

        addChild(toast)
        toast.run(.sequence([
            .group([.fadeIn(withDuration: 0.18), .moveBy(x: 0, y: -4, duration: 0.18)]),
            .wait(forDuration: 2.4),
            .group([.fadeOut(withDuration: 0.2), .moveBy(x: 0, y: 8, duration: 0.2)]),
            .removeFromParent()
        ]))
    }

    func showPreLevelPerkChoiceIfNeeded() {
        guard preLevelPerkOverlay == nil, !preLevelPerkApplied else { return }
        guard !levelConfig.modifiers.contains(.noBoosters) else { return }
        guard levelConfig.isBoss || levelConfig.difficulty == .hard || levelConfig.difficulty == .superHard || levelConfig.difficulty == .crownChallenge else { return }
        guard size.width > 120, size.height > 260 else {
            run(.sequence([
                .wait(forDuration: 0.05),
                .run { [weak self] in self?.showPreLevelPerkChoiceIfNeeded() }
            ]), withKey: "deferPreLevelPerk")
            return
        }

        let overlayZ: CGFloat = 4_000
        let overlay = SKNode()
        overlay.name = "preLevelPerkOverlay"
        overlay.zPosition = overlayZ

        let scrim = SKShapeNode(rectOf: size)
        scrim.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.58)
        scrim.strokeColor = .clear
        scrim.name = "preLevelPerkScrim"
        scrim.zPosition = overlayZ
        overlay.addChild(scrim)

        let cardW = min(size.width - 52, 318)
        let cardH: CGFloat = 300
        let cardY = max(-24, min(34, -safeTop * 0.25))

        let shadow = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 24)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: cardY - 8)
        shadow.zPosition = overlayZ + 1
        overlay.addChild(shadow)

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 24)
        card.fillColor = .white
        card.strokeColor = UIColor(hex: "#D9E3EF")
        card.lineWidth = 1.5
        card.name = "preLevelPerkCard"
        card.position = CGPoint(x: 0, y: cardY)
        card.zPosition = overlayZ + 2
        overlay.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = String(localized: "Pick a start perk")
        title.fontSize = 22
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: cardH / 2 - 42)
        title.zPosition = overlayZ + 3
        card.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = levelConfig.isBoss ? String(localized: "Boss board bonus") : String(localized: "Hard level bonus")
        subtitle.fontSize = 13
        subtitle.fontColor = UIColor(hex: "#64748B")
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: 0, y: cardH / 2 - 68)
        subtitle.zPosition = overlayZ + 3
        card.addChild(subtitle)

        let options: [(PreLevelPerk, String, String, UIColor)] = [
            (.bomb, "Start bomb", "One bomb on the board", UIColor(hex: "#F97316")),
            (.moves, "+3 moves", "Extra room to finish", UIColor(hex: "#EC4899")),
            (.blockers, "Clear 3", "Remove blockers now", UIColor(hex: "#22C55E"))
        ]

        for (index, option) in options.enumerated() {
            let y = CGFloat(40 - index * 70)
            let button = makePreLevelPerkButton(perk: option.0,
                                                title: option.1,
                                                subtitle: option.2,
                                                color: option.3,
                                                width: cardW - 34,
                                                zBase: overlayZ + 4)
            button.position = CGPoint(x: 0, y: y)
            card.addChild(button)
        }

        addChild(overlay)
        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.18))
        preLevelPerkOverlay = overlay
    }

    func makePreLevelPerkButton(perk: PreLevelPerk,
                                        title: String,
                                        subtitle: String,
                                        color: UIColor,
                                        width: CGFloat,
                                        zBase: CGFloat) -> SKNode {
        let button = SKNode()
        button.name = "prePerk:\(perk.rawValue)"
        button.zPosition = zBase

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 54), cornerRadius: 20)
        bg.fillColor = color.withAlphaComponent(0.14)
        bg.strokeColor = color.withAlphaComponent(0.75)
        bg.lineWidth = 1.4
        bg.name = button.name
        bg.zPosition = zBase
        button.addChild(bg)

        let dot = SKShapeNode(circleOfRadius: 17)
        dot.fillColor = color
        dot.strokeColor = .white
        dot.lineWidth = 1.5
        dot.position = CGPoint(x: -width / 2 + 32, y: 0)
        dot.name = button.name
        dot.zPosition = zBase + 1
        button.addChild(dot)

        let symbol = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        switch perk {
        case .bomb: symbol.text = String(localized: "B")
        case .moves: symbol.text = "+3"
        case .blockers: symbol.text = String(localized: "X")
        }
        symbol.fontSize = perk == .moves ? 12 : 15
        symbol.fontColor = .white
        symbol.verticalAlignmentMode = .center
        symbol.horizontalAlignmentMode = .center
        symbol.name = button.name
        symbol.zPosition = zBase + 2
        dot.addChild(symbol)

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = title
        titleLabel.fontSize = 15
        titleLabel.fontColor = UIColor(hex: "#0F172A")
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -width / 2 + 66, y: 9)
        titleLabel.name = button.name
        titleLabel.zPosition = zBase + 2
        button.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 11
        subtitleLabel.fontColor = UIColor(hex: "#64748B")
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.position = CGPoint(x: -width / 2 + 66, y: -12)
        subtitleLabel.name = button.name
        subtitleLabel.zPosition = zBase + 2
        button.addChild(subtitleLabel)

        return button
    }

    func handlePreLevelPerkTap(at point: CGPoint) {
        guard let overlay = preLevelPerkOverlay else { return }
        let local = overlay.convert(point, from: self)
        var node: SKNode? = overlay.atPoint(local)
        while let current = node {
            if let name = current.name,
               name.hasPrefix("prePerk:"),
               let perk = PreLevelPerk(rawValue: String(name.dropFirst("prePerk:".count))) {
                applyPreLevelPerk(perk)
                return
            }
            node = current.parent
        }
        Effects.haptic(.soft)
    }

    func applyPreLevelPerk(_ perk: PreLevelPerk) {
        preLevelPerkApplied = true
        preLevelPerkOverlay?.run(.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))
        preLevelPerkOverlay = nil

        switch perk {
        case .bomb:
            applyStartingBombPerk()
        case .moves:
            movesLeft += 3
            Effects.showComboBanner(text: String(localized: "+3 MOVES"), color: UIColor(hex: "#EC4899"), in: self)
        case .blockers:
            applyRemoveBlockersPerk()
        }

        Analytics.track("pre_level_perk",
                        properties: ["level": "\(levelNumber)",
                                     "perk": perk.rawValue])
        Effects.haptic(.medium)
        Effects.notify(.success)
    }

    /// Quiet dynamic-difficulty mercy: after repeated losses on a level, hand the
    /// player a starting bomb (and extra moves once they're really stuck) so a
    /// spike level doesn't become a churn wall. Announced, never silent. Skipped
    /// when the pre-level perk picker is already offering a choice.
    func applyFailStreakAssistIfNeeded() {
        guard preLevelPerkOverlay == nil, !preLevelPerkApplied else { return }
        let fails = Analytics.levelStats(for: levelNumber)["fails"] ?? 0
        guard fails >= 3 else { return }
        if fails >= 5 { movesLeft += 3 }
        applyStartingBombPerk(banner: String(localized: "HERE'S A HAND!"))
        Effects.notify(.success)
        Analytics.track("fail_streak_assist",
                        properties: ["level": "\(levelNumber)", "fails": "\(fails)"])
    }

    func applyStartingBombPerk(banner: String = String(localized: "START BOMB!")) {
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c],
                      cell.blocker == nil,
                      cell.kind == .normal else { continue }
                candidates.append(Pos(r: r, c: c))
            }
        }
        guard let p = candidates.randomElement(using: &gameplayRNG) else { return }
        grid[p.r][p.c]?.special = .bomb
        refreshNode(at: p)
        if let node = nodes[p.r][p.c] {
            node.run(.sequence([.scale(to: 1.16, duration: 0.10),
                                .scale(to: 1.0, duration: 0.14)]))
        }
        Effects.showComboBanner(text: banner, color: UIColor(hex: "#F97316"), in: self)
    }

    func applyRemoveBlockersPerk() {
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c]?.blocker != nil {
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle(using: &gameplayRNG)
        let chosen = Set(candidates.prefix(3))
        var opened: Set<Pos> = []
        for p in chosen {
            if grid[p.r][p.c]?.blocker?.type == .chest {
                opened.insert(p)
            }
            grid[p.r][p.c]?.blocker = nil
            refreshNode(at: p)
        }
        if !opened.isEmpty {
            openedChests += opened.count
            awardChestRewards(opened: opened)
        }
        Effects.showComboBanner(text: String(localized: "BLOCKERS CLEARED!"), color: UIColor(hex: "#22C55E"), in: self)
    }

    /// Randomly tag playable cells with ice / lock blockers so the level reads as harder.
    func seedBlockers(layout: LevelLayout) {
        guard layout.iceCount > 0 || layout.lockCount > 0 else { return }
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c] != nil {
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle()

        // Ice
        for p in candidates.prefix(layout.iceCount) {
            grid[p.r][p.c]?.blocker = Blocker(type: .ice, hits: 2)
        }
        // Lock — start after the ice slice so they don't stack
        let lockSlice = candidates.dropFirst(layout.iceCount).prefix(layout.lockCount)
        for p in lockSlice {
            grid[p.r][p.c]?.blocker = Blocker(type: .lock, hits: 1)
        }
    }

    func seedAdvancedMechanics(layout: LevelLayout) {
        guard layout.jellyCount > 0 ||
              layout.crateCount > 0 ||
              layout.colorLockCount > 0 ||
              layout.chocolateCount > 0 ||
              layout.chestCount > 0 ||
              layout.vineCount > 0 else { return }
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c] != nil && grid[r][c]?.blocker == nil {
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle()

        var index = 0
        func nextPosition() -> Pos? {
            guard index < candidates.count else { return nil }
            defer { index += 1 }
            return candidates[index]
        }

        for _ in 0..<layout.jellyCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .jelly, hits: 1)
        }

        for _ in 0..<layout.crateCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .crate, hits: 3)
        }

        for i in 0..<layout.colorLockCount {
            guard let p = nextPosition() else { break }
            let required = palette[i % palette.count]
            grid[p.r][p.c]?.color = required
            grid[p.r][p.c]?.blocker = Blocker(type: .colorLock,
                                              hits: 1,
                                              requiredColor: required)
        }

        for _ in 0..<layout.chocolateCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .chocolate, hits: 1)
        }
        for _ in 0..<layout.chestCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .chest, hits: 1)
        }
        for _ in 0..<layout.vineCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .vine, hits: 1)
        }
    }

    /// Once per resolved turn: pick one chocolate to spread to a neighbor,
    /// unless the player damaged a chocolate this turn. Animates the new
    /// blocker into place by refreshing the affected node.
    func applyChocolateSpreadIfDue() {
        guard !chocolateDamagedThisTurn else { return }
        let attempts = levelConfig.modifiers.contains(.chocolateSpreadsFaster) ? 2 : 1
        var spreadTargets: [Pos] = []
        for _ in 0..<attempts {
            let (newGrid, spreadTo) = Engine.spreadChocolate(grid, rng: &gameplayRNG)
            guard let target = spreadTo else { break }
            grid = newGrid
            spreadTargets.append(target)
        }
        guard !spreadTargets.isEmpty else { return }
        for target in spreadTargets {
            refreshNode(at: target)
            if let node = nodes[target.r][target.c] {
                node.run(.sequence([
                    .scale(to: 1.15, duration: 0.10),
                    .scale(to: 1.0, duration: 0.12)
                ]))
            }
        }
        Audio.shared.play(.crate)
        Effects.haptic(.light)
        Analytics.track("chocolate_spread",
                        properties: ["level": "\(levelNumber)",
                                     "count": "\(spreadTargets.count)"])
    }

    /// Per-turn fuse tick: every `.countdown` blocker counts down one. When a fuse
    /// hits zero it detonates — costs the player one move and re-arms — pressuring
    /// them to defuse it (by matching it) before it blows. Deliberately not an
    /// instant-lose: the move cost is the threat, and the normal end-of-level
    /// check resolves any resulting loss fairly.
    func tickCountdownFusesIfNeeded() {
        var detonatedAt: Pos?
        for r in 0..<rows {
            for c in 0..<cols {
                guard var cell = grid[r][c],
                      cell.blocker?.type == .countdown,
                      let count = cell.blocker?.countdown else { continue }
                let next = count - 1
                cell.blocker?.countdown = next <= 0 ? countdownFuseRearm : next
                if next <= 0 { detonatedAt = Pos(r: r, c: c) }
                grid[r][c] = cell
                refreshNode(at: Pos(r: r, c: c))
            }
        }
        guard let p = detonatedAt else { return }
        movesLeft = max(0, movesLeft - 1)
        if let node = nodes[p.r][p.c] { Effects.shake(node, intensity: 7, duration: 0.3) }
        Effects.showComboBanner(text: String(localized: "FUSE BLEW!  -1 move"),
                                color: UIColor(hex: "#EF4444"), in: self)
        Effects.notify(.warning)
        Audio.shared.play(.bomb)
        Analytics.track("countdown_fuse_blew", properties: ["level": "\(levelNumber)"])
    }

    /// Seed ingredient cells near the top of distinct columns. They drop with
    /// gravity and are collected when they hit the bottom playable row.
    func seedIngredients(layout: LevelLayout) {
        guard layout.ingredientCount > 0 else { return }
        var columns = Array(0..<cols).filter { c in
            (0..<rows).contains { r in grid[r][c] != nil && grid[r][c]?.blocker == nil }
        }
        columns.shuffle()

        var seeded = 0
        for col in columns where seeded < layout.ingredientCount {
            // Top-most playable, non-blocker row for this column.
            var topRow = -1
            for r in 0..<rows {
                if grid[r][col] != nil, grid[r][col]?.blocker == nil { topRow = r; break }
            }
            guard topRow >= 0 else { continue }
            grid[topRow][col]?.kind = .ingredient
            grid[topRow][col]?.special = nil
            seeded += 1
        }
    }

    func seedStartingBombs(layout: LevelLayout) {
        guard layout.startingBombs > 0 else { return }
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c] != nil && grid[r][c]?.blocker == nil {
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle()
        for p in candidates.prefix(layout.startingBombs) {
            grid[p.r][p.c]?.special = .bomb
        }
    }

    func remainingBlockerCount() -> Int {
        grid.reduce(0) { partial, row in
            partial + row.filter { $0?.blocker != nil }.count
        }
    }

    func rebuildAllNodes() {
        for row in nodes { for n in row { n?.removeFromParent() } }
        nodes = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c] else { continue }
                let node = makeTileNode(for: cell)
                node.position = point(forRow: r, col: c)
                worldNode.addChild(node)
                nodes[r][c] = node
            }
        }
    }

    func makeTileNode(for cell: Cell) -> SKNode {
        BoardRenderer.makeTile(cell: cell, size: tileSize, accessibilityLabel: tileAccessibilityLabel(for: cell), theme: worldTheme)
    }

    /// VoiceOver description for a board tile: fruit, then any special and any
    /// blocker, e.g. "grape, striped row, frozen". Lets a player using the
    /// screen reader perceive the board state cell by cell.
    func tileAccessibilityLabel(for cell: Cell) -> String {
        var parts: [String] = [Theme.fruitName(forColor: cell.color)]
        if let special = cell.special {
            switch special {
            case .stripedRow:  parts.append(String(localized: "striped row"))
            case .stripedCol:  parts.append(String(localized: "striped column"))
            case .wrapped:     parts.append(String(localized: "wrapped"))
            case .colorBomb:   parts.append(String(localized: "color bomb"))
            case .bomb:        parts.append(String(localized: "bomb"))
            case .fish:        parts.append(String(localized: "fish"))
            case .lineBlast:   parts.append(String(localized: "line blast"))
            case .rocket:      parts.append(String(localized: "rocket"))
            case .ufo:         parts.append(String(localized: "UFO"))
            }
        }
        if cell.kind == .ingredient { parts.append(String(localized: "basket")) }
        if cell.kind == .key { parts.append(String(localized: "key")) }
        if let blocker = cell.blocker {
            switch blocker.type {
            case .ice:       parts.append(String(localized: "frozen"))
            case .lock:      parts.append(String(localized: "locked"))
            case .colorLock: parts.append(String(localized: "color locked"))
            case .jelly:     parts.append(String(localized: "jelly"))
            case .crate:     parts.append(String(localized: "crate"))
            case .chest:     parts.append(String(localized: "chest"))
            case .vine:      parts.append(String(localized: "vine"))
            case .chocolate: parts.append(String(localized: "chocolate"))
            case .syrup:     parts.append(String(localized: "syrup"))
            case .countdown: parts.append(String(localized: "fuse \(blocker.countdown ?? 0)"))
            default: parts.append(NSLocalizedString(blocker.type.rawValue, comment: "Blocker"))
            }
        }
        return parts.joined(separator: ", ")
    }

    /// Small high-contrast geometric marker placed on each tile when the
    /// color-blind patterns setting is on. Each color gets a different shape
    /// (circle / triangle / square / diamond / star / cross) so players can
    /// tell tiles apart even when the colors look similar.
    func makeColorBlindMarker(for color: String) -> SKNode {
        let node = SKNode()
        let size: CGFloat = max(10, tileSize * 0.20)
        let halfPad: CGFloat = size * 0.18

        let bg = SKShapeNode(circleOfRadius: size * 0.78)
        bg.fillColor = UIColor(white: 0, alpha: 0.55)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.78)
        bg.lineWidth = 1
        node.addChild(bg)

        let shape = SKShapeNode(path: colorBlindMarkerPath(for: color, size: size))
        shape.fillColor = .white
        shape.strokeColor = .clear
        node.addChild(shape)
        _ = halfPad
        return node
    }

    func colorBlindMarkerPath(for color: String, size: CGFloat) -> CGPath {
        let idx = Theme.fruitIndex(forColor: color) % 6
        let half = size / 2
        let path = UIBezierPath()
        switch idx {
        case 0: // circle
            path.append(UIBezierPath(ovalIn: CGRect(x: -half * 0.7, y: -half * 0.7,
                                                     width: size * 0.7, height: size * 0.7)))
        case 1: // upward triangle
            path.move(to: CGPoint(x: 0, y: half * 0.78))
            path.addLine(to: CGPoint(x: half * 0.74, y: -half * 0.62))
            path.addLine(to: CGPoint(x: -half * 0.74, y: -half * 0.62))
            path.close()
        case 2: // square
            path.append(UIBezierPath(rect: CGRect(x: -half * 0.6, y: -half * 0.6,
                                                   width: size * 0.6, height: size * 0.6)))
        case 3: // diamond
            path.move(to: CGPoint(x: 0, y: half * 0.78))
            path.addLine(to: CGPoint(x: half * 0.78, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -half * 0.78))
            path.addLine(to: CGPoint(x: -half * 0.78, y: 0))
            path.close()
        case 4: // 5-pointed star
            let outer = half * 0.82
            let inner = outer * 0.42
            for i in 0..<10 {
                let r = i % 2 == 0 ? outer : inner
                let theta = -CGFloat.pi / 2 + CGFloat(i) * (.pi / 5)
                let pt = CGPoint(x: r * cos(theta), y: r * sin(theta))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.close()
        default: // cross / plus
            let arm = half * 0.78
            let thick = half * 0.30
            path.append(UIBezierPath(rect: CGRect(x: -thick, y: -arm,
                                                   width: thick * 2, height: arm * 2)))
            path.append(UIBezierPath(rect: CGRect(x: -arm, y: -thick,
                                                   width: arm * 2, height: thick * 2)))
        }
        return path.cgPath
    }

    func addHitBadge(to container: SKNode, hits: Int) {
        let radius = max(8, tileSize * 0.15)
        let badge = SKShapeNode(circleOfRadius: radius)
        badge.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.82)
        badge.strokeColor = .white.withAlphaComponent(0.90)
        badge.lineWidth = 1
        badge.position = CGPoint(x: tileSize * 0.27, y: tileSize * 0.27)
        badge.zPosition = 8
        container.addChild(badge)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "\(hits)"
        label.fontSize = max(9, tileSize * 0.18)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        badge.addChild(label)
    }

    func addCrackLines(to container: SKNode, tint: UIColor, alpha: CGFloat) {
        let paths: [[CGPoint]] = [
            [CGPoint(x: -0.18, y: 0.20), CGPoint(x: -0.05, y: 0.04), CGPoint(x: -0.12, y: -0.12)],
            [CGPoint(x: 0.05, y: 0.24), CGPoint(x: 0.12, y: 0.04), CGPoint(x: 0.24, y: -0.08)],
            [CGPoint(x: -0.24, y: -0.02), CGPoint(x: -0.06, y: -0.05), CGPoint(x: 0.08, y: -0.22)]
        ]
        for points in paths {
            let path = CGMutablePath()
            guard let first = points.first else { continue }
            path.move(to: CGPoint(x: first.x * tileSize, y: first.y * tileSize))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * tileSize, y: point.y * tileSize))
            }
            let line = SKShapeNode(path: path)
            line.strokeColor = tint.withAlphaComponent(alpha)
            line.lineWidth = max(1.2, tileSize * 0.035)
            line.lineCap = .round
            line.zPosition = 7
            container.addChild(line)
        }
    }

    func showMechanicImpact(_ type: BlockerType, at point: CGPoint) {
        let text: String
        let color: UIColor
        switch type {
        case .ice, .magicFrost:
            text = "CRACK"
            color = UIColor(hex: "#7DD3FC")
            Audio.shared.play(.match)
        case .lock, .cage:
            text = "OPEN"
            color = UIColor(hex: "#FACC15")
            Audio.shared.play(.tap)
        case .jelly, .bubble:
            text = "SPLASH"
            color = UIColor(hex: "#F9A8D4")
            Audio.shared.play(.jelly)
        case .crate, .stone, .solidX, .licorice:
            text = "CRUNCH"
            color = UIColor(hex: "#F59E0B")
            Audio.shared.play(.crate)
        case .colorLock:
            text = "UNLOCK"
            color = UIColor(hex: "#A78BFA")
            Audio.shared.play(.tap)
        case .chest:
            text = "CHEST"
            color = UIColor(hex: "#FACC15")
            Audio.shared.play(.combo(depth: 2))
        case .vine:
            text = "CUT"
            color = UIColor(hex: "#22C55E")
            Audio.shared.play(.match)
        case .chocolate, .cream, .donut:
            text = "CRUMBLE"
            color = UIColor(hex: "#A75B22")
            Audio.shared.play(.crate)
        case .syrup, .honey:
            text = "SPLAT"
            color = UIColor(hex: "#EC4899")
            Audio.shared.play(.jelly)
        case .countdown:
            text = "DEFUSED"
            color = UIColor(hex: "#EF4444")
            Audio.shared.play(.match)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = max(12, tileSize * 0.23)
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.zPosition = 850
        worldNode.addChild(label)

        let cracks = SKNode()
        cracks.position = point
        cracks.zPosition = 845
        for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 3) {
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: cos(angle) * tileSize * 0.30,
                                     y: sin(angle) * tileSize * 0.30))
            let shard = SKShapeNode(path: path)
            shard.strokeColor = color.withAlphaComponent(0.95)
            shard.lineWidth = max(1.4, tileSize * 0.04)
            shard.glowWidth = 2
            cracks.addChild(shard)
        }
        worldNode.addChild(cracks)
        cracks.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.18),
                    .fadeOut(withDuration: 0.24)]),
            .removeFromParent()
        ]))
        label.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.12),
                    .moveBy(x: 0, y: tileSize * 0.36, duration: 0.38)]),
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ]))
    }

}
