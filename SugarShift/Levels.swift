import UIKit

// MARK: - Level archetypes

enum LevelArchetype {
    case starter      // pure score, gentle pacing
    case combo        // rewards cascades — tighter moves, generous target
    case ice          // ice blockers seeded on the board
    case lock         // lock blockers seeded on the board
    case crowded      // smaller board, more colors
    case bombRush     // bombs spawn earlier and from move 1
    case finale       // boss flavor — exotic shape + many blockers
}

// MARK: - Layout (board shape + starting blockers)

struct LevelLayout {
    /// Optional `[[Bool]]` mask. true = playable cell, false = hole. nil = full board.
    let mask: [[Bool]]?
    /// Random ice tiles seeded on playable cells at start.
    let iceCount: Int
    /// Random lock tiles seeded on playable cells at start.
    let lockCount: Int
    /// Bomb tiles pre-placed before the player's first move.
    let startingBombs: Int

    static let `default` = LevelLayout(mask: nil, iceCount: 0, lockCount: 0, startingBombs: 0)
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
    let skin: BoardSkin
    let layout: LevelLayout
    let starThresholds: (one: Int, two: Int, three: Int)
    /// Bomb spawns when a single match group reaches this length.
    let bombSpawnRunLength: Int?
    let blurb: String
}

// MARK: - Catalog

enum Levels {

    static let count = 20

    static func config(for level: Int) -> LevelConfig {
        let n = max(1, min(level, count))
        switch n {
        case 1:  return mk(n, 8, 8, 5, 25, 2000,  .starter,   .midnight,
                           layout(mask: full8()),
                           "Start sweet — match any three.")
        case 2:  return mk(n, 8, 8, 5, 24, 2600,  .starter,   .midnight,
                           layout(mask: octagon8(cut: 1)),
                           "Trim the corners — adapt your runs.")
        case 3:  return mk(n, 8, 8, 5, 23, 3200,  .combo,     .midnight,
                           layout(mask: stepPyramid8()),
                           "Cascade down the steps.")
        case 4:  return mk(n, 8, 8, 6, 22, 3800,  .starter,   .midnight,
                           layout(mask: diamond8()),
                           "Diamond board. New fruit joins.")
        case 5:  return mk(n, 8, 8, 6, 22, 4400,  .ice,       .glacier,
                           layout(mask: octagon8(cut: 1), ice: 6),
                           "Frost forms — break it twice.", bomb: 5)
        case 6:  return mk(n, 8, 8, 6, 20, 5000,  .starter,   .glacier,
                           layout(mask: hourglass8(), ice: 4),
                           "Hourglass shape — squeeze through.")
        case 7:  return mk(n, 8, 8, 6, 20, 5800,  .combo,     .glacier,
                           layout(mask: donut8()),
                           "Match around the hole in the middle.")
        case 8:  return mk(n, 8, 8, 6, 18, 6500,  .ice,       .glacier,
                           layout(mask: plus8(), ice: 8),
                           "Plus-shape & deep frost.")
        case 9:  return mk(n, 8, 8, 6, 18, 7200,  .bombRush,  .sunset,
                           layout(mask: arrow8(), startingBombs: 2),
                           "Arrow board — bombs pre-loaded.", bomb: 4)
        case 10: return mk(n, 9, 9, 6, 22, 8500,  .starter,   .sunset,
                           layout(mask: full9()),
                           "9×9 — bigger canvas.")
        case 11: return mk(n, 8, 8, 6, 16, 7500,  .combo,     .sunset,
                           layout(mask: stepUp8()),
                           "Step-up shape. Tight budget.")
        case 12: return mk(n, 8, 8, 6, 18, 8200,  .lock,      .berry,
                           layout(mask: octagon8(cut: 2), lock: 6),
                           "Locked tiles need direct hits.")
        case 13: return mk(n, 9, 9, 6, 20, 9800,  .combo,     .berry,
                           layout(mask: crossMask9()),
                           "Cross-shape board — chain it.")
        case 14: return mk(n, 8, 8, 6, 14, 7800,  .bombRush,  .berry,
                           layout(mask: dumbbell8(), startingBombs: 3),
                           "Dumbbell board. Bombs ready.", bomb: 4)
        case 15: return mk(n, 9, 9, 6, 18, 11000, .crowded,   .citrine,
                           layout(mask: diamondMask9()),
                           "Six-fruit diamond. Crowded.")
        case 16: return mk(n, 8, 8, 6, 16, 10500, .ice,       .citrine,
                           layout(mask: octagon8(cut: 1), ice: 8, lock: 4),
                           "Ice + locks — the floor is slippery.")
        case 17: return mk(n, 9, 9, 6, 16, 13000, .combo,     .lagoon,
                           layout(mask: plusMask9()),
                           "Plus-shape combos required.")
        case 18: return mk(n, 8, 8, 6, 14, 11500, .crowded,   .lagoon,
                           layout(mask: tShape8(), ice: 4),
                           "T-shape. Tight + crowded.")
        case 19: return mk(n, 9, 9, 6, 18, 15500, .bombRush,  .mint,
                           layout(mask: plusMask9(), startingBombs: 4),
                           "Bomb storm. Detonate everything.", bomb: 4)
        case 20: return mk(n, 9, 9, 6, 20, 19500, .finale,    .sherbet,
                           layout(mask: hourglassMask9(), ice: 6, lock: 4, startingBombs: 2),
                           "The Sugar Crown awaits.", bomb: 5)
        default: return mk(1, 8, 8, 5, 25, 2000, .starter, .midnight,
                           layout(mask: full8()), "")
        }
    }

    private static func layout(mask: [[Bool]]?,
                               ice: Int = 0,
                               lock: Int = 0,
                               startingBombs: Int = 0) -> LevelLayout {
        LevelLayout(mask: mask, iceCount: ice, lockCount: lock, startingBombs: startingBombs)
    }

    private static func mk(_ n: Int,
                           _ rows: Int, _ cols: Int,
                           _ colors: Int, _ moves: Int, _ target: Int,
                           _ archetype: LevelArchetype,
                           _ skin: BoardSkin,
                           _ layoutValue: LevelLayout,
                           _ blurb: String,
                           bomb: Int? = 5) -> LevelConfig {
        let layout = layoutValue
        return LevelConfig(number: n,
                           rows: rows, cols: cols, colors: colors,
                           moves: moves, target: target,
                           archetype: archetype,
                           skin: skin,
                           layout: layout,
                           starThresholds: (Int(Double(target) * 0.6),
                                            Int(Double(target) * 0.8),
                                            target),
                           bombSpawnRunLength: bomb,
                           blurb: blurb)
    }

    // MARK: - Mask presets

    static func full8() -> [[Bool]] { parseMask(Array(repeating: "11111111", count: 8)) }
    static func full9() -> [[Bool]] { parseMask(Array(repeating: "111111111", count: 9)) }

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
