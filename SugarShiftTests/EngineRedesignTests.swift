import Foundation
import Testing
@testable import SugarShift

@Suite(.serialized)
struct EngineRedesignTests {
    @Test func wrappedPairReportsBothBlastStages() {
        let grid: Grid = (0..<7).map { r in (0..<7).map { c in
            Cell(id: "\(r)-\(c)", color: "B", special: nil, kind: .normal)
        } }
        let result = Engine.resolveSpecialComboStaged(
            grid, kind: .wrappedWrapped, first: .wrapped, second: .wrapped,
            positions: (Pos(r: 3, c: 2), Pos(r: 3, c: 3)), targetColor: nil,
            rankedFishTargets: [], bigger: false)
        #expect(result.stages.count == 2)
        #expect(result.stages.first?.positions.contains(Pos(r: 1, c: 3)) == true)
    }

    @Test func fishHitChainsTargetSpecial() {
        var grid: Grid = (0..<5).map { r in (0..<5).map { c in
            Cell(id: "\(r)-\(c)", color: "B", special: nil, kind: .normal)
        } }
        grid[0][0]?.special = .fish
        grid[3][3]?.special = .stripedRow
        let result = Engine.resolveSpecialActivationStaged(
            grid, special: .fish, at: Pos(r: 0, c: 0), rankedTargets: [Pos(r: 3, c: 3)])
        #expect(result.positions.contains(Pos(r: 0, c: 0)))
        #expect(result.positions.contains(Pos(r: 3, c: 4)))
    }

    @Test func normalMatchDamagesAdjacentStoneButCannotDamageMagicFrost() {
        var grid: Grid = [[
            Cell(id: "fruit", color: "R", special: nil, kind: .normal),
            Cell(piece: nil, tile: BoardTile(blocker: Blocker(type: .stone, hits: 2))),
            Cell(id: "frost", color: "G", special: nil, kind: .normal,
                 blocker: Blocker(type: .magicFrost, hits: 1))
        ]]
        _ = Engine.clearMatches(&grid, matches: [Pos(r: 0, c: 0), Pos(r: 0, c: 2)])
        #expect(grid[0][1]?.blocker?.hits == 1)
        #expect(grid[0][2]?.blocker?.type == .magicFrost)
        _ = Engine.clearMatches(&grid, matches: [Pos(r: 0, c: 2)], context: .special)
        #expect(grid[0][2]?.blocker == nil)
    }

    @Test func movementBlockersCannotBeSwapped() {
        let grid: Grid = [[
            Cell(id: "locked", color: "R", special: .wrapped, kind: .normal,
                 blocker: Blocker(type: .lock, hits: 1)),
            Cell(id: "free", color: "G", special: .bomb, kind: .normal)
        ]]

        #expect(Engine.classifySwap(grid, Pos(r: 0, c: 0), Pos(r: 0, c: 1)) == nil)
    }

    @Test func gravityKeepsFixedBlockerAtItsBoardPosition() {
        let grid: Grid = [
            [Cell(id: "top", color: "R", special: nil, kind: .normal)],
            [Cell(id: "locked", color: "G", special: nil, kind: .normal,
                  blocker: Blocker(type: .lock, hits: 1))],
            [nil]
        ]
        var rng = SeededRandomNumberGenerator(seed: 7)

        let settled = Engine.collapseAndRefill(grid,
                                               colors: ["R", "G", "B"],
                                               rng: &rng)

        #expect(settled[1][0]?.blocker?.type == .lock)
        #expect(settled[1][0]?.id == "locked")
        #expect(settled[2][0]?.blocker == nil)
    }

    @Test func occupiedPortalDoesNotSwapTwoPieces() {
        let grid: Grid = [[
            Cell(id: "source", color: "R", special: nil, kind: .normal),
            Cell(id: "exit", color: "G", special: nil, kind: .normal)
        ]]

        let moved = Engine.applyPortals(
            grid,
            pairs: [LevelPortal(from: Pos(r: 0, c: 0), to: Pos(r: 0, c: 1))])

        #expect(moved[0][0]?.id == "source")
        #expect(moved[0][1]?.id == "exit")
    }

    @Test func conveyorMovesPiecesButKeepsBlockedTileAnchored() {
        let grid: Grid = [[
            Cell(id: "a", color: "R", special: nil, kind: .normal),
            Cell(id: "locked", color: "G", special: nil, kind: .normal,
                 blocker: Blocker(type: .lock, hits: 1)),
            Cell(id: "c", color: "B", special: nil, kind: .normal),
            Cell(id: "d", color: "Y", special: nil, kind: .normal)
        ]]

        let moved = Engine.applyConveyors(
            grid,
            belts: [ConveyorBelt(row: 0, direction: 1)])

        #expect(moved[0][1]?.id == "locked")
        #expect(moved[0][1]?.blocker?.type == .lock)
        #expect(moved[0][2]?.id == "d")
        #expect(moved[0][3]?.id == "c")
    }

    @Test func twoStripesAlwaysResolveToOneRowAndOneColumn() {
        let grid: Grid = (0..<5).map { r in
            (0..<5).map { c in
                Cell(id: "\(r)-\(c)",
                     color: "B",
                     special: r == 2 && (c == 1 || c == 2) ? .stripedRow : nil,
                     kind: .normal)
            }
        }

        let affected = Engine.resolveSpecialCombo(
            grid,
            kind: .stripeStripe,
            first: .stripedRow,
            second: .stripedRow,
            positions: (Pos(r: 2, c: 1), Pos(r: 2, c: 2)),
            targetColor: nil,
            rankedFishTargets: [],
            bigger: false)

        #expect(affected.count == 9)
        #expect(affected.contains(Pos(r: 0, c: 2)))
        #expect(affected.contains(Pos(r: 2, c: 4)))
        #expect(!affected.contains(Pos(r: 1, c: 0)))
    }
}
