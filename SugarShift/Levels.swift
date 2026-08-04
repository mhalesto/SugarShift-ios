import UIKit

// MARK: - Level archetypes

enum LevelArchetype {
    case starter      // pure score, gentle pacing
    case combo        // rewards cascades — tighter moves, generous target
    case ice          // ice blockers seeded on the board
    case lock         // lock blockers seeded on the board
    case crowded      // smaller board, more colors
    case bombRush     // bombs are pre-seeded and special creation matters more
    case finale       // boss flavor — exotic shape + many blockers
}

enum LevelGoal: Equatable {
    case score
    case clearBlockers
    case collectColor(index: Int, count: Int)
    case createSpecials(count: Int)
    case detonateBombs(count: Int)
    /// Drop fruit baskets to the bottom of the board.
    case collectIngredients(count: Int)
    /// Drop keys to the bottom of the board.
    case collectKeys(count: Int)
    /// Open chest blockers by matching beside them or collecting keys.
    case openChests(count: Int)
    /// Mixed drop mission for boards that seed both baskets and keys.
    case collectIngredientsAndKeys(ingredients: Int, keys: Int)

    var title: String {
        switch self {
        case .score:
            return String(localized: "Reach score")
        case .clearBlockers:
            return String(localized: "Clear blockers")
        case .collectColor(let index, let count):
            return String(localized: "Collect \(count) \(LevelGoal.fruitName(for: index))")
        case .createSpecials(let count):
            return String(localized: "Create \(count) specials")
        case .detonateBombs(let count):
            return String(localized: "Detonate \(count) bombs")
        case .collectIngredients(let count):
            return String(localized: "Drop \(count) baskets")
        case .collectKeys(let count):
            return String(localized: "Collect \(count) keys")
        case .openChests(let count):
            return String(localized: "Open \(count) chests")
        case .collectIngredientsAndKeys(let ingredients, let keys):
            return String(localized: "Drop \(ingredients) baskets + \(keys) keys")
        }
    }

    var previewText: String {
        switch self {
        case .score:
            return String(localized: "Reach the target score.")
        case .clearBlockers:
            return String(localized: "Break every blocker tile.")
        case .collectColor(let index, let count):
            return String(localized: "Collect \(count) \(LevelGoal.fruitName(for: index)) pieces.")
        case .createSpecials(let count):
            return String(localized: "Create \(count) striped, wrapped, color, or bomb specials.")
        case .detonateBombs(let count):
            return String(localized: "Detonate \(count) bomb specials.")
        case .collectIngredients(let count):
            return String(localized: "Drop \(count) fruit baskets off the bottom.")
        case .collectKeys(let count):
            return String(localized: "Drop \(count) keys off the bottom.")
        case .openChests(let count):
            return String(localized: "Open \(count) chests with nearby matches or keys.")
        case .collectIngredientsAndKeys(let ingredients, let keys):
            return String(localized: "Drop \(ingredients) baskets and \(keys) keys.")
        }
    }

    static func fruitName(for index: Int) -> String {
        let names = ["orange", "grape", "blueberry", "apple", "banana", "cherry"]
        return names[max(0, index) % names.count]
    }
}

struct LevelChapter: Equatable {
    let title: String
    let subtitle: String
    let range: ClosedRange<Int>
}

enum LevelDifficulty: String, Equatable {
    case normal = "Normal"
    case hard = "Hard"
    case superHard = "Super Hard"
    case crownChallenge = "Crown Challenge"

    /// Localized, user-facing name (the raw value stays a stable identifier
    /// used for analytics and lookups).
    var displayName: String {
        switch self {
        case .normal: return String(localized: "Normal")
        case .hard: return String(localized: "Hard")
        case .superHard: return String(localized: "Super Hard")
        case .crownChallenge: return String(localized: "Crown Challenge")
        }
    }
}

enum LevelModifier: String, Equatable, CaseIterable {
    case noBoosters
    case moveCap12
    case bananaScoreDouble
    case specialsExplodeBigger
    case chocolateSpreadsFaster

    var title: String {
        switch self {
        case .noBoosters: return String(localized: "No boosters")
        case .moveCap12: return String(localized: "12 swaps")
        case .bananaScoreDouble: return String(localized: "Bananas x2")
        case .specialsExplodeBigger: return String(localized: "Bigger specials")
        case .chocolateSpreadsFaster: return String(localized: "Fast chocolate")
        }
    }

    var summary: String {
        switch self {
        case .noBoosters: return String(localized: "Boosters are locked for this level.")
        case .moveCap12: return String(localized: "Only 12 swaps are available.")
        case .bananaScoreDouble: return String(localized: "Banana clears score double.")
        case .specialsExplodeBigger: return String(localized: "Bombs and wrapped specials blast wider.")
        case .chocolateSpreadsFaster: return String(localized: "Chocolate spreads twice if ignored.")
        }
    }
}

struct LevelReward: Equatable {
    let title: String
    let coins: Int
    let lives: Int
    let shuffles: Int
    let hammers: Int
    let swaps: Int
    let themeName: String?

    init(title: String,
         coins: Int,
         lives: Int,
         shuffles: Int,
         hammers: Int,
         swaps: Int,
         themeName: String? = nil) {
        self.title = title
        self.coins = coins
        self.lives = lives
        self.shuffles = shuffles
        self.hammers = hammers
        self.swaps = swaps
        self.themeName = themeName
    }

    var summary: String {
        var parts: [String] = []
        if coins > 0 { parts.append("+\(coins) coins") }
        if lives > 0 { parts.append("+\(lives) lives") }
        if shuffles > 0 { parts.append("+\(shuffles) shuffles") }
        if hammers > 0 { parts.append("+\(hammers) hammers") }
        if swaps > 0 { parts.append("+\(swaps) swaps") }
        if let themeName { parts.append("Theme: \(themeName)") }
        return parts.joined(separator: "  ")
    }

    var isEmpty: Bool {
        coins == 0 && lives == 0 && shuffles == 0 && hammers == 0 && swaps == 0 && themeName == nil
    }
}

struct DailyChallenge {
    let dateKey: String
    let level: Int
    let reward: LevelReward
    /// Global challenge index (#1 = 2026-01-01). Shown in the share text.
    let number: Int
    /// Deterministic board seed derived from `dateKey` — every player in the
    /// world gets the identical board and refill stream for this challenge.
    let seed: UInt64
}

struct SugarEvent: Equatable {
    let id: String
    let title: String
    let subtitle: String
    let dateKey: String
    let level: Int
    let reward: LevelReward
}

struct LevelPortal: Equatable {
    let from: Pos
    let to: Pos
}

struct ConveyorBelt: Equatable {
    let row: Int
    /// Positive moves right, negative moves left.
    let direction: Int
}

// MARK: - Layout (board shape + starting blockers)

struct LevelLayout {
    /// Optional `[[Bool]]` mask. true = playable cell, false = hole. nil = full board.
    let mask: [[Bool]]?
    /// Random ice tiles seeded on playable cells at start.
    let iceCount: Int
    /// Random lock tiles seeded on playable cells at start.
    let lockCount: Int
    /// Jelly tiles require a match directly on top before the candy clears.
    let jellyCount: Int
    /// Sugar crates take three direct hits.
    let crateCount: Int
    /// Color locks show the required fruit and take one direct match to open.
    let colorLockCount: Int
    /// Treasure chests open from nearby matches or collected key tiles.
    let chestCount: Int
    /// Rope/vine blockers seeded in adjacent pairs where possible.
    let vineCount: Int
    /// Bomb tiles pre-placed before the player's first move.
    let startingBombs: Int
    /// Portal pairs swap their tiles after gravity settles.
    let portalPairs: [LevelPortal]
    /// Conveyor rows shift after gravity settles.
    let conveyorBelts: [ConveyorBelt]
    /// Chocolate spreader tiles. One spreads to a neighbor at end of turn
    /// unless the player damaged a chocolate that turn — adjacency keeps
    /// it in check.
    let chocolateCount: Int
    /// Fruit-basket ingredient tiles seeded near the top. They drop with
    /// gravity and are collected when they reach the bottom playable row.
    let ingredientCount: Int
    /// Key tiles seeded near the top. They drop like ingredients and open one
    /// chest when collected.
    let keyCount: Int
    /// Rising-syrup pressure mechanic. The syrup line starts at the bottom
    /// playable row and climbs one row every `syrupTickEvery` player moves,
    /// coating every playable tile on the new row with a one-hit syrup
    /// blocker. nil = no syrup on this level.
    let syrupTickEvery: Int?
    let countdownCount: Int

    init(mask: [[Bool]]?,
         iceCount: Int,
         lockCount: Int,
         jellyCount: Int,
         crateCount: Int,
         colorLockCount: Int,
         chestCount: Int = 0,
         vineCount: Int = 0,
         startingBombs: Int,
         portalPairs: [LevelPortal],
         conveyorBelts: [ConveyorBelt],
         chocolateCount: Int = 0,
         ingredientCount: Int = 0,
         keyCount: Int = 0,
         syrupTickEvery: Int? = nil,
         countdownCount: Int = 0) {
        self.mask = mask
        self.iceCount = iceCount
        self.lockCount = lockCount
        self.jellyCount = jellyCount
        self.crateCount = crateCount
        self.colorLockCount = colorLockCount
        self.chestCount = chestCount
        self.vineCount = vineCount
        self.startingBombs = startingBombs
        self.portalPairs = portalPairs
        self.conveyorBelts = conveyorBelts
        self.chocolateCount = chocolateCount
        self.ingredientCount = ingredientCount
        self.keyCount = keyCount
        self.syrupTickEvery = syrupTickEvery
        self.countdownCount = countdownCount
    }

    /// Returns a copy with countdown fuses added — used to sprinkle the fuse
    /// mechanic onto a sparse set of late levels without rebuilding their layout.
    func withCountdownFuses(_ count: Int) -> LevelLayout {
        LevelLayout(mask: mask, iceCount: iceCount, lockCount: lockCount,
                    jellyCount: jellyCount, crateCount: crateCount,
                    colorLockCount: colorLockCount, chestCount: chestCount,
                    vineCount: vineCount, startingBombs: startingBombs,
                    portalPairs: portalPairs, conveyorBelts: conveyorBelts,
                    chocolateCount: chocolateCount, ingredientCount: ingredientCount,
                    keyCount: keyCount, syrupTickEvery: syrupTickEvery,
                    countdownCount: count)
    }

    static let `default` = LevelLayout(mask: nil,
                                       iceCount: 0,
                                       lockCount: 0,
                                       jellyCount: 0,
                                       crateCount: 0,
                                       colorLockCount: 0,
                                       startingBombs: 0,
                                       portalPairs: [],
                                       conveyorBelts: [])

    var blockerCount: Int {
        iceCount + lockCount + jellyCount + crateCount + colorLockCount + chestCount + vineCount + chocolateCount + countdownCount
    }

    var mechanicSummary: String {
        var parts: [String] = []
        if blockerCount > 0 { parts.append("\(blockerCount) blockers") }
        if startingBombs > 0 { parts.append("\(startingBombs) bombs") }
        if !portalPairs.isEmpty { parts.append("\(portalPairs.count) portals") }
        if !conveyorBelts.isEmpty { parts.append("\(conveyorBelts.count) conveyors") }
        if chocolateCount > 0 { parts.append("\(chocolateCount) chocolate") }
        if ingredientCount > 0 { parts.append("\(ingredientCount) baskets") }
        if keyCount > 0 { parts.append("\(keyCount) keys") }
        if chestCount > 0 { parts.append("\(chestCount) chests") }
        if vineCount > 0 { parts.append("\(vineCount) vines") }
        if let interval = syrupTickEvery { parts.append("syrup/\(interval)") }
        if countdownCount > 0 { parts.append("\(countdownCount) fuses") }
        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }
}

// MARK: - Per-level config

struct LevelConfig {
    let number: Int
    let rows: Int
    let cols: Int
    let colors: Int
    let moves: Int
    let target: Int
    let archetype: LevelArchetype
    let difficulty: LevelDifficulty
    let skin: BoardSkin
    let layout: LevelLayout
    let goal: LevelGoal
    let starThresholds: (one: Int, two: Int, three: Int)
    /// Optional bomb threshold hint. Normal special creation still reserves bombs
    /// for huge 6+ runs so 4- and 5-matches can create striped/color-bomb tiles.
    let bombSpawnRunLength: Int?
    let blurb: String
    let modifiers: [LevelModifier]
    /// Boss levels cap each chapter — extra reward, dramatic banner, harder goal.
    /// Currently every multiple of 10 plus levels with the `.finale` archetype.
    let isBoss: Bool

    init(number: Int,
         rows: Int, cols: Int, colors: Int,
         moves: Int, target: Int,
         archetype: LevelArchetype,
         difficulty: LevelDifficulty,
         skin: BoardSkin,
         layout: LevelLayout,
         goal: LevelGoal,
         starThresholds: (one: Int, two: Int, three: Int),
         bombSpawnRunLength: Int?,
         blurb: String,
         modifiers: [LevelModifier] = [],
         isBoss: Bool = false) {
        self.number = number
        self.rows = rows
        self.cols = cols
        self.colors = colors
        self.moves = moves
        self.target = target
        self.archetype = archetype
        self.difficulty = difficulty
        self.skin = skin
        self.layout = layout
        self.goal = goal
        self.starThresholds = starThresholds
        self.bombSpawnRunLength = bombSpawnRunLength
        self.blurb = blurb
        self.modifiers = modifiers
        self.isBoss = isBoss
    }
}

// MARK: - Catalog

enum Levels {

    static let count = 200

    /// Sentinel "level" for the replayable Score Rush mode (outside 1...count).
    static let endlessLevel = 100_000

    /// A big, colourful, score-goal board reached from the map's Rush tab. Uses
    /// a sentinel number so the normal launch + end-of-level flow treats it as a
    /// one-off (no campaign progression, replays on finish for a higher score).
    static func endlessConfig() -> LevelConfig {
        LevelConfig(number: endlessLevel,
                    rows: 9, cols: 9, colors: 6,
                    moves: 35, target: 5_000,
                    archetype: .combo,
                    difficulty: .normal,
                    skin: .midnight,
                    layout: .default,
                    goal: .score,
                    starThresholds: (one: 5_000, two: 12_000, three: 22_000),
                    bombSpawnRunLength: 5,
                    blurb: String(localized: "Score Rush — one big board, chase a high score!"),
                    modifiers: [],
                    isBoss: false)
    }

    /// Sentinel for Sugar Tower floors. The config comes from the active
    /// tower run (floor + drafted perks), so the normal launch flow works
    /// unchanged — same trick as `endlessLevel`.
    static let towerLevel = 200_000

    static func towerConfig() -> LevelConfig {
        let run = TowerMode.activeRun()
            ?? TowerRun(weekKey: TowerMode.weekKey(), floor: 1, perks: [], coinsEarned: 0)
        return TowerMode.floorConfig(weekKey: run.weekKey,
                                     floor: run.floor,
                                     perks: run.perks)
    }

    static func config(for level: Int) -> LevelConfig {
        if level == endlessLevel { return endlessConfig() }
        if level == towerLevel { return towerConfig() }
        let n = max(1, min(level, count))
        switch n {
        case 1:  return mk(n, 5, 5, 3, 28,  1_100,  .starter,   .midnight,
                           layout(mask: nil),
                           "Three fruits, big tiles — find your rhythm.")
        case 2:  return mk(n, 6, 6, 3, 28,  1_700,  .starter,   .midnight,
                           layout(mask: nil),
                           "Same three fruits, a little more room.")
        case 3:  return mk(n, 6, 6, 4, 29,  2_300,  .starter,   .midnight,
                           layout(mask: nil),
                           "A new fruit joins the mix.")
        case 4:  return mk(n, 7, 7, 4, 30,  2_900,  .starter,   .midnight,
                           layout(mask: diamond7()),
                           "Diamond board — clean shape, four fruits.")
        case 5:  return mk(n, 7, 7, 4, 31, 3_300,  .ice,       .glacier,
                           layout(mask: octagon7(cut: 1), ice: 2),
                           "Frost forms — crack a few tiles.", goal: .score, bomb: 5)
        case 6:  return mk(n, 7, 7, 4, 31, 2_700,  .starter,   .glacier,
                           layout(mask: hourglass7()),
                           "Hourglass shape — five fruits now.",
                           goal: .collectColor(index: n % 4, count: 18))
        case 7:  return mk(n, 8, 8, 4, 32, 3_900,  .combo,     .glacier,
                           layout(mask: donut8()),
                           "Bigger canvas — match around the hole.")
        case 8:  return mk(n, 8, 8, 4, 32, 4_150,  .ice,       .glacier,
                           layout(mask: plus8(), ice: 3),
                           "Plus-shape & deep frost.")
        case 9:  return mk(n, 8, 8, 4, 31, 4_600,  .bombRush,  .sunset,
                           layout(mask: arrow8(), startingBombs: 2),
                           "Arrow board — bombs pre-loaded.", bomb: 4)
        case 10: return mk(n, 9, 9, 5, 33, 5_200,  .starter,   .sunset,
                           layout(mask: full9()),
                           "9×9 — bigger canvas.")
        case 11: return mk(n, 8, 8, 5, 33, 2600,  .combo,     .sunset,
                           layout(mask: stepUp8()),
                           "Step-up shape. Make one special.")
        case 12: return mk(n, 8, 8, 5, 33, 2900,  .lock,      .berry,
                           layout(mask: octagon8(cut: 2), lock: 3),
                           "Locked tiles need direct hits.")
        case 13: return mk(n, 9, 9, 5, 33, 3300,  .combo,     .berry,
                           layout(mask: crossMask9()),
                           "Cross-shape board — chain it.")
        case 14: return mk(n, 8, 8, 5, 32, 3300,  .bombRush,  .berry,
                           layout(mask: dumbbell8(), startingBombs: 2),
                           "Dumbbell board. Bombs ready.", bomb: 4)
        case 15: return mk(n, 9, 9, 5, 33, 3600, .crowded,   .citrine,
                           layout(mask: diamondMask9()),
                           "Five-fruit diamond. Crowded.",
                           goal: .collectColor(index: n % 5, count: 8))
        case 16: return mk(n, 8, 8, 5, 34, 3900, .ice,       .citrine,
                           layout(mask: octagon8(cut: 1), ice: 3, lock: 1),
                           "Ice + locks — the floor is slippery.")
        case 17: return mk(n, 9, 9, 5, 34, 4200, .combo,     .lagoon,
                           layout(mask: plusMask9()),
                           "Plus-shape combos required.")
        case 18: return mk(n, 8, 8, 5, 34, 4100, .crowded,   .lagoon,
                           layout(mask: tShape8(), ice: 2),
                           "T-shape. Crowded but relaxed.",
                           goal: .collectColor(index: n % 5, count: 8))
        case 19: return mk(n, 9, 9, 5, 34, 4600, .bombRush,  .mint,
                           layout(mask: plusMask9(), startingBombs: 2),
                           "Bomb storm. Detonate everything.", bomb: 4)
        case 20: return mk(n, 9, 9, 5, 36, 5200, .finale,    .sherbet,
                           layout(mask: hourglassMask9(), ice: 3, lock: 1, startingBombs: 1),
                           "The Sugar Crown awaits.", bomb: 5)

        // ── Act II — uncharted shapes, layered hazards.

        case 21: return mk(n, 9, 9, 5, 33, 6000, .starter,  .midnight,
                           layout(mask: ring9(), jelly: 3),
                           "Cooldown — match around the ring.")
        case 22: return mk(n, 8, 8, 5, 34, 6800, .ice,      .glacier,
                           layout(mask: heart8(), ice: 3),
                           "Frozen heart — thaw it out.", goal: .score, bomb: 5)
        case 23: return mk(n, 9, 9, 5, 34, 7400, .lock,     .berry,
                           layout(mask: crescent9(), lock: 4),
                           "Locked under the moon.", goal: .score)
        case 24: return mk(n, 8, 8, 5, 33, 8000, .bombRush, .sunset,
                           layout(mask: lightning8(), startingBombs: 2),
                           "Lightning fast — bombs ready.", bomb: 4)
        case 25: return mk(n, 9, 9, 5, 33, 8800, .combo,    .citrine,
                           layout(mask: star9()),
                           "Star of cascades — combo it.")

        case 26: return mk(n, 9, 9, 6, 20, 11500, .lock,     .lagoon,
                           layout(mask: crown9(), ice: 6, lock: 6),
                           "Crown of frost and locks.", bomb: 4)
        case 27: return mk(n, 9, 9, 5, 26, 9800, .starter,  .mint,
                           layout(mask: anchor9()),
                           "Anchor down and score.")
        case 28: return mk(n, 9, 9, 6, 18, 13800, .combo,    .berry,
                           layout(mask: ring9(), ice: 6),
                           "Loop the ring of ice.")
        case 29: return mk(n, 9, 9, 6, 20, 14500, .crowded,  .citrine,
                           layout(mask: flower9()),
                           "Six fruits in a flower — crowded.")
        case 30: return mk(n, 9, 9, 6, 20, 16000, .finale,   .sherbet,
                           layout(mask: diamondMask9(), ice: 6, lock: 4, startingBombs: 2),
                           "Treasure of gems — Act II finale.", bomb: 5)

        // ── Act III — the gauntlet.

        case 31: return mk(n, 9, 9, 6, 18, 17000, .ice,      .glacier,
                           layout(mask: crescent9(), ice: 10, startingBombs: 1),
                           "Frosted moon, sparked fuse.", bomb: 5)
        case 32: return mk(n, 8, 8, 6, 16, 17800, .bombRush, .sunset,
                           layout(mask: lightning8(), startingBombs: 4),
                           "Twin lightning — chain the booms.", bomb: 4)
        case 33: return mk(n, 9, 9, 6, 18, 18800, .ice,      .lagoon,
                           layout(mask: crown9(), ice: 12),
                           "The frosted crown.")
        case 34: return mk(n, 9, 9, 6, 20, 19800, .lock,     .berry,
                           layout(mask: anchor9(), lock: 10),
                           "Anchor in chains.")
        case 35: return mk(n, 8, 8, 6, 18, 21000, .ice,      .glacier,
                           layout(mask: heart8(), ice: 14, lock: 4),
                           "Frozen heart, locked away.")

        case 36: return mk(n, 9, 9, 6, 18, 22000, .bombRush, .citrine,
                           layout(mask: star9(), ice: 6, startingBombs: 3),
                           "A star explodes.", bomb: 4)
        case 37: return mk(n, 9, 9, 6, 16, 23000, .bombRush, .sunset,
                           layout(mask: ring9(), startingBombs: 4),
                           "Ring of fire — bombs in.", bomb: 4)
        case 38: return mk(n, 8, 8, 6, 14, 23800, .ice,      .glacier,
                           layout(mask: donut8(), ice: 12, lock: 4),
                           "Donut of ice.", bomb: 5)
        case 39: return mk(n, 9, 9, 6, 16, 24800, .lock,     .berry,
                           layout(mask: crossMask9(), lock: 12),
                           "Crossroads of locks.")
        case 40: return mk(n, 8, 8, 6, 14, 26000, .finale,   .midnight,
                           layout(mask: heart8(), ice: 8, lock: 6, startingBombs: 3),
                           "Mid-boss: cracked heart.", bomb: 4)

        // ── Act IV — final approach.

        case 41: return mk(n, 9, 9, 6, 18, 27000, .ice,      .glacier,
                           layout(mask: star9(), ice: 14),
                           "Astral cold.")
        case 42: return mk(n, 9, 9, 6, 18, 28000, .crowded,  .citrine,
                           layout(mask: diamondMask9()),
                           "Crowded gemstone.")
        case 43: return mk(n, 9, 9, 6, 16, 29200, .bombRush, .sunset,
                           layout(mask: flower9(), startingBombs: 4),
                           "Flower festival — boom!", bomb: 4)
        case 44: return mk(n, 9, 9, 6, 16, 30400, .lock,     .berry,
                           layout(mask: crescent9(), ice: 4, lock: 10),
                           "Crescent rising tide.", bomb: 5)
        case 45: return mk(n, 8, 8, 6, 14, 31600, .bombRush, .sunset,
                           layout(mask: lightning8(), ice: 6, startingBombs: 5),
                           "Lightning storm — minimum moves.", bomb: 3)

        case 46: return mk(n, 9, 9, 6, 16, 32800, .bombRush, .lagoon,
                           layout(mask: crown9(), startingBombs: 5),
                           "Crown of chaos.", bomb: 4)
        case 47: return mk(n, 9, 9, 6, 18, 34000, .ice,      .glacier,
                           layout(mask: anchor9(), ice: 16),
                           "Frozen anchor.")
        case 48: return mk(n, 9, 9, 6, 18, 35200, .lock,     .midnight,
                           layout(mask: ring9(), lock: 12, startingBombs: 1),
                           "Ring fortress.", bomb: 5)
        case 49: return mk(n, 8, 8, 6, 14, 36500, .finale,  .berry,
                           layout(mask: heart8(), ice: 14, lock: 8, startingBombs: 3),
                           "Heart of darkness.", bomb: 4)
        case 50: return mk(n, 9, 9, 6, 18, 40000, .finale,  .sherbet,
                           layout(mask: crown9(), ice: 12, lock: 8, startingBombs: 4),
                           "The Ultimate Crown.", bomb: 4)

        case 51...100:
            return generatedActConfig(n)
        case 101...200:
            return generatedCrownActConfig(n)

        default: return mk(1, 8, 8, 5, 25, 2000, .starter, .midnight,
                           layout(mask: full8()), "")
        }
    }

    private static func generatedActConfig(_ n: Int) -> LevelConfig {
        let index = n - 51
        let shape = generatedShape(for: index % 16)

        let archetypes: [LevelArchetype] = [.ice, .lock, .bombRush, .combo, .crowded, .finale]
        let skins: [BoardSkin] = [.glacier, .berry, .sunset, .lagoon, .citrine, .mint, .sherbet, .midnight]
        let archetype = archetypes[index % archetypes.count]
        let target = 42_000 + index * 850 + (index / 10) * 2_500
        let moves = max(18, 22 - (index / 18))
        let ice = (archetype == .ice || archetype == .finale) ? min(16, 7 + index / 7) : (index % 4 == 0 ? 5 : 0)
        let lock = (archetype == .lock || archetype == .finale) ? min(12, 5 + index / 8) : (index % 5 == 0 ? 4 : 0)
        let bombs = (archetype == .bombRush || archetype == .finale) ? min(6, 3 + index / 18) : (index % 7 == 0 ? 1 : 0)
        let bombRun = archetype == .bombRush ? 4 : 5

        return mk(n, shape.rows, shape.cols, 6, moves, target, archetype, skins[index % skins.count],
                  layout(mask: shape.mask, ice: ice, lock: lock, startingBombs: bombs),
                  "Master \(shape.name) board - level \(n).",
                  bomb: bombRun)
    }

    private static func generatedCrownActConfig(_ n: Int) -> LevelConfig {
        let index = n - 101
        let band = min(3, index / 25)
        let shape = generatedShape(for: (index * 5 + 3 + band) % 16)
        let archetypes: [LevelArchetype] = [.combo, .ice, .lock, .bombRush, .crowded, .finale]
        let skins: [BoardSkin] = [.sherbet, .midnight, .mint, .glacier, .berry, .sunset, .lagoon, .citrine]
        let isMilestone = n % 25 == 0
        let archetype = isMilestone ? .finale : archetypes[(index + band) % archetypes.count]

        let baseTarget = 32_000 + index * 420 + (index / 10) * 1_800
        let target = baseTarget + (isMilestone ? 9_000 + band * 4_000 : 0)
        let baseMoves = max(19, 23 - index / 32)
        let moves = baseMoves + (isMilestone ? 2 : 0)

        var ice = 0
        var lock = 0
        var bombs = 0
        switch archetype {
        case .starter:
            break
        case .combo:
            ice = index % 9 == 0 ? 4 + band : 0
            bombs = index % 6 == 0 ? 2 : 0
        case .ice:
            ice = min(18, 8 + band * 2 + index / 18)
            lock = index % 4 == 0 ? 3 + band : 0
            bombs = index % 7 == 0 ? 1 : 0
        case .lock:
            ice = index % 3 == 0 ? 4 + band : 0
            lock = min(14, 6 + band * 2 + index / 20)
            bombs = index % 8 == 0 ? 1 : 0
        case .crowded:
            ice = index % 2 == 0 ? 4 + band : 0
            lock = index % 5 == 0 ? 4 + band : 0
            bombs = index % 6 == 0 ? 1 : 0
        case .bombRush:
            ice = index % 2 == 0 ? 3 + band : 0
            lock = index % 5 == 0 ? 3 + band : 0
            bombs = min(7, 3 + band + index / 35)
        case .finale:
            ice = min(18, 10 + band * 2 + index / 25)
            lock = min(14, 7 + band * 2 + index / 28)
            bombs = min(7, 4 + band)
        }

        let hazards = fittedHazards(ice: ice,
                                    lock: lock,
                                    bombs: bombs,
                                    playable: playableCells(in: shape.mask))
        let chapter = ["Crown ascent", "Royal mixers", "Vault breakers", "Sugar throne"][band]
        let blurb = isMilestone
            ? "\(chapter): \(shape.name) trial - claim the crown."
            : "\(chapter): \(shape.name) board - level \(n)."

        return mk(n, shape.rows, shape.cols, 6, moves, target, archetype, skins[(index + band) % skins.count],
                  layout(mask: shape.mask,
                         ice: hazards.ice,
                         lock: hazards.lock,
                         startingBombs: hazards.bombs),
                  blurb,
                  bomb: archetype == .bombRush ? 4 : 5)
    }

    private struct GeneratedShape {
        let rows: Int
        let cols: Int
        let mask: [[Bool]]
        let name: String
    }

    private static func generatedShape(for shape: Int) -> GeneratedShape {
        switch shape {
        case 0:
            return GeneratedShape(rows: 9, cols: 9, mask: ring9(), name: "ring")
        case 1:
            return GeneratedShape(rows: 8, cols: 8, mask: lightning8(), name: "lightning")
        case 2:
            return GeneratedShape(rows: 9, cols: 9, mask: crown9(), name: "crown")
        case 3:
            return GeneratedShape(rows: 8, cols: 8, mask: heart8(), name: "heart")
        case 4:
            return GeneratedShape(rows: 9, cols: 9, mask: crescent9(), name: "crescent")
        case 5:
            return GeneratedShape(rows: 9, cols: 9, mask: flower9(), name: "flower")
        case 6:
            return GeneratedShape(rows: 8, cols: 8, mask: donut8(), name: "donut")
        case 7:
            return GeneratedShape(rows: 9, cols: 9, mask: anchor9(), name: "anchor")
        case 8:
            return GeneratedShape(rows: 9, cols: 9, mask: star9(), name: "star")
        case 9:
            return GeneratedShape(rows: 9, cols: 9, mask: crossMask9(), name: "cross")
        case 10:
            return GeneratedShape(rows: 8, cols: 8, mask: dumbbell8(), name: "dumbbell")
        case 11:
            return GeneratedShape(rows: 9, cols: 9, mask: diamondMask9(), name: "diamond")
        case 12:
            return GeneratedShape(rows: 8, cols: 8, mask: tShape8(), name: "T-shape")
        case 13:
            return GeneratedShape(rows: 9, cols: 9, mask: plusMask9(), name: "plus")
        case 14:
            return GeneratedShape(rows: 8, cols: 8, mask: stepUp8(), name: "stair")
        default:
            return GeneratedShape(rows: 9, cols: 9, mask: hourglassMask9(), name: "hourglass")
        }
    }

    private static func playableCells(in mask: [[Bool]]) -> Int {
        mask.flatMap { $0 }.filter { $0 }.count
    }

    private static func fittedHazards(ice: Int,
                                      lock: Int,
                                      bombs: Int,
                                      playable: Int) -> (ice: Int, lock: Int, bombs: Int) {
        var fittedIce = max(0, ice)
        var fittedLock = max(0, lock)
        var fittedBombs = min(max(0, bombs), max(0, playable / 6))
        let maxSeeded = max(0, playable - 12)

        while fittedIce + fittedLock + fittedBombs > maxSeeded {
            if fittedIce >= fittedLock, fittedIce > 0 {
                fittedIce -= 1
            } else if fittedLock > 0 {
                fittedLock -= 1
            } else if fittedBombs > 0 {
                fittedBombs -= 1
            } else {
                break
            }
        }

        return (fittedIce, fittedLock, fittedBombs)
    }

    private static func layout(mask: [[Bool]]?,
                               ice: Int = 0,
                               lock: Int = 0,
                               jelly: Int = 0,
                               crates: Int = 0,
                               colorLocks: Int = 0,
                               chests: Int = 0,
                               vines: Int = 0,
                               startingBombs: Int = 0,
                               portals: [LevelPortal] = [],
                               conveyors: [ConveyorBelt] = [],
                               chocolate: Int = 0,
                               ingredients: Int = 0,
                               keys: Int = 0) -> LevelLayout {
        LevelLayout(mask: mask,
                    iceCount: ice,
                    lockCount: lock,
                    jellyCount: jelly,
                    crateCount: crates,
                    colorLockCount: colorLocks,
                    chestCount: chests,
                    vineCount: vines,
                    startingBombs: startingBombs,
                    portalPairs: portals,
                    conveyorBelts: conveyors,
                    chocolateCount: chocolate,
                    ingredientCount: ingredients,
                    keyCount: keys)
    }

    private static func decoratedLayout(_ base: LevelLayout,
                                        forLevel n: Int,
                                        rows: Int,
                                        cols: Int,
                                        archetype: LevelArchetype) -> LevelLayout {
        guard n > 20 || n.isMultiple(of: 10) else { return base }

        var jelly = base.jellyCount
        var crates = base.crateCount
        var colorLocks = base.colorLockCount
        var chests = base.chestCount
        var vines = base.vineCount
        var keys = base.keyCount
        var chocolate = base.chocolateCount
        var ingredients = base.ingredientCount
        var portals = base.portalPairs
        var conveyors = base.conveyorBelts

        switch n {
        case ...20:
            break
        case 21...35:
            if n.isMultiple(of: 2) || archetype == .ice {
                jelly += min(8, 3 + n / 10)
            }
        case 36...60:
            jelly += n.isMultiple(of: 3) ? 5 : 0
            crates += n.isMultiple(of: 2) ? min(6, 2 + n / 18) : 0
        case 61...100:
            jelly += n.isMultiple(of: 4) ? 6 : 0
            crates += n.isMultiple(of: 3) ? min(8, 3 + n / 20) : 0
            colorLocks += n.isMultiple(of: 5) ? min(6, 2 + n / 30) : 0
        default:
            jelly += n.isMultiple(of: 5) ? 6 : 0
            crates += n.isMultiple(of: 4) ? min(9, 4 + n / 40) : 0
            colorLocks += n.isMultiple(of: 3) ? min(8, 3 + n / 35) : 0
        }

        if n >= 30, n.isMultiple(of: 8) {
            chests += min(3, 1 + n / 90)
        }
        if n >= 35, n.isMultiple(of: 11), archetype != .bombRush {
            keys += min(3, 1 + n / 110)
        }
        if n >= 40, n.isMultiple(of: 7) {
            vines += min(6, 2 + n / 70)
        }
        if n.isMultiple(of: 10) {
            chests += n >= 10 ? 1 : 0
            vines += n >= 20 ? min(4, 1 + n / 50) : 0
            if n >= 30 { keys += 1 }
            if n >= 80 { chocolate = max(chocolate, 1) }
        }

        if n >= 51, n.isMultiple(of: 7), portals.isEmpty,
           let pair = defaultPortalPair(rows: rows, cols: cols, mask: base.mask) {
            portals = [pair]
        }

        if n >= 76, n.isMultiple(of: 6), conveyors.isEmpty,
           let belt = defaultConveyor(rows: rows, cols: cols, mask: base.mask, level: n) {
            conveyors = [belt]
        }

        // Late-act chocolate seeding: spice up chapters 6+ where the player
        // already knows the basic blockers. Tied to a deterministic mod so the
        // catalog stays predictable.
        if n >= 80, n.isMultiple(of: 9) {
            chocolate = max(chocolate, min(5, 2 + n / 50))
        }
        // Mid-act ingredient drops give players a fresh goal type ~once per
        // chapter. Skip on bomb-rush levels so the goal types don't conflict.
        if n >= 65, n.isMultiple(of: 11), archetype != .bombRush {
            ingredients = max(ingredients, min(4, 2 + n / 80))
        }

        let playable = playableCells(rows: rows, cols: cols, mask: base.mask)
        let maxSeeded = max(0, playable - 12)
        var totalSeeded = base.iceCount + base.lockCount + base.startingBombs + jelly + crates + colorLocks + chests + vines + chocolate + keys + ingredients
        while totalSeeded > maxSeeded {
            if crates > 0 { crates -= 1 }
            else if colorLocks > 0 { colorLocks -= 1 }
            else if vines > 0 { vines -= 1 }
            else if chests > 0 { chests -= 1 }
            else if chocolate > 0 { chocolate -= 1 }
            else if jelly > 0 { jelly -= 1 }
            else if keys > 0 { keys -= 1 }
            else if ingredients > 0 { ingredients -= 1 }
            else { break }
            totalSeeded = base.iceCount + base.lockCount + base.startingBombs + jelly + crates + colorLocks + chests + vines + chocolate + keys + ingredients
        }

        // Syrup pressure: a climbing wave that coats one row of tiles every N
        // moves. Late-campaign only (>= 75) and rare enough to feel special.
        // Tick rate shortens for harder levels and crown act for sharper
        // pressure curves.
        let syrupTickEvery: Int? = {
            guard base.syrupTickEvery == nil else { return base.syrupTickEvery }
            guard n >= 75, n.isMultiple(of: 13) else { return nil }
            guard archetype != .bombRush, ingredients == 0 else { return nil }
            return n >= 150 ? 4 : 5
        }()

        return LevelLayout(mask: base.mask,
                           iceCount: base.iceCount,
                           lockCount: base.lockCount,
                           jellyCount: max(0, jelly),
                           crateCount: max(0, crates),
                           colorLockCount: max(0, colorLocks),
                           chestCount: max(0, chests),
                           vineCount: max(0, vines),
                           startingBombs: base.startingBombs,
                           portalPairs: portals,
                           conveyorBelts: conveyors,
                           chocolateCount: chocolate,
                           ingredientCount: ingredients,
                           keyCount: keys,
                           syrupTickEvery: syrupTickEvery)
    }

    private static func defaultPortalPair(rows: Int,
                                          cols: Int,
                                          mask: [[Bool]]?) -> LevelPortal? {
        let positions = playablePositions(rows: rows, cols: cols, mask: mask)
        guard positions.count >= 18 else { return nil }
        let upper = positions.first { $0.r <= max(1, rows / 3) }
        let lower = positions.reversed().first { $0.r >= min(rows - 2, rows * 2 / 3) }
        guard let upper, let lower, upper != lower else { return nil }
        return LevelPortal(from: upper, to: lower)
    }

    private static func defaultConveyor(rows: Int,
                                        cols: Int,
                                        mask: [[Bool]]?,
                                        level: Int) -> ConveyorBelt? {
        let candidates = [rows / 2, max(0, rows / 2 - 1), min(rows - 1, rows / 2 + 1)]
        for row in candidates {
            let playable = (0..<cols).filter { c in mask?[row][c] ?? true }
            if playable.count >= 4 {
                return ConveyorBelt(row: row, direction: level.isMultiple(of: 12) ? -1 : 1)
            }
        }
        return nil
    }

    private static func playablePositions(rows: Int, cols: Int, mask: [[Bool]]?) -> [Pos] {
        var positions: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where mask?[r][c] ?? true {
                positions.append(Pos(r: r, c: c))
            }
        }
        return positions
    }

    private static func playableCells(rows: Int, cols: Int, mask: [[Bool]]?) -> Int {
        playablePositions(rows: rows, cols: cols, mask: mask).count
    }

    private static func difficulty(for n: Int,
                                   archetype: LevelArchetype,
                                   moves: Int,
                                   layout: LevelLayout) -> LevelDifficulty {
        if n >= 100, n.isMultiple(of: 25) || n >= 175 {
            return .crownChallenge
        }

        var pressure = 0
        pressure += layout.blockerCount / 4
        pressure += layout.startingBombs
        pressure += layout.portalPairs.count * 2
        pressure += layout.conveyorBelts.count * 2
        if moves <= 16 { pressure += 2 }
        if archetype == .finale { pressure += 3 }
        if archetype == .bombRush { pressure += 1 }

        if pressure >= 9 { return .superHard }
        if pressure >= 5 || n.isMultiple(of: 10) { return .hard }
        return .normal
    }

    private static func modifiers(for n: Int,
                                  archetype: LevelArchetype,
                                  layout: LevelLayout) -> [LevelModifier] {
        guard n >= 26 else { return [] }
        var rules: [LevelModifier] = []
        if n.isMultiple(of: 17) {
            rules.append(.noBoosters)
        }
        if n >= 45, n.isMultiple(of: 19) {
            rules.append(.moveCap12)
        }
        if n.isMultiple(of: 14) {
            rules.append(.bananaScoreDouble)
        }
        if archetype == .combo || n.isMultiple(of: 16) {
            rules.append(.specialsExplodeBigger)
        }
        if layout.chocolateCount > 0 && (n.isMultiple(of: 9) || n.isMultiple(of: 10)) {
            rules.append(.chocolateSpreadsFaster)
        }
        return Array(rules.prefix(2))
    }

    private static func mk(_ n: Int,
                           _ rows: Int, _ cols: Int,
                           _ colors: Int, _ moves: Int, _ target: Int,
                           _ archetype: LevelArchetype,
                           _ skin: BoardSkin,
                           _ layoutValue: LevelLayout,
                           _ blurb: String,
                           goal: LevelGoal? = nil,
                           bomb: Int? = 5) -> LevelConfig {
        let baseLayout = decoratedLayout(layoutValue,
                                         forLevel: n,
                                         rows: rows,
                                         cols: cols,
                                         archetype: archetype)
        // Sprinkle the countdown-fuse mechanic onto a sparse set of late,
        // non-boss levels for variety (kept rare like syrup).
        let layout = (n >= 96 && n % 17 == 0 && !n.isMultiple(of: 10))
            ? baseLayout.withCountdownFuses(2)
            : baseLayout
        var levelGoal = goal ?? defaultGoal(for: n,
                                            archetype: archetype,
                                            layout: layout,
                                            colors: colors)
        let modifiers = modifiers(for: n, archetype: archetype, layout: layout)
        let effectiveMoves = modifiers.contains(.moveCap12) ? min(moves, 12) : moves
        if modifiers.contains(.moveCap12) {
            switch levelGoal {
            case .createSpecials(let count):
                levelGoal = .createSpecials(count: min(count, max(2, effectiveMoves / 4)))
            case .detonateBombs(let count):
                levelGoal = .detonateBombs(count: min(count, max(1, effectiveMoves / 6)))
            default:
                break
            }
        }
        let difficulty = difficulty(for: n,
                                    archetype: archetype,
                                    moves: effectiveMoves,
                                    layout: layout)
        let tunedTarget = balancedTarget(raw: target,
                                         level: n,
                                         rows: rows,
                                         cols: cols,
                                         colors: colors,
                                         moves: effectiveMoves,
                                         archetype: archetype,
                                         difficulty: difficulty,
                                         layout: layout,
                                         goal: levelGoal)
        let stars = starThresholds(forLevel: n, target: tunedTarget)
        let isBoss = archetype == .finale || n.isMultiple(of: 10)
        return LevelConfig(number: n,
                           rows: rows, cols: cols, colors: colors,
                           moves: effectiveMoves, target: tunedTarget,
                           archetype: archetype,
                           difficulty: difficulty,
                           skin: skin,
                           layout: layout,
                           goal: levelGoal,
                           starThresholds: stars,
                           bombSpawnRunLength: bomb,
                           blurb: blurb,
                           modifiers: modifiers,
                           isBoss: isBoss)
    }

    private static func balancedTarget(raw: Int,
                                       level n: Int,
                                       rows: Int,
                                       cols: Int,
                                       colors: Int,
                                       moves: Int,
                                       archetype: LevelArchetype,
                                       difficulty: LevelDifficulty,
                                       layout: LevelLayout,
                                       goal: LevelGoal) -> Int {
        guard n > 10 else { return raw }

        let playable = playableCells(rows: rows, cols: cols, mask: layout.mask)
        let full = max(1, rows * cols)
        let shapeRatio = Double(playable) / Double(full)
        let shapeFactor = min(1.0, max(0.78, 0.72 + shapeRatio * 0.28))
        let colorFactor = colors >= 6 ? 0.90 : 1.0

        let basePerMove: Double
        switch n {
        case 11...25:
            basePerMove = 220
        case 26...50:
            basePerMove = 230
        case 51...100:
            basePerMove = 250
        case 101...150:
            // Eased slightly (was 270): the simulated balance pass showed the
            // late campaign skewing hard even for an objective-aware bot.
            basePerMove = 260
        default:
            basePerMove = 275
        }

        let difficultyFactor: Double
        switch difficulty {
        case .normal:
            difficultyFactor = 1.00
        case .hard:
            difficultyFactor = 1.10
        case .superHard:
            difficultyFactor = 1.22
        case .crownChallenge:
            difficultyFactor = 1.28
        }

        let archetypeFactor: Double
        switch archetype {
        case .starter:
            archetypeFactor = 1.00
        case .combo:
            archetypeFactor = 1.08
        case .bombRush:
            archetypeFactor = 1.12
        case .crowded:
            archetypeFactor = 0.96
        case .ice, .lock:
            archetypeFactor = 0.92
        case .finale:
            archetypeFactor = 1.16
        }

        let goalFactor: Double
        switch goal {
        case .score:
            goalFactor = 1.00
        case .clearBlockers, .collectIngredients, .collectKeys, .openChests, .collectIngredientsAndKeys:
            goalFactor = 0.92
        case .collectColor:
            goalFactor = 0.95
        case .createSpecials, .detonateBombs:
            goalFactor = 1.04
        }

        let bombBonus = Double(layout.startingBombs) * 220
        let movementBonus = Double(layout.portalPairs.count + layout.conveyorBelts.count) * 120
        let rawBudget = Double(moves) * basePerMove * difficultyFactor * archetypeFactor * goalFactor * shapeFactor * colorFactor
        let capped = Int(((rawBudget + bombBonus + movementBonus) / 50.0).rounded()) * 50
        let floor = max(300, Int(((Double(moves) * 115) / 50.0).rounded()) * 50)
        return min(raw, max(floor, capped))
    }

    /// Bonus reward granted on a boss-level clear, in addition to whatever
    /// chapter milestone rewards already exist. Doubles the standard star
    /// reward and grants a one-time booster.
    static func bossReward(for level: Int) -> LevelReward? {
        let cfg = config(for: level)
        guard cfg.isBoss else { return nil }
        let coins = 60 + (level / 10) * 30
        return LevelReward(title: String(localized: "Boss bonus"),
                           coins: coins,
                           lives: level >= 100 ? 1 : 0,
                           shuffles: 1,
                           hammers: level >= 50 ? 1 : 0,
                           swaps: level >= 100 ? 1 : 0)
    }

    private static func defaultGoal(for n: Int,
                                    archetype: LevelArchetype,
                                    layout: LevelLayout,
                                    colors: Int) -> LevelGoal {
        if n <= 3 { return .score }

        // When the level seeds drop items, the dominant goal is to collect them.
        if layout.ingredientCount > 0, layout.keyCount > 0, n.isMultiple(of: 10) || n.isMultiple(of: 15) {
            return .collectIngredientsAndKeys(ingredients: layout.ingredientCount, keys: layout.keyCount)
        }
        if layout.ingredientCount > 0 {
            return .collectIngredients(count: layout.ingredientCount)
        }
        if layout.keyCount > 0, layout.chestCount > 0, n.isMultiple(of: 10) {
            return .openChests(count: max(1, min(layout.chestCount, layout.keyCount + 1)))
        }
        if layout.keyCount > 0 {
            return .collectKeys(count: layout.keyCount)
        }
        if layout.chestCount > 0, n.isMultiple(of: 8) || n.isMultiple(of: 10) {
            return .openChests(count: layout.chestCount)
        }
        switch archetype {
        case .starter:
            if n % 6 == 0 {
                return .collectColor(index: n % max(1, colors),
                                     count: n <= 20 ? 7 + n / 4 : 18 + n / 12)
            }
            return .score
        case .combo:
            return .createSpecials(count: n <= 20 ? 1 : min(5, 2 + n / 50))
        case .ice, .lock:
            if layout.blockerCount > 0 {
                return .clearBlockers
            }
            return .collectColor(index: n % max(1, colors),
                                 count: n <= 20 ? 9 : 22 + n / 18)
        case .crowded:
            return .collectColor(index: n % max(1, colors),
                                 count: n <= 20 ? 8 + n / 5 : 24 + n / 16)
        case .bombRush:
            return .detonateBombs(count: n <= 20 ? 1 : max(1, min(3, layout.startingBombs)))
        case .finale:
            if layout.blockerCount > 0 {
                return .clearBlockers
            }
            return .detonateBombs(count: max(1, min(4, layout.startingBombs)))
        }
    }

    private static func starThresholds(forLevel n: Int,
                                       target: Int) -> (one: Int, two: Int, three: Int) {
        let multipliers: (two: Double, three: Double)
        switch n {
        case 1...10:
            multipliers = (1.10, 1.25)
        case 11...25:
            multipliers = (1.12, 1.30)
        case 26...100:
            multipliers = (1.15, 1.35)
        default:
            multipliers = (1.12, 1.32)
        }

        return (target,
                Int((Double(target) * multipliers.two).rounded()),
                Int((Double(target) * multipliers.three).rounded()))
    }

    static func chapter(for level: Int) -> LevelChapter {
        let n = max(1, min(level, count))
        let chapters: [LevelChapter] = [
            LevelChapter(title: String(localized: "Sweet Start"), subtitle: String(localized: "Learn matches, specials, and gentle shapes."), range: 1...25),
            LevelChapter(title: String(localized: "Frost Valley"), subtitle: String(localized: "Ice, locks, and tighter boards arrive."), range: 26...50),
            LevelChapter(title: String(localized: "Bomb Bakery"), subtitle: String(localized: "Bomb chains and odd shapes ask for planning."), range: 51...75),
            LevelChapter(title: String(localized: "Crown Gate"), subtitle: String(localized: "Classic campaign finales before the royal climb."), range: 76...100),
            LevelChapter(title: String(localized: "Royal Rush"), subtitle: String(localized: "Crowned boards remix hazards with bigger scores."), range: 101...150),
            LevelChapter(title: String(localized: "Sugar Throne"), subtitle: String(localized: "The final climb to level 200."), range: 151...200)
        ]
        return chapters.first { $0.range.contains(n) } ?? chapters[0]
    }

    static func milestoneReward(for level: Int) -> LevelReward? {
        guard level > 0 else { return nil }
        if level == 200 {
            return LevelReward(title: String(localized: "Sugar Throne cleared"),
                               coins: 2_000, lives: 3, shuffles: 5, hammers: 5, swaps: 5,
                               themeName: "Sugar Throne")
        }
        if level == 100 {
            return LevelReward(title: String(localized: "Crown unlocked"),
                               coins: 1_000, lives: 2, shuffles: 3, hammers: 3, swaps: 3,
                               themeName: "Crown Gate")
        }
        if level.isMultiple(of: 10) {
            let theme: String? = level.isMultiple(of: 50) ? chapter(for: level).title : nil
            return LevelReward(title: String(localized: "Booster bundle"),
                               coins: 250, lives: 1, shuffles: 2, hammers: 1, swaps: 1,
                               themeName: theme)
        }
        if level.isMultiple(of: 5) {
            return LevelReward(title: String(localized: "Milestone coins"),
                               coins: 120, lives: 0, shuffles: 0, hammers: 0, swaps: 0)
        }
        return nil
    }

    static func threeStarReward(for level: Int) -> LevelReward? {
        guard level > 0 else { return nil }
        let coinBonus = min(180, 35 + level)
        let hammerBonus = level.isMultiple(of: 25) ? 1 : 0
        let swapBonus = level.isMultiple(of: 40) ? 1 : 0
        return LevelReward(title: String(localized: "Perfect clear"),
                           coins: coinBonus,
                           lives: 0,
                           shuffles: level.isMultiple(of: 15) ? 1 : 0,
                           hammers: hammerBonus,
                           swaps: swapBonus)
    }

    /// The day the global daily challenge counter starts: #1 = 2026-01-01.
    private static let dailyEpoch = DateComponents(year: 2026, month: 1, day: 1)

    static func dailyChallenge(on date: Date = Date()) -> DailyChallenge {
        // Fixed Gregorian calendar (local timezone) so every device picks the
        // same level and seed regardless of the user's calendar preference.
        // The day rolls at local midnight, Wordle-style.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let start = calendar.startOfDay(for: date)
        let day = calendar.ordinality(of: .day, in: .era, for: start) ?? 1
        let level = 1 + ((day * 37) % count)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        // POSIX locale keeps the digits Western Arabic everywhere — the key
        // feeds the shared board seed, so it must be byte-identical worldwide.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: start)
        let epochStart = calendar.date(from: dailyEpoch).map { calendar.startOfDay(for: $0) } ?? start
        let number = max(1, (calendar.dateComponents([.day], from: epochStart, to: start).day ?? 0) + 1)
        let reward = LevelReward(title: String(localized: "Daily clear"),
                                 coins: 180, lives: 0, shuffles: 1, hammers: 1, swaps: 1)
        return DailyChallenge(dateKey: key,
                              level: level,
                              reward: reward,
                              number: number,
                              seed: LevelSeed.dailySeed(dateKey: key, level: level))
    }

    static func dailyStreakReward(streak: Int) -> LevelReward? {
        guard streak >= 3 else { return nil }
        return LevelReward(title: "\(streak)-day streak",
                           coins: min(500, 75 + streak * 20),
                           lives: streak.isMultiple(of: 7) ? 1 : 0,
                           shuffles: 1,
                           hammers: streak.isMultiple(of: 5) ? 1 : 0,
                           swaps: 0)
    }

    static func tomorrowDailyRewardPreview(on date: Date = Date()) -> LevelReward {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        let challenge = dailyChallenge(on: tomorrow)
        if let streak = dailyStreakReward(streak: max(2, Persistence.dailyStreak + 1)) {
            return LevelReward(title: String(localized: "Tomorrow streak"),
                               coins: challenge.reward.coins + streak.coins,
                               lives: challenge.reward.lives + streak.lives,
                               shuffles: challenge.reward.shuffles + streak.shuffles,
                               hammers: challenge.reward.hammers + streak.hammers,
                               swaps: challenge.reward.swaps + streak.swaps)
        }
        return challenge.reward
    }

    static func mechanicUnlock(for level: Int) -> String? {
        switch level {
        case 4: return String(localized: "Striped specials")
        case 5: return String(localized: "Frost blockers")
        case 7: return String(localized: "Color bombs")
        case 11: return String(localized: "Wrapped specials")
        case 13: return String(localized: "Fish specials")
        case 16: return String(localized: "Player Smash meter")
        case 21: return String(localized: "Jelly tiles")
        case 36: return String(localized: "Sugar crates")
        case 51: return String(localized: "Portals")
        case 61: return String(localized: "Color locks")
        case 70: return String(localized: "Chests and keys")
        case 76: return String(localized: "Conveyors")
        case 84: return String(localized: "Vine blockers")
        case 90: return String(localized: "Level modifiers")
        case 100: return String(localized: "Crown levels")
        default: return nil
        }
    }

    static func activeEvents(on date: Date = Date()) -> [SugarEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let day = calendar.ordinality(of: .day, in: .era, for: start) ?? 1
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: start)
        let weekday = calendar.component(.weekday, from: start)
        let isWeekend = weekday == 1 || weekday == 7

        let crownLevel = 100 + ((day * 17) % 101)
        let sprintLevel = 1 + ((day * 19) % 80)
        let bombLevel = 51 + ((day * 23) % 90)

        if isWeekend {
            return [
                SugarEvent(id: "crown-rush-\(key)",
                           title: String(localized: "Crown Rush"),
                           subtitle: String(localized: "Clear a crown-era level for a larger bundle."),
                           dateKey: key,
                           level: min(count, crownLevel),
                           reward: LevelReward(title: String(localized: "Crown Rush chest"),
                                               coins: 360, lives: 1, shuffles: 1, hammers: 2, swaps: 1)),
                SugarEvent(id: "bomb-bonanza-\(key)",
                           title: String(localized: "Bomb Bonanza"),
                           subtitle: String(localized: "Detonate your way through today's bomb board."),
                           dateKey: key,
                           level: min(count, bombLevel),
                           reward: LevelReward(title: String(localized: "Bomb Bonanza prize"),
                                               coins: 220, lives: 0, shuffles: 1, hammers: 1, swaps: 1))
            ]
        }

        return [
            SugarEvent(id: "sugar-sprint-\(key)",
                       title: String(localized: "Sugar Sprint"),
                       subtitle: String(localized: "Beat today's sprint level for a quick reward."),
                       dateKey: key,
                       level: sprintLevel,
                       reward: LevelReward(title: String(localized: "Sprint prize"),
                                           coins: 160, lives: 0, shuffles: 1, hammers: 0, swaps: 1))
        ]
    }

    // MARK: - Mask presets

    static func full8() -> [[Bool]] { parseMask(Array(repeating: "11111111", count: 8)) }
    static func full9() -> [[Bool]] { parseMask(Array(repeating: "111111111", count: 9)) }

    /// 7×7 octagon — corners cut by `cut`.
    static func octagon7(cut: Int) -> [[Bool]] { cornerCutMask(7, 7, cut: cut) }

    /// 7×7 diamond.
    static func diamond7() -> [[Bool]] {
        let s = ["0001000",
                 "0011100",
                 "0111110",
                 "1111111",
                 "0111110",
                 "0011100",
                 "0001000"]
        return parseMask(s)
    }

    /// 7×7 hourglass — pinched in the middle.
    static func hourglass7() -> [[Bool]] {
        let s = ["1111111",
                 "0111110",
                 "0011100",
                 "0001000",
                 "0011100",
                 "0111110",
                 "1111111"]
        return parseMask(s)
    }

    /// 8×8 octagon — corners cut by `cut`.
    static func octagon8(cut: Int) -> [[Bool]] { cornerCutMask(8, 8, cut: cut) }

    /// 8×8 hourglass — pinched in the middle.
    static func hourglass8() -> [[Bool]] {
        let s = ["11111111",
                 "01111110",
                 "00111100",
                 "00011000",
                 "00011000",
                 "00111100",
                 "01111110",
                 "11111111"]
        return parseMask(s)
    }

    /// 8×8 diamond.
    static func diamond8() -> [[Bool]] {
        let s = ["00011000",
                 "00111100",
                 "01111110",
                 "11111111",
                 "11111111",
                 "01111110",
                 "00111100",
                 "00011000"]
        return parseMask(s)
    }

    /// 8×8 plus.
    static func plus8() -> [[Bool]] {
        let s = ["00111100",
                 "00111100",
                 "00111100",
                 "11111111",
                 "11111111",
                 "00111100",
                 "00111100",
                 "00111100"]
        return parseMask(s)
    }

    /// 8×8 with a hole in the middle (donut).
    static func donut8() -> [[Bool]] {
        let s = ["11111111",
                 "11111111",
                 "11000011",
                 "11000011",
                 "11000011",
                 "11000011",
                 "11111111",
                 "11111111"]
        return parseMask(s)
    }

    /// 8×8 staircase pyramid (top tapers).
    static func stepPyramid8() -> [[Bool]] {
        let s = ["00011000",
                 "00111100",
                 "01111110",
                 "11111111",
                 "11111111",
                 "11111111",
                 "11111111",
                 "11111111"]
        return parseMask(s)
    }

    /// 8×8 step-up (asymmetric staircase).
    static func stepUp8() -> [[Bool]] {
        let s = ["00000011",
                 "00000111",
                 "00001111",
                 "00011111",
                 "00111111",
                 "01111111",
                 "11111111",
                 "11111111"]
        return parseMask(s)
    }

    /// 8×8 right-pointing arrow.
    static func arrow8() -> [[Bool]] {
        let s = ["11111000",
                 "11111100",
                 "11111110",
                 "11111111",
                 "11111111",
                 "11111110",
                 "11111100",
                 "11111000"]
        return parseMask(s)
    }

    /// 8×8 dumbbell (two slabs connected by a thin stem).
    static func dumbbell8() -> [[Bool]] {
        let s = ["11111111",
                 "11111111",
                 "00011000",
                 "00011000",
                 "00011000",
                 "00011000",
                 "11111111",
                 "11111111"]
        return parseMask(s)
    }

    /// 8×8 inverted T-shape.
    static func tShape8() -> [[Bool]] {
        let s = ["00011000",
                 "00011000",
                 "00011000",
                 "00011000",
                 "00011000",
                 "11111111",
                 "11111111",
                 "11111111"]
        return parseMask(s)
    }

    /// 8×8 with `cut` cells removed from each corner (turns the board into an octagon).
    static func cornerCutMask(_ rows: Int, _ cols: Int, cut: Int) -> [[Bool]] {
        var m = Array(repeating: Array(repeating: true, count: cols), count: rows)
        for r in 0..<cut {
            for c in 0..<cut {
                m[r][c] = false
                m[r][cols - 1 - c] = false
                m[rows - 1 - r][c] = false
                m[rows - 1 - r][cols - 1 - c] = false
            }
        }
        return m
    }

    /// 9×9 cross — 3-wide vertical + horizontal arms only.
    static func crossMask9() -> [[Bool]] {
        let s = ["000111000",
                 "000111000",
                 "000111000",
                 "111111111",
                 "111111111",
                 "111111111",
                 "000111000",
                 "000111000",
                 "000111000"]
        return parseMask(s)
    }

    /// 9×9 diamond.
    static func diamondMask9() -> [[Bool]] {
        let s = ["000010000",
                 "000111000",
                 "001111100",
                 "011111110",
                 "111111111",
                 "011111110",
                 "001111100",
                 "000111000",
                 "000010000"]
        return parseMask(s)
    }

    /// 9×9 plus with cut corners (octagonal-plus).
    static func plusMask9() -> [[Bool]] {
        let s = ["001111100",
                 "011111110",
                 "111111111",
                 "111111111",
                 "111111111",
                 "111111111",
                 "111111111",
                 "011111110",
                 "001111100"]
        return parseMask(s)
    }

    /// 9×9 hourglass — cinched in the middle.
    static func hourglassMask9() -> [[Bool]] {
        let s = ["111111111",
                 "111111111",
                 "011111110",
                 "001111100",
                 "000111000",
                 "001111100",
                 "011111110",
                 "111111111",
                 "111111111"]
        return parseMask(s)
    }

    // MARK: - Act II shapes

    /// 8×8 heart — twin bumps on top, single point at the bottom.
    static func heart8() -> [[Bool]] {
        let s = ["00100100",
                 "01100110",
                 "11111111",
                 "11111111",
                 "11111111",
                 "01111110",
                 "00111100",
                 "00011000"]
        return parseMask(s)
    }

    /// 9×9 star — diamond with extruded points top + bottom.
    static func star9() -> [[Bool]] {
        let s = ["000010000",
                 "000111000",
                 "001111100",
                 "111111111",
                 "111111111",
                 "111111111",
                 "001111100",
                 "000111000",
                 "000010000"]
        return parseMask(s)
    }

    /// 8×8 lightning bolt — staggered Z.
    static func lightning8() -> [[Bool]] {
        let s = ["00111111",
                 "00111110",
                 "00011100",
                 "00111000",
                 "00111100",
                 "01111100",
                 "11111100",
                 "11111000"]
        return parseMask(s)
    }

    /// 9×9 crown — three peaks on top, full body, narrow base.
    static func crown9() -> [[Bool]] {
        let s = ["100010001",
                 "101010101",
                 "101111101",
                 "111111111",
                 "111111111",
                 "111111111",
                 "011111110",
                 "001111100",
                 "000111000"]
        return parseMask(s)
    }

    /// 9×9 anchor — vertical stem with crossbar and curved bottom.
    static func anchor9() -> [[Bool]] {
        let s = ["000010000",
                 "000111000",
                 "000010000",
                 "111111111",
                 "111111111",
                 "000010000",
                 "100010001",
                 "111111111",
                 "001111100"]
        return parseMask(s)
    }

    /// 9×9 crescent — left-half moon.
    static func crescent9() -> [[Bool]] {
        let s = ["001111000",
                 "011111000",
                 "111110000",
                 "111100000",
                 "111100000",
                 "111100000",
                 "111110000",
                 "011111000",
                 "001111000"]
        return parseMask(s)
    }

    /// 9×9 flower — five rounded petals around a centre.
    static func flower9() -> [[Bool]] {
        let s = ["010000010",
                 "111101111",
                 "111111111",
                 "111111111",
                 "011111110",
                 "111111111",
                 "111111111",
                 "111101111",
                 "010000010"]
        return parseMask(s)
    }

    /// 9×9 ring — a thicker three-tile perimeter around a hollow centre.
    static func ring9() -> [[Bool]] {
        let s = ["111111111",
                 "111111111",
                 "111111111",
                 "111000111",
                 "111000111",
                 "111000111",
                 "111111111",
                 "111111111",
                 "111111111"]
        return parseMask(s)
    }

    private static func parseMask(_ rows: [String]) -> [[Bool]] {
        rows.map { row in row.map { $0 == "1" } }
    }
}

// MARK: - Skin presets

extension BoardSkin {
    static let glacier = BoardSkin(
        id: "glacier", name: "Glacier",
        boardBg: UIColor(hex: "#0E1626"),
        boardBorder: UIColor(hex: "#93C5FD").withAlphaComponent(0.30),
        tileBg: UIColor(hex: "#141F33"),
        tileBorder: UIColor(hex: "#93C5FD").withAlphaComponent(0.22),
        tileTarget: UIColor(hex: "#1B2A44"),
        tileHighlight: UIColor(hex: "#93C5FD").withAlphaComponent(0.6))

    static let sunset = BoardSkin(
        id: "sunset", name: "Sunset",
        boardBg: UIColor(hex: "#2A1B1B"),
        boardBorder: UIColor(hex: "#FB923C").withAlphaComponent(0.30),
        tileBg: UIColor(hex: "#3B2323"),
        tileBorder: UIColor(hex: "#FB923C").withAlphaComponent(0.22),
        tileTarget: UIColor(hex: "#4A2A2A"),
        tileHighlight: UIColor(hex: "#FB923C").withAlphaComponent(0.6))

    static let berry = BoardSkin(
        id: "berry", name: "Berry Night",
        boardBg: UIColor(hex: "#2A1220"),
        boardBorder: UIColor(hex: "#F43F5E").withAlphaComponent(0.35),
        tileBg: UIColor(hex: "#341625"),
        tileBorder: UIColor(hex: "#F43F5E").withAlphaComponent(0.25),
        tileTarget: UIColor(hex: "#3E1A2B"),
        tileHighlight: UIColor(hex: "#F43F5E").withAlphaComponent(0.6))

    static let citrine = BoardSkin(
        id: "citrine", name: "Citrine",
        boardBg: UIColor(hex: "#2A2412"),
        boardBorder: UIColor(hex: "#FBBF24").withAlphaComponent(0.35),
        tileBg: UIColor(hex: "#332A15"),
        tileBorder: UIColor(hex: "#FBBF24").withAlphaComponent(0.25),
        tileTarget: UIColor(hex: "#3C3118"),
        tileHighlight: UIColor(hex: "#FBBF24").withAlphaComponent(0.65))

    static let lagoon = BoardSkin(
        id: "lagoon", name: "Lagoon",
        boardBg: UIColor(hex: "#0B2020"),
        boardBorder: UIColor(hex: "#2DD4BF").withAlphaComponent(0.30),
        tileBg: UIColor(hex: "#0F2A2A"),
        tileBorder: UIColor(hex: "#2DD4BF").withAlphaComponent(0.22),
        tileTarget: UIColor(hex: "#123535"),
        tileHighlight: UIColor(hex: "#2DD4BF").withAlphaComponent(0.6))

    static let mint = BoardSkin(
        id: "mint", name: "Mint Pop",
        boardBg: UIColor(hex: "#0F1F1A"),
        boardBorder: UIColor(hex: "#2DD4BF").withAlphaComponent(0.25),
        tileBg: UIColor(hex: "#162A24"),
        tileBorder: UIColor(hex: "#2DD4BF").withAlphaComponent(0.18),
        tileTarget: UIColor(hex: "#1C3A31"),
        tileHighlight: UIColor(hex: "#2DD4BF").withAlphaComponent(0.6))

    static let sherbet = BoardSkin(
        id: "sherbet", name: "Sherbet",
        boardBg: UIColor(hex: "#FFF0F6"),
        boardBorder: UIColor(hex: "#FB7185").withAlphaComponent(0.30),
        tileBg: UIColor(hex: "#FFE4EE"),
        tileBorder: UIColor(hex: "#FB7185").withAlphaComponent(0.24),
        tileTarget: UIColor(hex: "#FFD3E4"),
        tileHighlight: UIColor(hex: "#FB7185").withAlphaComponent(0.6))
}
