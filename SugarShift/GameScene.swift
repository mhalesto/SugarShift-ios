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
    var palette: [String] { Array(Theme.colors.prefix(levelConfig.colors)) }
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
    var isResolving = false
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

    var score: Int = 0 { didSet { updateHUD() } }
    var movesLeft: Int = 0 { didSet { updateHUD(); maybeLowMovesTension(old: oldValue) } }
    var startingBlockers = 0 { didSet { updateHUD() } }
    var collectedGoalTiles = 0 { didSet { updateHUD() } }
    var createdSpecials = 0 { didSet { updateHUD() } }
    var detonatedBombs = 0 { didSet { updateHUD() } }
    var collectedIngredients = 0 { didSet { updateHUD() } }
    var collectedKeys = 0 { didSet { updateHUD() } }
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

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        safeTop = view.safeAreaInsets.top
        safeBottom = view.safeAreaInsets.bottom

        worldNode = SKNode()
        addChild(worldNode)

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
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        rebuildAllNodes()
        rebuildSyrupBand()
    }

    func rebuildChapterBackdrop() {
        childNode(withName: "chapterBackdrop")?.removeFromParent()
        guard size.width > 0, size.height > 0 else { return }

        let chapter = Levels.chapter(for: levelNumber)
        let palette: [UIColor]
        switch chapter.title {
        case "Frost Valley":
            palette = [UIColor(hex: "#7DD3FC"), UIColor(hex: "#E0F2FE"), UIColor(hex: "#A7F3D0")]
        case "Bomb Bakery":
            palette = [UIColor(hex: "#F97316"), UIColor(hex: "#FDE68A"), UIColor(hex: "#F472B6")]
        case "Crown Gate":
            palette = [UIColor(hex: "#FACC15"), UIColor(hex: "#F9A8D4"), UIColor(hex: "#A78BFA")]
        case "Royal Rush":
            palette = [UIColor(hex: "#8B5CF6"), UIColor(hex: "#22D3EE"), UIColor(hex: "#F472B6")]
        case "Sugar Throne":
            palette = [UIColor(hex: "#0F172A"), UIColor(hex: "#7C3AED"), UIColor(hex: "#F59E0B")]
        default:
            palette = [UIColor(hex: "#FBCFE8"), UIColor(hex: "#FDE68A"), UIColor(hex: "#BAE6FD")]
        }

        let backdrop = SKNode()
        backdrop.name = "chapterBackdrop"
        backdrop.zPosition = -2500

        let bandH = size.height / CGFloat(palette.count)
        for (index, color) in palette.enumerated() {
            let band = SKShapeNode(rectOf: CGSize(width: size.width, height: bandH + 2))
            band.fillColor = color.withAlphaComponent(index == 0 ? 0.82 : 0.72)
            band.strokeColor = .clear
            band.position = CGPoint(x: 0, y: size.height / 2 - bandH * (CGFloat(index) + 0.5))
            backdrop.addChild(band)
        }

        for i in 0..<18 {
            let sparkle = SKShapeNode(rectOf: CGSize(width: 5, height: 5), cornerRadius: 1)
            sparkle.fillColor = UIColor.white.withAlphaComponent(i.isMultiple(of: 3) ? 0.28 : 0.16)
            sparkle.strokeColor = .clear
            sparkle.zRotation = .pi / 4
            sparkle.position = CGPoint(x: CGFloat.random(in: -size.width / 2...size.width / 2),
                                       y: CGFloat.random(in: -size.height / 2...size.height / 2))
            backdrop.addChild(sparkle)
        }

        addChild(backdrop)
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
        let headerH: CGFloat = 170
        let headerBottom = size.height / 2 - safeTop - 8 - headerH
        let container = SKNode()
        container.name = "smashMeterButton"
        container.position = CGPoint(x: 0, y: headerBottom - 16)
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
        caption.position = CGPoint(x: 0, y: -15)
        container.addChild(caption)
        comboMeterCaption = caption

        let flow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        flow.fontSize = 9.5
        flow.fontColor = UIColor(hex: "#FDE68A")
        flow.verticalAlignmentMode = .center
        flow.horizontalAlignmentMode = .center
        flow.position = CGPoint(x: 0, y: 17)
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
        ]))
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
        undoSnapshot = UndoSnapshot(grid: grid,
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
        if footerCard != nil {
            let cardW = size.width - 24
            let cardH: CGFloat = 180
            let rightX = cardW / 2 - 18
            let topRowY = cardH / 2 - 28
            btn.position = CGPoint(x: rightX - 78, y: topRowY)
        } else {
            btn.position = CGPoint(x: size.width / 2 - 100, y: -size.height / 2 + safeBottom + 160)
        }
        btn.zPosition = 3
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

        (footerCard ?? self).addChild(btn)
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
        let headerH: CGFloat = 170
        let footerH: CGFloat = 180
        let headerBottom = size.height / 2 - safeTop - 8 - headerH
        let footerTop = -size.height / 2 + safeBottom + 8 + footerH

        let pad: CGFloat = 14
        let safeWidth = size.width - pad * 2
        let safeHeight = (headerBottom - footerTop) - 16
        let side = min(safeWidth, safeHeight)
        gap = Persistence.shapedBoard ? 0 : side * 0.012
        tileSize = (side - gap * CGFloat(cols + 1)) / CGFloat(cols)
        let boardSide = tileSize * CGFloat(cols) + gap * CGFloat(cols + 1)

        let centerY = (headerBottom + footerTop) / 2
        boardOrigin = CGPoint(
            x: -boardSide / 2 + gap + tileSize / 2,
            y: centerY + boardSide / 2 - gap - tileSize / 2
        )

        worldNode.childNode(withName: "boardBackdrop")?.removeFromParent()
        worldNode.childNode(withName: "shapeMat")?.removeFromParent()
        worldNode.childNode(withName: "tileCornerFillers")?.removeFromParent()
        worldNode.childNode(withName: "mechanicsLayer")?.removeFromParent()
        if Persistence.shapedBoard {
            buildShapeMat()
            buildInteriorCornerFillers()
        } else {
            let bg = SKShapeNode(rectOf: CGSize(width: boardSide + 12, height: boardSide + 12), cornerRadius: 22)
            bg.name = "boardBackdrop"
            bg.position = CGPoint(x: 0, y: centerY)
            bg.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.92)
            bg.strokeColor = UIColor(white: 1, alpha: 0.08)
            bg.lineWidth = 1
            bg.zPosition = -10
            worldNode.addChild(bg)
        }
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
                ring.run(.repeatForever(.sequence([
                    .scale(to: 1.10, duration: 0.8),
                    .scale(to: 1.0, duration: 0.8)
                ])))
            }
        }

        worldNode.addChild(layer)
    }

    /// Build a connected backdrop that hugs the playable cells. Each cell gets
    /// a rounded square slightly larger than `tileSize` so adjacent ones merge
    /// into a single shape — mimicking the Candy Crush mat look.
    func buildShapeMat() {
        let mat = SKNode()
        mat.name = "shapeMat"
        mat.zPosition = -10
        let radius = tileSize * 0.22
        // pad must be ≥ 2r·(1 − 1/√2) ≈ 0.59·r so adjacent rounded mats overlap
        // enough to cover the diamond gap where four corners meet.
        let pad: CGFloat = max(6, radius * 0.7)
        let mask = levelConfig.layout.mask
        let fill = UIColor(hex: "#0F172A").withAlphaComponent(0.92)
        for r in 0..<rows {
            for c in 0..<cols {
                if let m = mask, !m[r][c] { continue }
                let p = point(forRow: r, col: c)
                let cell = SKShapeNode(
                    rectOf: CGSize(width: tileSize + pad, height: tileSize + pad),
                    cornerRadius: radius
                )
                cell.fillColor = fill
                cell.strokeColor = .clear
                cell.position = p
                mat.addChild(cell)

                // Sharp filler squares between adjacent playable cells erase
                // the residual diamond gaps without rounding the outer edges.
                let inset = tileSize * 0.5
                if c + 1 < cols, mask?[r][c + 1] ?? true {
                    let bridge = SKShapeNode(rectOf: CGSize(width: pad + 2, height: tileSize))
                    bridge.fillColor = fill
                    bridge.strokeColor = .clear
                    bridge.position = CGPoint(x: p.x + inset, y: p.y)
                    mat.addChild(bridge)
                }
                if r + 1 < rows, mask?[r + 1][c] ?? true {
                    let bridge = SKShapeNode(rectOf: CGSize(width: tileSize, height: pad + 2))
                    bridge.fillColor = fill
                    bridge.strokeColor = .clear
                    bridge.position = CGPoint(x: p.x, y: p.y - inset)
                    mat.addChild(bridge)
                }
            }
        }
        worldNode.addChild(mat)
    }

    /// Fill only the tiny internal junctions where four rounded playable tiles meet.
    /// This keeps shaped-board silhouettes intact while removing accidental-looking holes.
    func buildInteriorCornerFillers() {
        guard rows > 1, cols > 1 else { return }
        let layer = SKNode()
        layer.name = "tileCornerFillers"
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
        towerRun = levelNumber == Levels.towerLevel
            ? (TowerMode.activeRun() ?? TowerMode.startNewRun())
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
            let headStacks = run.perks.filter { $0 == .headStart }.count
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
        let container = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize), cornerRadius: tileSize * 0.22)
        body.fillColor = skin.tileBg
        body.strokeColor = Persistence.highContrast ? .white : skin.tileBorder
        body.lineWidth = Persistence.highContrast ? 2 : 1
        body.name = "body"
        container.addChild(body)

        let emoji = SKSpriteNode(texture: Theme.emojiTexture(forColor: cell.color))
        emoji.size = CGSize(width: tileSize * 0.78, height: tileSize * 0.78)
        emoji.name = "emoji"
        if let blocker = cell.blocker {
            switch blocker.type {
            case .lock, .colorLock:
                emoji.alpha = 0.88
            case .ice, .jelly, .syrup, .countdown:
                emoji.alpha = 0.78
            case .crate, .chocolate, .chest, .vine:
                emoji.alpha = 0.52
            }
        } else {
            emoji.alpha = cell.special == .colorBomb ? 0.2 : (cell.special == .fish ? 0.3 : 1.0)
        }
        container.addChild(emoji)

        // Ingredient overlay — a fruit basket "halo" so players can spot the
        // tiles that need to fall to the bottom.
        if cell.kind == .ingredient {
            let halo = SKShapeNode(rectOf: CGSize(width: tileSize - 4, height: tileSize - 4),
                                   cornerRadius: tileSize * 0.28)
            halo.fillColor = .clear
            halo.strokeColor = UIColor(hex: "#34D399").withAlphaComponent(0.95)
            halo.lineWidth = 3
            halo.glowWidth = 4
            halo.zPosition = 7
            container.addChild(halo)
            halo.run(.repeatForever(.sequence([
                .scale(to: 1.05, duration: 0.6),
                .scale(to: 1.0,  duration: 0.6)
            ])))

            let basket = Icons.sprite("basket.fill",
                                      size: tileSize * 0.30,
                                      weight: .bold,
                                      tint: UIColor(hex: "#34D399"))
            basket.position = CGPoint(x: tileSize * 0.30, y: -tileSize * 0.30)
            basket.zPosition = 8
            container.addChild(basket)
        }

        if cell.kind == .key {
            let halo = SKShapeNode(rectOf: CGSize(width: tileSize - 4, height: tileSize - 4),
                                   cornerRadius: tileSize * 0.28)
            halo.fillColor = UIColor(hex: "#FEF3C7").withAlphaComponent(0.16)
            halo.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.98)
            halo.lineWidth = 3
            halo.glowWidth = 5
            halo.zPosition = 7
            container.addChild(halo)
            halo.run(.repeatForever(.sequence([
                .scale(to: 1.06, duration: 0.55),
                .scale(to: 1.0,  duration: 0.55)
            ])))

            let key = Icons.sprite("key.fill",
                                   size: tileSize * 0.32,
                                   weight: .bold,
                                   tint: UIColor(hex: "#FACC15"))
            key.position = CGPoint(x: tileSize * 0.29, y: -tileSize * 0.29)
            key.zPosition = 8
            container.addChild(key)
        }

        if Persistence.candyLabels {
            let labels = ["O", "G", "B", "A", "Y", "C"]
            let idx = Theme.fruitIndex(forColor: cell.color) % labels.count
            let tag = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            tag.text = labels[idx]
            tag.fontSize = max(10, tileSize * 0.22)
            tag.fontColor = .white
            tag.verticalAlignmentMode = .center
            tag.horizontalAlignmentMode = .center
            tag.position = CGPoint(x: tileSize * 0.28, y: -tileSize * 0.28)
            tag.zPosition = 6

            let bg = SKShapeNode(circleOfRadius: max(8, tileSize * 0.16))
            bg.fillColor = UIColor(white: 0, alpha: 0.62)
            bg.strokeColor = .white.withAlphaComponent(0.75)
            bg.lineWidth = 1
            bg.position = tag.position
            bg.zPosition = 5
            container.addChild(bg)
            container.addChild(tag)
        }

        // Color-blind pattern overlay — a unique geometric marker per color,
        // placed in the top-left so it doesn't fight the fruit emoji or the
        // optional candy label in the bottom-right.
        if Persistence.colorBlindPatterns {
            let marker = makeColorBlindMarker(for: cell.color)
            marker.position = CGPoint(x: -tileSize * 0.28, y: tileSize * 0.28)
            marker.zPosition = 7
            container.addChild(marker)
        }

        // Ice overlay — translucent icy blue + snowflake symbol
        if let blocker = cell.blocker, blocker.type == .ice {
            let strength: CGFloat = blocker.hits > 1 ? 0.30 : 0.18
            let ice = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2),
                                  cornerRadius: tileSize * 0.22)
            ice.fillColor = UIColor(hex: "#7DD3FC").withAlphaComponent(strength)
            ice.strokeColor = UIColor(hex: "#38BDF8").withAlphaComponent(0.75)
            ice.lineWidth = 2
            ice.glowWidth = 2
            ice.zPosition = 4
            container.addChild(ice)

            if blocker.hits > 1 {
                addCrackLines(to: container, tint: UIColor(hex: "#E0F2FE"), alpha: 0.90)
            }

            let frost = Icons.sprite("snowflake",
                                     size: tileSize * 0.42,
                                     weight: .heavy,
                                     tint: .white)
            frost.alpha = 0.95
            frost.zPosition = 5
            container.addChild(frost)
            frost.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.6, duration: 1.0),
                .fadeAlpha(to: 0.95, duration: 1.0)
            ])))
            _ = blocker
        }

        // Lock overlay — readable tint + corner lock, leaving the fruit visible.
        if let blocker = cell.blocker, blocker.type == .lock {
            let scrim = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2),
                                    cornerRadius: tileSize * 0.22)
            scrim.fillColor = UIColor(hex: "#FEF3C7").withAlphaComponent(0.10)
            scrim.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.95)
            scrim.lineWidth = 2
            scrim.glowWidth = 1.5
            scrim.zPosition = 4
            container.addChild(scrim)

            let badge = SKShapeNode(circleOfRadius: tileSize * 0.17)
            badge.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.78)
            badge.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.98)
            badge.lineWidth = 1.2
            badge.position = CGPoint(x: -tileSize * 0.27, y: -tileSize * 0.27)
            badge.zPosition = 5
            container.addChild(badge)

            let lock = Icons.sprite("lock.fill",
                                    size: tileSize * 0.20,
                                    weight: .heavy,
                                    tint: .white)
            lock.position = badge.position
            lock.zPosition = 6
            container.addChild(lock)
            _ = blocker
        }

        if let blocker = cell.blocker, blocker.type == .jelly {
            let jelly = SKShapeNode(rectOf: CGSize(width: tileSize - 4, height: tileSize - 4),
                                    cornerRadius: tileSize * 0.28)
            jelly.fillColor = UIColor(hex: "#F9A8D4").withAlphaComponent(0.38)
            jelly.strokeColor = UIColor(hex: "#EC4899").withAlphaComponent(0.70)
            jelly.lineWidth = 2
            jelly.glowWidth = 2
            jelly.zPosition = 4
            container.addChild(jelly)

            let drop = Icons.sprite("drop.fill",
                                    size: tileSize * 0.34,
                                    weight: .bold,
                                    tint: .white)
            drop.alpha = 0.86
            drop.zPosition = 5
            container.addChild(drop)
        }

        if let blocker = cell.blocker, blocker.type == .crate {
            let crate = SKShapeNode(rectOf: CGSize(width: tileSize - 5, height: tileSize - 5),
                                    cornerRadius: tileSize * 0.12)
            crate.fillColor = UIColor(hex: "#92400E").withAlphaComponent(0.62)
            crate.strokeColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.82)
            crate.lineWidth = 2
            crate.zPosition = 4
            container.addChild(crate)

            for angle in [CGFloat.pi / 4, -CGFloat.pi / 4] {
                let plank = SKShapeNode(rectOf: CGSize(width: tileSize * 0.78, height: tileSize * 0.10),
                                        cornerRadius: tileSize * 0.04)
                plank.fillColor = UIColor(hex: "#F59E0B").withAlphaComponent(0.82)
                plank.strokeColor = .clear
                plank.zRotation = angle
                plank.zPosition = 5
                container.addChild(plank)
            }

            let hits = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            hits.text = "\(max(1, blocker.hits))"
            hits.fontSize = max(11, tileSize * 0.24)
            hits.fontColor = .white
            hits.verticalAlignmentMode = .center
            hits.horizontalAlignmentMode = .center
            hits.zPosition = 6
            container.addChild(hits)
        }

        if let blocker = cell.blocker, blocker.type == .chocolate {
            let cocoa = SKShapeNode(rectOf: CGSize(width: tileSize - 3, height: tileSize - 3),
                                    cornerRadius: tileSize * 0.20)
            cocoa.fillColor = UIColor(hex: "#3B1F0E").withAlphaComponent(0.92)
            cocoa.strokeColor = UIColor(hex: "#7C3A12").withAlphaComponent(0.95)
            cocoa.lineWidth = 2
            cocoa.zPosition = 4
            container.addChild(cocoa)

            // Flecks of "chocolate chunks" — small round shapes scattered.
            for offset in [CGPoint(x: -tileSize * 0.18, y: tileSize * 0.10),
                           CGPoint(x: tileSize * 0.16,  y: -tileSize * 0.06),
                           CGPoint(x: tileSize * 0.02,  y: tileSize * 0.22),
                           CGPoint(x: -tileSize * 0.22, y: -tileSize * 0.18)] {
                let chunk = SKShapeNode(circleOfRadius: tileSize * 0.07)
                chunk.fillColor = UIColor(hex: "#6B2A0C").withAlphaComponent(0.95)
                chunk.strokeColor = UIColor(hex: "#A75B22").withAlphaComponent(0.7)
                chunk.lineWidth = 1
                chunk.position = offset
                chunk.zPosition = 5
                container.addChild(chunk)
            }

            // Subtle "creeping" pulse so the spreader feels alive.
            cocoa.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.78, duration: 1.4),
                .fadeAlpha(to: 0.95, duration: 1.4)
            ])))
            _ = blocker
        }

        if let blocker = cell.blocker, blocker.type == .syrup {
            let goo = SKShapeNode(rectOf: CGSize(width: tileSize - 3, height: tileSize - 3),
                                  cornerRadius: tileSize * 0.20)
            goo.fillColor = UIColor(hex: "#EC4899").withAlphaComponent(0.48)
            goo.strokeColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.92)
            goo.lineWidth = 2
            goo.glowWidth = 3
            goo.zPosition = 4
            container.addChild(goo)

            // Drip droplets on the bottom edge to sell the "sticky" feeling.
            for offset in [CGPoint(x: -tileSize * 0.20, y: -tileSize * 0.30),
                           CGPoint(x:  tileSize * 0.08, y: -tileSize * 0.36),
                           CGPoint(x:  tileSize * 0.26, y: -tileSize * 0.28)] {
                let drop = SKShapeNode(circleOfRadius: tileSize * 0.06)
                drop.fillColor = UIColor(hex: "#F472B6").withAlphaComponent(0.85)
                drop.strokeColor = UIColor.white.withAlphaComponent(0.55)
                drop.lineWidth = 1
                drop.position = offset
                drop.zPosition = 5
                container.addChild(drop)
                drop.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: -1.5, duration: 0.8),
                    .moveBy(x: 0, y: 1.5,  duration: 0.8)
                ])))
            }
            _ = blocker
        }

        if let blocker = cell.blocker, blocker.type == .colorLock {
            let lockRing = SKShapeNode(rectOf: CGSize(width: tileSize - 4, height: tileSize - 4),
                                       cornerRadius: tileSize * 0.22)
            lockRing.fillColor = UIColor(hex: "#F8FAFC").withAlphaComponent(0.14)
            lockRing.strokeColor = UIColor(hex: blocker.requiredColor ?? cell.color).withAlphaComponent(0.95)
            lockRing.lineWidth = 3
            lockRing.glowWidth = 3
            lockRing.zPosition = 4
            container.addChild(lockRing)

            let colorKey = blocker.requiredColor ?? cell.color
            let required = SKSpriteNode(texture: Theme.emojiTexture(forColor: colorKey))
            required.size = CGSize(width: tileSize * 0.30, height: tileSize * 0.30)
            required.position = CGPoint(x: tileSize * 0.24, y: tileSize * 0.24)
            required.zPosition = 5
            container.addChild(required)

            let badge = SKShapeNode(circleOfRadius: tileSize * 0.15)
            badge.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.72)
            badge.strokeColor = .white.withAlphaComponent(0.85)
            badge.lineWidth = 1
            badge.position = CGPoint(x: -tileSize * 0.25, y: -tileSize * 0.25)
            badge.zPosition = 5
            container.addChild(badge)

            let miniLock = Icons.sprite("lock.open",
                                        size: tileSize * 0.16,
                                        weight: .heavy,
                                        tint: .white)
            miniLock.position = badge.position
            miniLock.zPosition = 6
            container.addChild(miniLock)
        }

        if let blocker = cell.blocker, blocker.type == .chest {
            let chest = SKShapeNode(rectOf: CGSize(width: tileSize - 4, height: tileSize - 4),
                                    cornerRadius: tileSize * 0.18)
            chest.fillColor = UIColor(hex: "#92400E").withAlphaComponent(0.76)
            chest.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.95)
            chest.lineWidth = 2
            chest.glowWidth = 2
            chest.zPosition = 4
            container.addChild(chest)

            let lid = SKShapeNode(rectOf: CGSize(width: tileSize * 0.70, height: tileSize * 0.18),
                                  cornerRadius: tileSize * 0.07)
            lid.fillColor = UIColor(hex: "#F59E0B").withAlphaComponent(0.96)
            lid.strokeColor = .clear
            lid.position = CGPoint(x: 0, y: tileSize * 0.12)
            lid.zPosition = 5
            container.addChild(lid)

            let lock = Icons.sprite("lock.fill",
                                    size: tileSize * 0.20,
                                    weight: .heavy,
                                    tint: UIColor(hex: "#FEF3C7"))
            lock.zPosition = 6
            container.addChild(lock)
        }

        if let blocker = cell.blocker, blocker.type == .vine {
            let ring = SKShapeNode(rectOf: CGSize(width: tileSize - 5, height: tileSize - 5),
                                   cornerRadius: tileSize * 0.20)
            ring.fillColor = UIColor(hex: "#064E3B").withAlphaComponent(0.22)
            ring.strokeColor = UIColor(hex: "#22C55E").withAlphaComponent(0.92)
            ring.lineWidth = 2
            ring.glowWidth = 2
            ring.zPosition = 4
            container.addChild(ring)

            for angle in [CGFloat.pi / 5, -CGFloat.pi / 5] {
                let rope = SKShapeNode(rectOf: CGSize(width: tileSize * 0.82, height: tileSize * 0.08),
                                       cornerRadius: tileSize * 0.04)
                rope.fillColor = UIColor(hex: "#16A34A").withAlphaComponent(0.90)
                rope.strokeColor = UIColor(hex: "#BBF7D0").withAlphaComponent(0.70)
                rope.lineWidth = 1
                rope.zRotation = angle
                rope.zPosition = 5
                container.addChild(rope)
            }
        }

        if let blocker = cell.blocker, blocker.hits > 1, blocker.type != .crate {
            addHitBadge(to: container, hits: blocker.hits)
        }

        // Bomb overlay — pulsing red glow + drawn bomb (black sphere + fuse spark)
        if cell.special == .bomb {
            let glow = SKShapeNode(circleOfRadius: tileSize * 0.42)
            glow.fillColor = UIColor(hex: "#EF4444").withAlphaComponent(0.4)
            glow.strokeColor = .clear
            glow.glowWidth = 6
            glow.blendMode = .add
            glow.zPosition = 1
            container.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .scale(to: 1.18, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))

            let bombGroup = SKNode()
            bombGroup.zPosition = 2
            bombGroup.position = CGPoint(x: 0, y: 0)
            container.addChild(bombGroup)

            // Bomb body — black sphere with subtle highlight
            let bodyR = tileSize * 0.30
            let body = SKShapeNode(circleOfRadius: bodyR)
            body.fillColor = UIColor(hex: "#0F172A")
            body.strokeColor = UIColor(white: 1, alpha: 0.15)
            body.lineWidth = 1
            bombGroup.addChild(body)
            let bodyHi = SKShapeNode(circleOfRadius: bodyR * 0.32)
            bodyHi.fillColor = UIColor.white.withAlphaComponent(0.4)
            bodyHi.strokeColor = .clear
            bodyHi.position = CGPoint(x: -bodyR * 0.35, y: bodyR * 0.40)
            bombGroup.addChild(bodyHi)

            // Fuse — short curved line (rotated rectangle)
            let fuse = SKShapeNode(rectOf: CGSize(width: tileSize * 0.05, height: tileSize * 0.18),
                                   cornerRadius: tileSize * 0.025)
            fuse.fillColor = UIColor(hex: "#92400E")
            fuse.strokeColor = .clear
            fuse.position = CGPoint(x: bodyR * 0.55, y: bodyR * 0.92)
            fuse.zRotation = -0.4
            bombGroup.addChild(fuse)

            // Fuse spark (yellow dot, twinkles)
            let spark = SKShapeNode(circleOfRadius: tileSize * 0.05)
            spark.fillColor = UIColor(hex: "#FBBF24")
            spark.strokeColor = UIColor.white.withAlphaComponent(0.9)
            spark.lineWidth = 1
            spark.glowWidth = 4
            spark.position = CGPoint(x: bodyR * 0.95, y: bodyR * 1.30)
            bombGroup.addChild(spark)
            spark.run(.repeatForever(.sequence([
                .scale(to: 1.3, duration: 0.18),
                .scale(to: 0.85, duration: 0.18)
            ])))

            bombGroup.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 2, duration: 0.5),
                .moveBy(x: 0, y: -2, duration: 0.5)
            ])))
        }

        if cell.special == .stripedRow || cell.special == .stripedCol {
            let stripeLayer = SKNode()
            stripeLayer.zPosition = 2
            container.addChild(stripeLayer)

            let stripeCount = 3
            for i in 0..<stripeCount {
                let offset = CGFloat(i - 1) * tileSize * 0.22
                let stripe: SKShapeNode
                if cell.special == .stripedRow {
                    stripe = SKShapeNode(rectOf: CGSize(width: tileSize * 0.78, height: tileSize * 0.09),
                                         cornerRadius: tileSize * 0.04)
                    stripe.position = CGPoint(x: 0, y: offset)
                } else {
                    stripe = SKShapeNode(rectOf: CGSize(width: tileSize * 0.09, height: tileSize * 0.78),
                                         cornerRadius: tileSize * 0.04)
                    stripe.position = CGPoint(x: offset, y: 0)
                }
                stripe.fillColor = UIColor.white.withAlphaComponent(0.72)
                stripe.strokeColor = UIColor(hex: cell.color).withAlphaComponent(0.8)
                stripe.lineWidth = 1
                stripeLayer.addChild(stripe)
            }

            let glow = SKShapeNode(rectOf: CGSize(width: tileSize * 0.9, height: tileSize * 0.9),
                                   cornerRadius: tileSize * 0.22)
            glow.fillColor = UIColor.clear
            glow.strokeColor = UIColor.white.withAlphaComponent(0.55)
            glow.lineWidth = 2
            glow.glowWidth = 4
            glow.zPosition = 1
            container.addChild(glow)
        }

        if cell.special == .wrapped {
            let wrap = SKNode()
            wrap.zPosition = 2
            container.addChild(wrap)

            let bandColor = UIColor(hex: "#FDE68A")
            for angle in [CGFloat.pi / 4, -CGFloat.pi / 4] {
                let band = SKShapeNode(rectOf: CGSize(width: tileSize * 0.92, height: tileSize * 0.12),
                                       cornerRadius: tileSize * 0.05)
                band.fillColor = bandColor.withAlphaComponent(0.9)
                band.strokeColor = UIColor(hex: "#F59E0B")
                band.lineWidth = 1
                band.zRotation = angle
                wrap.addChild(band)
            }

            let knot = SKShapeNode(circleOfRadius: tileSize * 0.13)
            knot.fillColor = UIColor(hex: "#F97316")
            knot.strokeColor = .white
            knot.lineWidth = 1.5
            knot.glowWidth = 3
            wrap.addChild(knot)
        }

        if cell.special == .colorBomb {
            let orb = SKShapeNode(circleOfRadius: tileSize * 0.34)
            orb.fillColor = UIColor(hex: "#111827")
            orb.strokeColor = UIColor.white.withAlphaComponent(0.45)
            orb.lineWidth = 1.5
            orb.glowWidth = 5
            orb.zPosition = 2
            container.addChild(orb)

            let sprinkleColors = ["#F472B6", "#60A5FA", "#FACC15", "#34D399", "#FB923C", "#FFFFFF"]
            for i in 0..<10 {
                let angle = CGFloat(i) * (.pi * 2 / 10)
                let radius = tileSize * (i.isMultiple(of: 2) ? 0.17 : 0.25)
                let dot = SKShapeNode(circleOfRadius: tileSize * 0.035)
                dot.fillColor = UIColor(hex: sprinkleColors[i % sprinkleColors.count])
                dot.strokeColor = .clear
                dot.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                dot.zPosition = 3
                container.addChild(dot)
            }
        }

        if cell.special == .fish {
            let body = SKShapeNode(ellipseOf: CGSize(width: tileSize * 0.6, height: tileSize * 0.4))
            body.fillColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.92)
            body.strokeColor = .white
            body.lineWidth = 2
            body.zPosition = 4
            container.addChild(body)

            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: tileSize * 0.26, y: 0))
            tailPath.addLine(to: CGPoint(x: tileSize * 0.44, y: tileSize * 0.16))
            tailPath.addLine(to: CGPoint(x: tileSize * 0.44, y: -tileSize * 0.16))
            tailPath.close()
            let tail = SKShapeNode(path: tailPath.cgPath)
            tail.fillColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.92)
            tail.strokeColor = .white
            tail.lineWidth = 1.5
            tail.zPosition = 4
            container.addChild(tail)

            let eye = SKShapeNode(circleOfRadius: tileSize * 0.05)
            eye.fillColor = .white
            eye.strokeColor = UIColor(hex: "#0F172A")
            eye.lineWidth = 1
            eye.position = CGPoint(x: -tileSize * 0.14, y: tileSize * 0.06)
            eye.zPosition = 5
            container.addChild(eye)
        }

        if let blocker = cell.blocker, blocker.type == .countdown {
            let scrim = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2),
                                    cornerRadius: tileSize * 0.22)
            scrim.fillColor = UIColor(hex: "#7F1D1D").withAlphaComponent(0.16)
            scrim.strokeColor = UIColor(hex: "#EF4444").withAlphaComponent(0.95)
            scrim.lineWidth = 2
            scrim.glowWidth = 1.5
            scrim.zPosition = 4
            container.addChild(scrim)

            let badge = SKShapeNode(circleOfRadius: tileSize * 0.22)
            badge.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.82)
            badge.strokeColor = UIColor(hex: "#EF4444")
            badge.lineWidth = 1.5
            badge.zPosition = 5
            container.addChild(badge)

            let num = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            num.text = "\(blocker.countdown ?? 0)"
            num.fontSize = max(11, tileSize * 0.30)
            num.fontColor = .white
            num.verticalAlignmentMode = .center
            num.horizontalAlignmentMode = .center
            num.zPosition = 6
            container.addChild(num)
        }

        container.isAccessibilityElement = true
        container.accessibilityLabel = tileAccessibilityLabel(for: cell)
        container.accessibilityTraits = .button

        container.userData = NSMutableDictionary(dictionary: ["color": cell.color])
        return container
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
        case .ice:
            text = "CRACK"
            color = UIColor(hex: "#7DD3FC")
            Audio.shared.play(.match)
        case .lock:
            text = "OPEN"
            color = UIColor(hex: "#FACC15")
            Audio.shared.play(.tap)
        case .jelly:
            text = "SPLASH"
            color = UIColor(hex: "#F9A8D4")
            Audio.shared.play(.jelly)
        case .crate:
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
        case .chocolate:
            text = "CRUMBLE"
            color = UIColor(hex: "#A75B22")
            Audio.shared.play(.crate)
        case .syrup:
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
