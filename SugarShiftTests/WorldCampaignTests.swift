import Testing
@testable import SugarShift

struct WorldCampaignTests {
    @Test func everyWorldRecipeIsConnectedAndHasAttainableTargets() throws {
        for level in 16...200 {
            let definition = try #require(WorldCampaign.definition(for: level))
            #expect(try definition.validated() == definition)
            let available = definition.fixedBlockers.count
            #expect(available < definition.activeCells.count * 3 / 4)
            #expect(definition.objectives.count == 3)
        }
    }
    @Test func worldEntryTeachesOneBlockerBeforeMixedLayers() throws {
        for chapter in WorldCampaign.chapters {
            let entry = try #require(WorldCampaign.definition(for: chapter.range.lowerBound))
            #expect(Set(entry.fixedBlockers.map(\.type)) == [chapter.blocker])
            #expect(entry.fixedBlockers.allSatisfy { $0.hits == 1 })
            let late = try #require(WorldCampaign.definition(for: chapter.range.upperBound))
            #expect(late.fixedBlockers.contains { $0.hits > 1 })
        }
    }
    @Test func authoredShapesSurviveRefillAndOfferAnOpeningMove() {
        for level in [16, 26, 36, 51, 66, 81, 101, 116, 136, 166, 186] {
            let config = Levels.config(for: level)
            let board = LevelBoardFactory.makeInitialBoard(config: config, seed: UInt64(level))
            #expect(Engine.hasAnyMoves(board.grid))
            for r in board.grid.indices {
                for c in board.grid[r].indices where config.layout.mask?[r][c] == false {
                    #expect(board.grid[r][c] == nil)
                }
            }
        }
    }
}
