import Foundation

/// Authored world recipes extend the existing LevelDefinition/factory pipeline.
/// Stable campaign IDs, rewards, persistence and the Tower/Rush generators stay
/// intact. A recipe introduces one blocker, then mixes familiar mechanics.
enum WorldCampaign {
    struct Chapter {
        let id: String
        let range: ClosedRange<Int>
        let blocker: BlockerType
        let secondary: BlockerType
        let collection: [PieceColor]
    }
    static let chapters: [Chapter] = [
        .init(id: "ice", range: 16...30, blocker: .ice, secondary: .ice, collection: [.blueberry, .strawberry]),
        .init(id: "honey", range: 31...45, blocker: .honey, secondary: .chocolate, collection: [.grape, .heart]),
        .init(id: "volcano", range: 46...60, blocker: .stone, secondary: .donut, collection: [.strawberry, .orange]),
        .init(id: "coral", range: 61...75, blocker: .vine, secondary: .crate, collection: [.heart, .grape]),
        .init(id: "cloud", range: 76...90, blocker: .cream, secondary: .lock, collection: [.grape, .heart]),
        .init(id: "golden", range: 91...110, blocker: .stone, secondary: .crate, collection: [.grape, .orange]),
        .init(id: "firefly", range: 111...130, blocker: .vine, secondary: .ice, collection: [.heart, .leaf]),
        .init(id: "sahara", range: 131...150, blocker: .stone, secondary: .crate, collection: [.heart, .grape]),
        .init(id: "galaxy", range: 151...175, blocker: .stone, secondary: .cage, collection: [.blueberry, .strawberry]),
        .init(id: "sakura", range: 176...200, blocker: .stone, secondary: .cage, collection: [.heart, .grape])
    ]

    static func definition(for level: Int) -> LevelDefinition? {
        guard let chapter = chapters.first(where: { $0.range.contains(level) }) else { return nil }
        let offset = level - chapter.range.lowerBound
        let finale = level == chapter.range.upperBound
        let teaching = offset < 3
        let pattern: [String]
        if chapter.id == "ice" {
            // The frozen board in the reference is a broad, dense seven-by-seven
            // field. Its interest comes from the ice layers and trapped fruit.
            pattern = Array(repeating: "#######", count: 7)
        } else if teaching {
            pattern = [".#####.", "#######", "#######", "#######", "#######", "#######", ".#####."]
        } else if chapter.id == "golden" {
            pattern = [".#####.", "#######", "#######", "#######", "#######", "#######", ".#####."]
        } else if chapter.id == "cloud" {
            pattern = ["..##.##..", ".#######.", "#########", "#########", ".#######.",
                       "#########", ".#######.", ".#######.", "..#####..", "...###..."]
        } else if ["firefly", "galaxy"].contains(chapter.id) {
            pattern = ["..##.##..", ".#######.", "###.#.###", "#########", ".#######.",
                       "###.#.###", "#########", ".#######.", "..#####..", "...#.#..."]
        } else if chapter.id == "volcano" {
            pattern = [".#..#..#.", ".#######.", "#########", ".###.###.", "#########",
                       "#########", "###.#####", ".#######.", "#########", "..#...#.."]
        } else if chapter.id == "sakura" {
            pattern = ["..##.##..", ".#######.", "#########", "#########", ".#######.",
                       "#########", "#########", ".#######.", "..#####..", "..##.##.."]
        } else {
            pattern = ["..#####..", ".#######.", "#########", "#########", "#########",
                       "#########", "#########", ".#######.", "..#####.."]
        }
        let height = pattern.count, width = pattern[0].count
        let cells = pattern.enumerated().flatMap { r, line in
            line.enumerated().compactMap { c, character in
                character == "#" ? LevelCell(row: r, column: c) : nil
            }
        }
        let active = Set(cells)
        // Keep a clear central lane and teach from the edges inward. Stable
        // ordering is independent of the random fruit refill stream.
        let candidates = cells.filter { !($0.column == width / 2 && (height / 2 - 1...height / 2 + 1).contains($0.row)) }
            .sorted { a, b in
                let edgeA = min(a.row, height - 1 - a.row, a.column, width - 1 - a.column)
                let edgeB = min(b.row, height - 1 - b.row, b.column, width - 1 - b.column)
                let rankA = (a.row * 17 + a.column * 31 + offset * 7) % 97
                let rankB = (b.row * 17 + b.column * 31 + offset * 7) % 97
                return (edgeA, rankA, a.row, a.column) < (edgeB, rankB, b.row, b.column)
            }
        let primaryCapacity = chapter.blocker == .ice ? candidates.count * 2 / 3 : candidates.count / 3
        let primaryCount = min(primaryCapacity, teaching ? 6 + offset * 2 : chapter.blocker == .ice ? 14 + offset : 12 + min(10, offset))
        var blockers = candidates.prefix(primaryCount).enumerated().map { index, cell in
            LevelFixedBlocker(position: cell, type: chapter.blocker,
                              hits: teaching ? 1 : 1 + (index + offset) % (offset >= 8 ? 3 : 2))
        }
        if offset >= 5, chapter.secondary != chapter.blocker {
            let count = min(6, 2 + offset / 4)
            blockers += candidates.dropFirst(primaryCount).prefix(count).map {
                LevelFixedBlocker(position: $0, type: chapter.secondary, hits: finale ? 2 : 1)
            }
        }
        let goal: LevelObjective = chapter.blocker == .ice ? .breakIce(count: primaryCount)
            : .destroySpecificBlocker(type: chapter.blocker, count: primaryCount)
        let target = teaching ? 8 + offset * 2 : 12 + min(8, offset / 2)
        let objectives = [goal] + chapter.collection.map { LevelObjective.collectPieces(color: $0, count: target) }
        var portals: [LevelDefinitionPortal] = []
        if chapter.id == "galaxy", offset >= 3 {
            let free = cells.filter { cell in !blockers.contains { $0.position == cell } }
            if let from = free.first, let to = free.last, from != to {
                portals = [.init(from: from, to: to)]
            }
        }
        var conveyors: [LevelDefinitionConveyor] = []
        if chapter.id == "galaxy", offset >= 10 {
            let r = height / 2
            if (0..<width).filter({ active.contains(LevelCell(row: r, column: $0)) }).count >= 2 {
                conveyors = [.init(row: r, direction: offset.isMultiple(of: 2) ? 1 : -1)]
            }
        }
        let score = teaching ? 3_000 : 5_000 + primaryCount * 100
        return LevelDefinition(id: level, boardWidth: width, boardHeight: height,
            activeCells: cells, pieceTypes: PieceColor.allCases,
            moves: teaching ? 32 : finale ? 32 : 30,
            objectives: objectives, fixedBlockers: blockers, portals: portals, conveyors: conveyors,
            starThresholds: .init(one: score, two: score * 2, three: score * 3),
            difficulty: finale || offset % 5 == 4 ? .hard : .normal)
    }
}
