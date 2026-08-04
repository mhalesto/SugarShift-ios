import Foundation
import SpriteKit
import Testing
@testable import SugarShift

@Suite(.serialized)
@MainActor
struct SugarShiftTests {

    @Test func initialGridHasNoMatchesAndHonorsMask() {
        let mask = [
            [true, true, false],
            [true, true, true],
            [false, true, true]
        ]
        let grid = Engine.createInitialGrid(rows: 3,
                                            cols: 3,
                                            colors: Array(Theme.colors.prefix(3)),
                                            mask: mask)

        #expect(grid[0][2] == nil)
        #expect(grid[2][0] == nil)
        #expect(Engine.findMatches(grid).isEmpty)
    }

    @Test func seededInitialGridIsReplayable() {
        let mask = [
            [true, true, true, true],
            [true, true, false, true],
            [true, true, true, true],
            [true, false, true, true]
        ]
        var firstRNG = SeededRandomNumberGenerator(seed: 42)
        var secondRNG = SeededRandomNumberGenerator(seed: 42)
        let first = Engine.createInitialGrid(rows: 4,
                                             cols: 4,
                                             colors: Array(Theme.colors.prefix(4)),
                                             mask: mask,
                                             rng: &firstRNG)
        let second = Engine.createInitialGrid(rows: 4,
                                              cols: 4,
                                              colors: Array(Theme.colors.prefix(4)),
                                              mask: mask,
                                              rng: &secondRNG)

        #expect(boardSignature(first) == boardSignature(second))
        #expect(Engine.findMatches(first).isEmpty)
    }

    @Test func levelBoardFactoryBuildsReplayableOpeningBoards() {
        let config = Levels.config(for: 26)
        let seed = LevelSeed.make(level: config.number, attempt: 3, salt: 99)
        let first = LevelBoardFactory.makeInitialBoard(config: config,
                                                       seed: seed,
                                                       minimumOpeningMoveScore: 20)
        let second = LevelBoardFactory.makeInitialBoard(config: config,
                                                        seed: seed,
                                                        minimumOpeningMoveScore: 20)

        #expect(first.seed == second.seed)
        #expect(first.openingMoveScore == second.openingMoveScore)
        #expect(boardSignature(first.grid) == boardSignature(second.grid))
        #expect(Engine.findMatches(first.grid).isEmpty)
        #expect(Engine.findSquares(first.grid).isEmpty)
        #expect(Engine.hasAnyMoves(first.grid))
    }

    @Test func blockersTakeHitsBeforeTileClears() {
        let p = Pos(r: 0, c: 0)
        var grid: Grid = [[
            Cell(id: "a", color: "#F97316", special: nil, kind: .normal,
                 blocker: Blocker(type: .ice, hits: 2))
        ]]

        let first = Engine.clearMatches(&grid, matches: Set([p]))
        #expect(first.cleared.isEmpty)
        #expect(first.damagedBlockers == Set([p]))
        #expect(grid[0][0]?.blocker?.hits == 1)

        let second = Engine.clearMatches(&grid, matches: Set([p]))
        #expect(second.cleared.isEmpty)
        #expect(second.damagedBlockers == Set([p]))
        #expect(grid[0][0]?.blocker == nil)
        #expect(grid[0][0] != nil)

        let third = Engine.clearMatches(&grid, matches: Set([p]))
        #expect(third.cleared == Set([p]))
        #expect(grid[0][0] == nil)
    }

    @Test func specialSpawnRulesCreateExpectedPowerUps() {
        let fourAcross = [[Pos(r: 0, c: 0), Pos(r: 0, c: 1), Pos(r: 0, c: 2), Pos(r: 0, c: 3)]]
        #expect(Engine.specialSpawn(from: fourAcross)?.special == .stripedRow)
        #expect(Engine.specialSpawn(from: fourAcross, bombRunLength: 4)?.special == .stripedRow)

        let fourDown = [[Pos(r: 0, c: 0), Pos(r: 1, c: 0), Pos(r: 2, c: 0), Pos(r: 3, c: 0)]]
        #expect(Engine.specialSpawn(from: fourDown)?.special == .stripedCol)

        let fiveStraight = [[Pos(r: 1, c: 0), Pos(r: 1, c: 1), Pos(r: 1, c: 2), Pos(r: 1, c: 3), Pos(r: 1, c: 4)]]
        #expect(Engine.specialSpawn(from: fiveStraight)?.special == .colorBomb)

        let tShape = [
            [Pos(r: 1, c: 0), Pos(r: 1, c: 1), Pos(r: 1, c: 2)],
            [Pos(r: 0, c: 1), Pos(r: 1, c: 1), Pos(r: 2, c: 1)]
        ]
        let wrapped = Engine.specialSpawn(from: tShape)
        #expect(wrapped?.special == .wrapped)
        #expect(wrapped?.position == Pos(r: 1, c: 1))

        let huge = [[Pos(r: 2, c: 0), Pos(r: 2, c: 1), Pos(r: 2, c: 2),
                     Pos(r: 2, c: 3), Pos(r: 2, c: 4), Pos(r: 2, c: 5)]]
        #expect(Engine.specialSpawn(from: huge)?.special == .bomb)

        let colorBombGrid: Grid = [[
            Cell(id: "bomb", color: "#111827", special: .colorBomb, kind: .normal),
            Cell(id: "tile", color: "#F97316", special: nil, kind: .normal)
        ]]
        #expect(Engine.swapIfValid(colorBombGrid, Pos(r: 0, c: 0), Pos(r: 0, c: 1)).didSwap)
    }

    @Test func everySpecialPairClassifiesAndCountsAsAPlayableMove() {
        let specials = Special.allCases
        var pairCount = 0
        for firstIndex in specials.indices {
            for secondIndex in firstIndex..<specials.count {
                let first = specials[firstIndex]
                let second = specials[secondIndex]
                pairCount += 1
                let kind = Engine.specialComboKind(first, second)
                #expect(kind != nil)
                #expect(kind == Engine.specialComboKind(second, first))

                let grid: Grid = [[
                    Cell(id: "a", color: "A", special: first, kind: .normal),
                    Cell(id: "b", color: "B", special: second, kind: .normal)
                ]]
                let swap = Engine.classifySwap(grid, Pos(r: 0, c: 0), Pos(r: 0, c: 1))
                #expect(swap != nil)
                if case .specialCombo(let classifiedKind, _, _, _) = swap?.activation {
                    #expect(classifiedKind == kind)
                } else {
                    Issue.record("special pair did not classify as a combo")
                }
                #expect(Engine.hasAnyMoves(grid))
                #expect(Engine.findHintMove(grid) != nil)
            }
        }
        #expect(pairCount == 21)
    }

    @Test func pureComboResolverHonorsFootprintsHolesAndConsumedPieces() {
        func cell(_ r: Int, _ c: Int, color: String = "B", special: Special? = nil) -> Cell {
            Cell(id: "\(r)-\(c)", color: color, special: special, kind: .normal)
        }
        var grid: Grid = (0..<9).map { r in
            (0..<9).map { c in Optional(cell(r, c)) }
        }
        let source = Pos(r: 4, c: 3)
        let destination = Pos(r: 4, c: 4)
        grid[source.r][source.c]?.special = .bomb
        grid[destination.r][destination.c]?.special = .stripedRow

        let lanes = Engine.resolveSpecialCombo(grid,
                                               kind: .bombStripe,
                                               first: .bomb,
                                               second: .stripedRow,
                                               positions: (source, destination),
                                               targetColor: nil,
                                               rankedFishTargets: [],
                                               bigger: false)
        #expect(lanes.count == 27)
        #expect(lanes.allSatisfy { (3...5).contains($0.r) })

        let edgeLanes = Engine.resolveSpecialCombo(grid,
                                                   kind: .bombStripe,
                                                   first: .bomb,
                                                   second: .stripedRow,
                                                   positions: (Pos(r: 0, c: 0), Pos(r: 0, c: 1)),
                                                   targetColor: nil,
                                                   rankedFishTargets: [],
                                                   bigger: false)
        #expect(edgeLanes.count == 27)
        #expect(edgeLanes.allSatisfy { (0...2).contains($0.r) })

        grid[2][2] = nil
        let all = Engine.resolveSpecialCombo(grid,
                                             kind: .colorColor,
                                             first: .colorBomb,
                                             second: .colorBomb,
                                             positions: (source, destination),
                                             targetColor: nil,
                                             rankedFishTargets: [],
                                             bigger: false)
        #expect(all.count == 80)
        #expect(!all.contains(Pos(r: 2, c: 2)))
    }

    @Test func specialPlacementPrefersMovedTileAndFallsBackToEligibleCells() {
        let destination = Pos(r: 0, c: 3)
        let source = Pos(r: 0, c: 0)
        let run = [[source, Pos(r: 0, c: 1), Pos(r: 0, c: 2), destination]]
        #expect(Engine.specialSpawn(from: run,
                                    preferredPositions: [destination, source])?.position == destination)
        #expect(Engine.specialSpawn(from: run,
                                    preferredPositions: [destination, source],
                                    eligiblePositions: [source, Pos(r: 0, c: 1)])?.position == source)

        let tShape = [
            [Pos(r: 1, c: 0), Pos(r: 1, c: 1), Pos(r: 1, c: 2)],
            [Pos(r: 0, c: 1), Pos(r: 1, c: 1), Pos(r: 2, c: 1)]
        ]
        #expect(Engine.specialSpawn(from: tShape,
                                    preferredPositions: [Pos(r: 1, c: 0)])?.position == Pos(r: 1, c: 0))
    }

    @Test func dropItemsCannotMatchOrBeDeletedBySpecialFootprints() {
        let ingredient = Pos(r: 0, c: 1)
        var grid: Grid = [[
            Cell(id: "a", color: "R", special: nil, kind: .normal),
            Cell(id: "basket", color: "R", special: nil, kind: .ingredient),
            Cell(id: "c", color: "R", special: nil, kind: .normal)
        ]]
        #expect(Engine.findMatches(grid).isEmpty)
        let result = Engine.clearMatches(&grid, matches: [ingredient])
        #expect(result.cleared.isEmpty)
        #expect(grid[ingredient.r][ingredient.c]?.kind == .ingredient)
    }

    @Test func comboContractsAreFeasibleAndBossesHaveRealShieldRules() {
        for level in 1...Levels.count {
            let config = Levels.config(for: level)
            if let contract = ComboContract.contract(for: config) {
                #expect(contract.target > 0)
                #expect(contract.reward > 0)
                if contract.kind == .damageBlockers {
                    #expect(config.layout.blockerCount > 0)
                }
            }
        }

        let boss = GameScene(size: CGSize(width: 390, height: 844))
        boss.levelConfig = Levels.config(for: 10)
        boss.configureBossForNewAttempt()
        #expect(boss.bossShieldRemaining == 2)
        #expect(!boss.isBossShieldBroken)
        boss.damageBossShield(by: 2, source: "test")
        #expect(boss.isBossShieldBroken)
        #expect(GameScene.smashChargeGain(tilesCleared: 3,
                                         blockersDamaged: 1,
                                         specialsTriggered: 1) == 23)
        #expect(GameScene.smashChargeGain(tilesCleared: 3,
                                         blockersDamaged: 1,
                                         specialsTriggered: 1,
                                         multiplier: 0.5) == 12)
        #expect(GameScene.smashChargeGain(tilesCleared: 3,
                                         blockersDamaged: 1,
                                         specialsTriggered: 1,
                                         multiplier: 1.3,
                                         objectiveHits: 2) == 34)
        #expect(GameScene.smashChargeGain(tilesCleared: 20,
                                         blockersDamaged: 4,
                                         specialsTriggered: 3,
                                         multiplier: 0,
                                         objectiveHits: 5) == 0)
        #expect(PlayerSmashTier.tier(for: 49) == nil)
        #expect(PlayerSmashTier.tier(for: 50) == .focused)
        #expect(PlayerSmashTier.tier(for: 75) == .cross)
        #expect(PlayerSmashTier.tier(for: 100) == .mega)
    }

    @Test func clearPresentationPlansPreserveDirectionalCausality() {
        let origin = Pos(r: 4, c: 4)
        let ripple = ClearPresentationPlan(kind: .combo(.colorColor),
                                           origin: origin,
                                           secondary: Pos(r: 4, c: 3),
                                           firstSpecial: .colorBomb,
                                           secondSpecial: .colorBomb,
                                           fishTargets: [],
                                           colorTargets: [])
        #expect(ripple.delay(for: origin) == 0)
        #expect(ripple.delay(for: Pos(r: 0, c: 0)) > ripple.delay(for: Pos(r: 3, c: 3)))

        let fishTarget = Pos(r: 1, c: 7)
        let fish = ClearPresentationPlan(kind: .combo(.fishBomb),
                                         origin: origin,
                                         secondary: Pos(r: 4, c: 3),
                                         firstSpecial: .fish,
                                         secondSpecial: .bomb,
                                         fishTargets: [fishTarget],
                                         colorTargets: [])
        #expect(fish.delay(for: fishTarget) >= 0.18)
        #expect(fish.maximumDelay(in: [fishTarget, origin]) >= fish.delay(for: fishTarget))
    }

    @Test func turnMasteryRewardsAgencyAndMakesCoolingVisible() {
        let routine = TurnMasteryPolicy.evaluate(
            flow: 3,
            intent: .match,
            tilesCleared: 3,
            blockersDamaged: 0,
            specialsTriggered: 0,
            specialsCreated: 0,
            objectiveHits: 0,
            cascadeDepth: 1,
            scoreEarned: 30)
        #expect(routine.grade == .routine)
        #expect(routine.flowAfter == 2)
        #expect(routine.scoreBonus == 0)

        let objectiveMove = TurnMasteryPolicy.evaluate(
            flow: 0,
            intent: .match,
            tilesCleared: 3,
            blockersDamaged: 1,
            specialsTriggered: 0,
            specialsCreated: 0,
            objectiveHits: 1,
            cascadeDepth: 1,
            scoreEarned: 30)
        #expect(objectiveMove.grade == .purposeful)
        #expect(objectiveMove.flowAfter == 1)
        #expect(objectiveMove.scoreBonus > 0)

        let plannedCombo = TurnMasteryPolicy.evaluate(
            flow: 1,
            intent: .specialCombo,
            tilesCleared: 12,
            blockersDamaged: 2,
            specialsTriggered: 2,
            specialsCreated: 0,
            objectiveHits: 2,
            cascadeDepth: 1,
            scoreEarned: 700)
        #expect(plannedCombo.grade == .masterful)
        #expect(plannedCombo.flowAfter == 3)
        #expect(plannedCombo.chargesSugarRush)
        #expect(plannedCombo.smashBonus == 8)

        let smash = TurnMasteryPolicy.evaluate(
            flow: 4,
            intent: .playerSmash,
            tilesCleared: 15,
            blockersDamaged: 3,
            specialsTriggered: 1,
            specialsCreated: 0,
            objectiveHits: 3,
            cascadeDepth: 2,
            scoreEarned: 800)
        #expect(smash.flowAfter == 4)
        #expect(smash.smashBonus == 0)
    }

    @Test func sugarRushAndTacticalAnalysisUseThePlayersChosenAnchor() {
        func cell(_ id: String, _ color: String, blocker: Blocker? = nil) -> Cell {
            Cell(id: id, color: color, special: nil, kind: .normal, blocker: blocker)
        }
        let fullGrid: Grid = (0..<3).map { r in
            (0..<3).map { c in Optional(cell("\(r)-\(c)", "R")) }
        }
        let chosen = Pos(r: 1, c: 1)
        let rush = Engine.sugarRushResolution(in: fullGrid,
                                              base: [chosen],
                                              preferredAnchor: chosen)
        #expect(rush.anchor == chosen)
        #expect(rush.positions == Set([
            Pos(r: 1, c: 0), Pos(r: 1, c: 1), Pos(r: 1, c: 2),
            Pos(r: 0, c: 1), Pos(r: 2, c: 1)
        ]))

        let fuse = Pos(r: 0, c: 0)
        let tacticalGrid: Grid = [
            [cell("a", "R", blocker: Blocker(type: .countdown, hits: 1, countdown: 1)),
             cell("b", "G"), cell("c", "R")],
            [cell("d", "B"), cell("e", "R"), cell("f", "G")],
            [cell("g", "G"), cell("h", "B"), cell("i", "R")]
        ]
        let analysis = TacticalMoveEvaluator.analysis(
            for: Pos(r: 0, c: 1), Pos(r: 1, c: 1),
            in: tacticalGrid,
            config: Levels.config(for: 8))
        #expect(analysis != nil)
        #expect(analysis?.affected.contains(fuse) == true)
        #expect(analysis?.objectivePositions.contains(fuse) == true)
        #expect(analysis?.hazardPositions.contains(fuse) == true)
    }

    @Test func precisionSmashOffersTierChoiceAndTruthfulTargeting() {
        #expect(PlayerSmashTier.available(for: 49).isEmpty)
        #expect(PlayerSmashTier.available(for: 50) == [.focused])
        #expect(PlayerSmashTier.available(for: 75) == [.cross, .focused])
        #expect(PlayerSmashTier.available(for: 100) == [.mega, .cross, .focused])
        #expect(PlayerSmashTier.nextAvailable(after: .mega, charge: 100) == .cross)
        #expect(PlayerSmashTier.nextAvailable(after: .cross, charge: 100) == .focused)
        #expect(PlayerSmashTier.nextAvailable(after: .focused, charge: 100) == nil)
        #expect(PlayerSmashTier.focused.chargeCost == 50)
        #expect(PlayerSmashTier.cross.chargeCost == 75)
        #expect(PlayerSmashTier.mega.chargeCost == 100)

        func cell(_ id: String, blocker: Blocker? = nil) -> Cell {
            Cell(id: id, color: "R", special: nil, kind: .normal, blocker: blocker)
        }
        let fuse = Pos(r: 0, c: 0)
        let grid: Grid = [
            [cell("a", blocker: Blocker(type: .countdown, hits: 1, countdown: 1)),
             cell("b"), cell("c")],
            [cell("d"), cell("e"), cell("f")],
            [cell("g"), cell("h"), nil]
        ]
        let center = Pos(r: 1, c: 1)
        #expect(Engine.playerSmashFootprint(in: grid,
                                           centeredAt: center,
                                           tier: .focused).count == 8)
        #expect(Engine.playerSmashFootprint(in: grid,
                                           centeredAt: center,
                                           tier: .cross).count == 5)
        #expect(Engine.playerSmashFootprint(in: grid,
                                           centeredAt: center,
                                           tier: .mega).count == 8)

        let smash = TacticalSmashEvaluator.analysis(
            tier: .focused,
            centeredAt: center,
            in: grid,
            config: Levels.config(for: 8))
        #expect(smash?.affected.contains(fuse) == true)
        #expect(smash?.objectivePositions.contains(fuse) == true)
        #expect(smash?.hazardPositions.contains(fuse) == true)
        #expect(TacticalSmashEvaluator.bestTarget(tier: .focused,
                                                  in: grid,
                                                  config: Levels.config(for: 8))?.center == center)
    }

    @Test func levelCatalogIsValidThroughTwoHundred() {
        #expect(Levels.count >= 200)
        #expect(Levels.config(for: 200).number == 200)

        for n in 1...Levels.count {
            let config = Levels.config(for: n)
            #expect(config.number == n)
            #expect(config.colors >= 3)
            #expect(config.colors <= Theme.colors.count)
            #expect(config.moves > 0)
            #expect(config.target > 0)
            #expect(config.starThresholds.one == config.target)
            #expect(config.starThresholds.two > config.starThresholds.one)
            #expect(config.starThresholds.three > config.starThresholds.two)
            #expect(LevelBalanceAnalyzer.warnings(for: config).isEmpty)

            if let mask = config.layout.mask {
                #expect(mask.count == config.rows)
                #expect(mask.allSatisfy { $0.count == config.cols })
                let playable = mask.flatMap { $0 }.filter { $0 }.count
                #expect(playable >= config.layout.blockerCount + config.layout.startingBombs)
            }
        }
    }

    @Test func clearBlockerGoalsNeverFightARisingTide() {
        // "Clear every blocker" only closes if the board stops adding them.
        // Syrup coats a fresh row every N moves, so a tick landing after the
        // player empties the board reopens a goal they had already met.
        for n in 1...Levels.count {
            let config = Levels.config(for: n)
            guard case .clearBlockers = config.goal else { continue }
            #expect(config.layout.syrupTickEvery == nil,
                    "Level \(n) asks to clear all blockers while syrup keeps adding them")
            #expect(config.layout.blockerCount > 0,
                    "Level \(n) asks to clear blockers it never seeds")
        }
    }

    @Test func ringShapeUsesThreeTileInnerLane() {
        let mask = Levels.ring9()

        #expect(mask.count == 9)
        #expect(mask.allSatisfy { $0.count == 9 })
        #expect(mask[0].allSatisfy { $0 })
        #expect(mask[1].allSatisfy { $0 })
        #expect(mask[2].allSatisfy { $0 })
        #expect(mask[6].allSatisfy { $0 })
        #expect(mask[7].allSatisfy { $0 })
        #expect(mask[8].allSatisfy { $0 })

        for r in 3...5 {
            #expect(mask[r][0])
            #expect(mask[r][1])
            #expect(mask[r][2])
            #expect(mask[r][3] == false)
            #expect(mask[r][4] == false)
            #expect(mask[r][5] == false)
            #expect(mask[r][6])
            #expect(mask[r][7])
            #expect(mask[r][8])
        }
    }

    @Test func advancedBlockersAndBoardMovementWork() {
        var blocked: Grid = [[
            Cell(id: "jelly", color: "#F97316", special: nil, kind: .normal,
                 blocker: Blocker(type: .jelly, hits: 1)),
            Cell(id: "crate", color: "#F97316", special: nil, kind: .normal,
                 blocker: Blocker(type: .crate, hits: 3)),
            Cell(id: "lock", color: "#F97316", special: nil, kind: .normal,
                 blocker: Blocker(type: .colorLock, hits: 1, requiredColor: "#F97316"))
        ]]

        let first = Engine.clearMatches(&blocked,
                                        matches: Set([Pos(r: 0, c: 0), Pos(r: 0, c: 1), Pos(r: 0, c: 2)]))
        #expect(first.damagedBlockers.count == 3)
        #expect(blocked[0][0]?.blocker == nil)
        #expect(blocked[0][1]?.blocker?.hits == 2)
        #expect(blocked[0][2]?.blocker == nil)

        let movementGrid: Grid = [[
            Cell(id: "a", color: "#1", special: nil, kind: .normal),
            Cell(id: "b", color: "#2", special: nil, kind: .normal),
            Cell(id: "c", color: "#3", special: nil, kind: .normal)
        ]]
        let portalGrid = Engine.applyPortals(movementGrid,
                                             pairs: [LevelPortal(from: Pos(r: 0, c: 0), to: Pos(r: 0, c: 2))])
        #expect(portalGrid[0][0]?.id == "c")
        #expect(portalGrid[0][2]?.id == "a")

        let conveyorGrid = Engine.applyConveyors(movementGrid,
                                                 belts: [ConveyorBelt(row: 0, direction: 1)])
        #expect(conveyorGrid[0][0]?.id == "c")
        #expect(conveyorGrid[0][1]?.id == "a")
        #expect(conveyorGrid[0][2]?.id == "b")
    }

    @Test func campaignHasChaptersAndRotatingDailyChallenge() {
        #expect(Levels.chapter(for: 1).title == "Sweet Start")
        #expect(Levels.chapter(for: 100).title == "Crown Gate")
        #expect(Levels.chapter(for: 200).title == "Sugar Throne")

        let first = Levels.dailyChallenge(on: Date(timeIntervalSince1970: 1_800_000_000))
        let second = Levels.dailyChallenge(on: Date(timeIntervalSince1970: 1_800_086_400))
        #expect(first.dateKey != second.dateKey)
        #expect(first.level >= 1 && first.level <= Levels.count)
        #expect(second.level >= 1 && second.level <= Levels.count)
        #expect(!first.reward.isEmpty)
    }

    @Test func generatedLevelsUseVariedGoals() {
        var goals = Set<String>()
        var difficulties = Set<LevelDifficulty>()
        var hasJelly = false
        var hasCrates = false
        var hasColorLocks = false
        var hasPortals = false
        var hasConveyors = false
        var hasChests = false
        var hasKeys = false
        var hasVines = false
        var hasModifiers = false
        for n in 1...Levels.count {
            let config = Levels.config(for: n)
            goals.insert(config.goal.title)
            difficulties.insert(config.difficulty)
            hasJelly = hasJelly || config.layout.jellyCount > 0
            hasCrates = hasCrates || config.layout.crateCount > 0
            hasColorLocks = hasColorLocks || config.layout.colorLockCount > 0
            hasPortals = hasPortals || !config.layout.portalPairs.isEmpty
            hasConveyors = hasConveyors || !config.layout.conveyorBelts.isEmpty
            hasChests = hasChests || config.layout.chestCount > 0
            hasKeys = hasKeys || config.layout.keyCount > 0
            hasVines = hasVines || config.layout.vineCount > 0
            hasModifiers = hasModifiers || !config.modifiers.isEmpty
        }

        #expect(goals.contains("Reach score"))
        #expect(goals.contains("Clear blockers"))
        #expect(goals.contains { $0.hasPrefix("Collect") })
        #expect(goals.contains { $0.hasPrefix("Create") })
        #expect(goals.contains { $0.hasPrefix("Detonate") })
        #expect(goals.contains { $0.contains("keys") || $0.contains("chests") })
        #expect(difficulties.contains(.hard))
        #expect(difficulties.contains(.superHard))
        #expect(difficulties.contains(.crownChallenge))
        #expect(hasJelly)
        #expect(hasCrates)
        #expect(hasColorLocks)
        #expect(hasPortals)
        #expect(hasConveyors)
        #expect(hasChests)
        #expect(hasKeys)
        #expect(hasVines)
        #expect(hasModifiers)
    }

    @Test func eventsRewardsAndDesignReportAreAvailable() {
        let saturday = Date(timeIntervalSince1970: 1_799_971_200)
        let events = Levels.activeEvents(on: saturday)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.level >= 1 && $0.level <= Levels.count })
        #expect(events.allSatisfy { !$0.reward.isEmpty })

        #expect(Levels.threeStarReward(for: 25) != nil)
        #expect(Levels.dailyStreakReward(streak: 3) != nil)
        #expect(LevelDesignReport.rows().count == Levels.count)
        #expect(LevelDesignReport.levelsNeedingAttention().isEmpty)
        #expect(LevelDesignReport.csv().contains("level,chapter,difficulty"))
        #expect(LevelDesignReport.csv().contains("cadence,tags"))
    }

    @Test func simulationBotProducesLevelSignals() {
        let summary = LevelSimulationBot.simulate(config: Levels.config(for: 1),
                                                  attempts: 4,
                                                  seed: 123)
        #expect(summary.level == 1)
        #expect(summary.attempts == 4)
        #expect(summary.averageScore > 0)
        #expect(summary.winRate >= 0)
        #expect(summary.winRate <= 1)
        #expect(summary.stuckBoardRate >= 0)
        #expect(summary.stuckBoardRate <= 1)
    }


    @Test func earlyLevelTargetsStayRewardingWithoutHiddenMoveGates() {
        let level1 = Levels.config(for: 1)
        #expect(level1.moves > 20)
        #expect(level1.target >= 1_000)
        #expect(level1.target <= 1_300)
        #expect(level1.starThresholds.two == Int((Double(level1.target) * 1.10).rounded()))
        #expect(level1.starThresholds.three == Int((Double(level1.target) * 1.25).rounded()))

        let level2 = Levels.config(for: 2)
        #expect(level2.target >= 1_600)
        #expect(level2.target <= 1_900)

        let level20 = Levels.config(for: 20)
        #expect(level20.moves >= 34)
        #expect(level20.colors <= 5)
        #expect(level20.target <= 7200)
        #expect(level20.starThresholds.two == Int((Double(level20.target) * 1.12).rounded()))
        #expect(level20.starThresholds.three == Int((Double(level20.target) * 1.30).rounded()))

        let level10 = Levels.config(for: 10)
        #expect(level10.moves >= 30)
        #expect(level10.colors <= 5)
        #expect(level10.target >= 4_800)
        #expect(level10.target <= 5_500)
    }

    @Test func firstTwentyFiveLevelsEstimateAsFairOrBetter() {
        for n in 1...25 {
            let config = Levels.config(for: n)
            let snapshot = LevelBalanceAnalyzer.snapshot(for: config)
            let winRate = LevelBalanceAnalyzer.estimatedWinRate(for: config)
            let stars = LevelBalanceAnalyzer.estimatedAverageStars(for: config)
            #expect(snapshot.warnings.isEmpty)
            #expect(snapshot.estimatedScoreCapacity >= Int(Double(config.target) * 1.08))
            #expect(winRate >= 0.56)
            #expect(LevelBalanceAnalyzer.balanceLabel(winRate: winRate, averageStars: stars) != "Too hard")
        }
    }

    @Test func levelTwentySevenIsReliefAfterBlockerGate() {
        let config = Levels.config(for: 27)
        let snapshot = LevelBalanceAnalyzer.snapshot(for: config)
        let winRate = LevelBalanceAnalyzer.estimatedWinRate(for: config)

        #expect(config.goal == .score)
        #expect(config.difficulty == .normal)
        #expect(config.colors <= 5)
        #expect(config.moves >= 25)
        #expect(config.target <= 6_200)
        #expect(snapshot.warnings.isEmpty)
        #expect(winRate >= 0.65)
    }

    @Test func scoreTargetsStayInsideRealisticMoveBudgets() {
        for n in 11...Levels.count {
            let config = Levels.config(for: n)
            guard case .score = config.goal else { continue }

            let bonusPerMove = Double(config.layout.startingBombs * 220
                + (config.layout.portalPairs.count + config.layout.conveyorBelts.count) * 120)
                / Double(max(1, config.moves))
            let budget: Double
            switch config.difficulty {
            case .normal:
                budget = 285
            case .hard:
                budget = 350
            case .superHard:
                budget = 425
            case .crownChallenge:
                budget = 480
            }

            let targetPerMove = Double(config.target) / Double(max(1, config.moves))
            #expect(targetPerMove <= budget + bonusPerMove + 10)
        }
    }

    @Test func lossEndLevelCardUsesCompactFooterActions() {
        let card = EndLevelCard(outcome: .lose(score: 6_220,
                                               targetText: "Target  9,800",
                                               message: "You were 3,580 points short.",
                                               recommendation: "Save specials for one cascade."),
                                sceneSize: CGSize(width: 390, height: 844))

        let retry = firstNode(named: "primaryBtn", in: card)
        let levels = firstNode(named: "secondaryBtn", in: card)

        #expect(retry != nil)
        #expect(levels != nil)
        if let retry, let levels {
            #expect(abs(retry.position.y - levels.position.y) < 0.5)
            #expect(abs(retry.position.x - levels.position.x) > 80)
        }
    }

    @Test func winEndLevelCardSeparatesMedalsScoreAndRatingFooter() {
        let card = EndLevelCard(outcome: .win(stars: 2,
                                              score: 1_750,
                                              targetText: "2/3 stars earned",
                                              moveBonus: nil),
                                sceneSize: CGSize(width: 390, height: 844),
                                breakdown: EndLevelCard.Breakdown(score: 1_750,
                                                                  moveBonus: EndLevelCard.MoveBonus(moves: 11,
                                                                                                     points: 1_100),
                                                                  objective: "Create 2 specials",
                                                                  rewards: [],
                                                                  threeStarReward: nil,
                                                                  newUnlock: nil),
                                canRetryForStars: true,
                                showRatingRow: true,
                                medals: Persistence.MedalSet(noBoosters: true,
                                                              movesToSpare: true,
                                                              overshotGoal: false))

        let medalRow = firstNode(named: "medalRow", in: card)
        let scoreLine = firstNode(named: "scoreLine", in: card)
        let targetLine = firstNode(named: "targetLine", in: card)
        let primary = firstNode(named: "primaryBtn", in: card)
        let retry = firstNode(named: "retryStarsBtn", in: card)
        let levels = firstNode(named: "secondaryBtn", in: card)
        let thumbsUp = firstNode(named: "thumbsUp", in: card)

        #expect(medalRow != nil)
        #expect(scoreLine != nil)
        #expect(targetLine != nil)
        #expect(primary != nil)
        #expect(retry != nil)
        #expect(levels != nil)
        #expect(thumbsUp != nil)

        if let medalRow, let scoreLine, let targetLine {
            #expect(medalRow.position.y - scoreLine.position.y >= 42)
            #expect(scoreLine.position.y - targetLine.position.y >= 28)
        }
        if let primary, let retry, let levels, let thumbsUp {
            #expect(abs(retry.position.y - levels.position.y) < 0.5)
            #expect(primary.position.y - retry.position.y >= 64)
            #expect(retry.position.y - thumbsUp.position.y >= 42)
        }
    }

    @Test func bonusOfferShowsPendingAndClaimedStates() {
        let card = EndLevelCard(outcome: .win(stars: 3,
                                              score: 2_210,
                                              targetText: "Goal  Create 2 specials",
                                              moveBonus: nil),
                                sceneSize: CGSize(width: 390, height: 844),
                                bonusOffer: EndLevelCard.BonusOffer(title: "Double rewards",
                                                                    subtitle: "Claim the chest again",
                                                                    buttonText: "Watch",
                                                                    enabled: true),
                                breakdown: EndLevelCard.Breakdown(score: 2_210,
                                                                  moveBonus: EndLevelCard.MoveBonus(moves: 15,
                                                                                                     points: 1_500),
                                                                  objective: "Create 2 specials",
                                                                  rewards: [],
                                                                  threeStarReward: "+63 coins",
                                                                  newUnlock: nil),
                                showRatingRow: true)

        let bonusButton = firstNode(named: "bonusBtn", in: card)
        let buttonLabel = firstNode(named: "bonusButtonLabel", in: card) as? SKLabelNode
        let subtitle = firstNode(named: "bonusSubtitleLabel", in: card) as? SKLabelNode

        #expect(bonusButton != nil)
        #expect(buttonLabel?.text == "Watch")

        card.beginBonusRequest()

        #expect(firstNode(named: "bonusPending", in: card) != nil)
        #expect(buttonLabel?.text == "Opening...")
        #expect(subtitle?.text == "Opening ad...")

        card.markBonusCompleted(title: "Rewards doubled", subtitle: "Added +63 coins")

        #expect(firstNode(named: "bonusClaimed", in: card) != nil)
        #expect(buttonLabel?.text == "Claimed")
        #expect(subtitle?.text == "Added +63 coins")
    }

    @Test func nonScoreGoalsUseObjectiveMasteryForStars() {
        let config = Levels.config(for: 128)
        #expect(config.goal != .score)
        #expect(LevelScoring.previewSummary(for: config).contains("objective"))
        #expect(config.target < 80_000)

        let normalClear = LevelAttemptPerformance(score: config.target / 2,
                                                  movesLeft: max(1, config.moves / 5),
                                                  movesAtStart: config.moves,
                                                  maxCascadeDepth: 2,
                                                  createdSpecials: 2,
                                                  detonatedBombs: 0,
                                                  objectiveProgress: 1)
        #expect(LevelScoring.stars(for: config, performance: normalClear, won: true) >= 2)

        let masteryClear = LevelAttemptPerformance(score: config.target,
                                                   movesLeft: max(2, config.moves / 3),
                                                   movesAtStart: config.moves,
                                                   maxCascadeDepth: 4,
                                                   createdSpecials: 4,
                                                   detonatedBombs: 1,
                                                   objectiveProgress: 1)
        #expect(LevelScoring.stars(for: config, performance: masteryClear, won: true) == 3)
    }

    @Test func storeProductFallbackPricesMatchLocalStoreKitConfig() {
        #expect(CoinProduct.small.fallbackPrice == "$0.99")
        #expect(CoinProduct.large.fallbackPrice == "$4.99")
        #expect(Monetization.coinPackButtonText(.small, displayPrice: "$0.99") == "$0.99")
        #expect(Monetization.coinPackButtonText(.large, displayPrice: "$4.99") == "$4.99")
        #expect(Monetization.coinPackSubtitle(.small) == "+500 coins")
        #expect(Monetization.coinPackSubtitle(.large) == "+5000 coins")
        #expect(Monetization.rewardedAdButtonText == "Watch")
        #expect(Monetization.rewardedAdSubtitle == "+120 coins")
    }

    @Test func rewardedAdCooldownEscalatesAndResetsEachDay() {
        Persistence.resetDailyAndEventState()
        let calendar = Calendar.current
        let firstWatch = calendar.date(from: DateComponents(year: 2026,
                                                            month: 5,
                                                            day: 21,
                                                            hour: 9,
                                                            minute: 0,
                                                            second: 0))!

        #expect(Persistence.rewardedAdGate(now: firstWatch).isAvailable)
        Persistence.recordRewardedAdWatched(now: firstWatch)

        let firstCooldown = Persistence.rewardedAdGate(now: firstWatch.addingTimeInterval(1))
        #expect(!firstCooldown.isAvailable)
        #expect(firstCooldown.secondsRemaining > 298)
        #expect(firstCooldown.secondsRemaining <= 300)

        let secondWatch = firstWatch.addingTimeInterval(5 * 60 + 1)
        #expect(Persistence.rewardedAdGate(now: secondWatch).isAvailable)
        Persistence.recordRewardedAdWatched(now: secondWatch)

        let secondCooldown = Persistence.rewardedAdGate(now: secondWatch.addingTimeInterval(1))
        #expect(!secondCooldown.isAvailable)
        #expect(secondCooldown.secondsRemaining > 1_798)
        #expect(secondCooldown.secondsRemaining <= 1_800)

        let nextDay = calendar.date(from: DateComponents(year: 2026,
                                                         month: 5,
                                                         day: 22,
                                                         hour: 0,
                                                         minute: 1,
                                                         second: 0))!
        let resetGate = Persistence.rewardedAdGate(now: nextDay)
        #expect(resetGate.isAvailable)
        #expect(resetGate.watchedToday == 0)
        Persistence.resetDailyAndEventState()
    }

    @Test func settingsCardIgnoresTouchEndThatOpenedIt() {
        let card = SettingsCard(sceneSize: CGSize(width: 390, height: 844))
        var didClose = false
        card.onAction = { action in
            if case .close = action {
                didClose = true
            }
        }

        _ = card.handleTouchEnded(at: CGPoint(x: 180, y: 360), timestamp: 1)
        #expect(didClose == false)

        _ = card.handleTouchBegan(at: CGPoint(x: 180, y: 360), timestamp: 2)
        _ = card.handleTouchEnded(at: CGPoint(x: 180, y: 360), timestamp: 3)
        #expect(didClose == true)
    }

    @Test func continueOfferRequiresValuableNearMissAndNoRepeat() {
        #expect(Monetization.qualifiesForContinueOffer(level: 4,
                                                       score: 66,
                                                       target: 100,
                                                       alreadyUsed: false))
        #expect(!Monetization.qualifiesForContinueOffer(level: 3,
                                                        score: 90,
                                                        target: 100,
                                                        alreadyUsed: false))
        #expect(!Monetization.qualifiesForContinueOffer(level: 4,
                                                        score: 40,
                                                        target: 100,
                                                        alreadyUsed: false))
        #expect(!Monetization.qualifiesForContinueOffer(level: 4,
                                                        score: 90,
                                                        target: 100,
                                                        alreadyUsed: true))
    }

    @Test func analyticsAggregatesLevelDifficultySignals() {
        Analytics.resetLevelStats()
        Analytics.track("level_start", properties: ["level": "3", "target": "1200"])
        Analytics.track("booster_use", properties: ["level": "3", "type": "hammer"])
        Analytics.track("level_fail", properties: ["level": "3", "score": "900", "target": "1200"])
        Analytics.track("level_start", properties: ["level": "3", "target": "1200"])
        Analytics.track("level_win", properties: ["level": "3", "score": "1500", "target": "1200", "stars": "2", "moves_left": "4"])

        let stats = Analytics.levelStats(for: 3)
        #expect(stats["attempts"] == 2)
        #expect(stats["fails"] == 1)
        #expect(stats["wins"] == 1)
        #expect(stats["booster_uses"] == 1)
        #expect(stats["fail_score_gap_total"] == 300)
        #expect(stats["stars_total"] == 2)
        #expect(stats["moves_left_total"] == 4)
    }

    @Test func persistenceClampsLevelAndPreservesBestStars() {
        Persistence.resetAll()
        Persistence.currentLevel = Levels.count + 50
        #expect(Persistence.currentLevel == Levels.count)

        Persistence.recordStars(2, for: 4)
        Persistence.recordStars(1, for: 4)
        #expect(Persistence.starsForLevel(4) == 2)
        #expect(Persistence.highestUnlockedLevel >= 5)

        #expect(Levels.milestoneReward(for: 10) != nil)
        #expect(!Persistence.hasClaimedMilestoneReward(for: 10))
        Persistence.markMilestoneRewardClaimed(for: 10)
        #expect(Persistence.hasClaimedMilestoneReward(for: 10))

        #expect(!Persistence.hasClaimedThreeStarReward(for: 4))
        Persistence.markThreeStarRewardClaimed(for: 4)
        #expect(Persistence.hasClaimedThreeStarReward(for: 4))

        Persistence.unlockTheme("Test Theme")
        #expect(Persistence.unlockedThemes().contains("Test Theme"))

        Persistence.markStoreKitTransactionDelivered("tx-test")
        #expect(Persistence.hasDeliveredStoreKitTransaction("tx-test"))

        Persistence.resetAll()
        #expect(Persistence.currentLevel == 1)
        #expect(Persistence.starsForLevel(4) == 0)
        #expect(!Persistence.hasClaimedMilestoneReward(for: 10))
        #expect(!Persistence.hasClaimedThreeStarReward(for: 4))
        #expect(!Persistence.unlockedThemes().contains("Test Theme"))
        #expect(!Persistence.hasDeliveredStoreKitTransaction("tx-test"))
    }

    @Test func backendStateMergesProgressAndPurchaseLedger() {
        Persistence.resetAll()
        Persistence.currentLevel = 3
        Persistence.cash = 100
        Persistence.recordStars(2, for: 6)
        Persistence.markStoreKitTransactionDelivered("local-tx")

        let remote = Persistence.BackendState(
            clientUpdatedAt: Date().timeIntervalSince1970 + 100,
            currentLevel: 8,
            totalScore: 4_500,
            cash: 2_000,
            lives: 4,
            lifeReferenceAt: nil,
            shuffleCount: 7,
            movesQuantity: 9,
            hammerCount: 5,
            swapCount: 6,
            piggyCoins: 120,
            coinDoublerExpiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970,
            dailyRewardDate: "2026-05-10",
            dailyAdBonusDate: "2026-05-10",
            dailyStreak: 3,
            unlockedThemes: ["Cloud Theme"],
            deliveredStoreKitTransactionIDs: ["remote-tx"],
            stars: ["6": 3],
            claimedRewards: ["10": true],
            claimedThreeStarRewards: ["6": true],
            claimedEventRewards: ["weekend": true],
            claimedBossRewards: ["10": true]
        )

        Persistence.applyBackendState(remote)

        #expect(Persistence.currentLevel == 8)
        #expect(Persistence.cash == 2_000)
        #expect(Persistence.shuffleCount == 7)
        #expect(Persistence.hammerCount == 5)
        #expect(Persistence.swapCount == 6)
        #expect(Persistence.starsForLevel(6) == 3)
        #expect(Persistence.hasDeliveredStoreKitTransaction("local-tx"))
        #expect(Persistence.hasDeliveredStoreKitTransaction("remote-tx"))
        #expect(Persistence.hasClaimedMilestoneReward(for: 10))
        #expect(Persistence.hasClaimedThreeStarReward(for: 6))
        #expect(Persistence.hasClaimedEventReward("weekend"))
        #expect(Persistence.hasClaimedBossReward(for: 10))

        let exported = Persistence.exportBackendState()
        #expect(exported.deliveredStoreKitTransactionIDs.contains("local-tx"))
        #expect(exported.deliveredStoreKitTransactionIDs.contains("remote-tx"))
        #expect(exported.stars["6"] == 3)

        Persistence.resetAll()
    }

    // MARK: - New mechanics

    @Test func chocolateSpreadsToOneEmptyNeighbor() {
        // 2x2 grid: chocolate top-left, plain neighbors elsewhere.
        let grid: Grid = [
            [Cell(id: "c0", color: "#F97316", special: nil, kind: .normal,
                  blocker: Blocker(type: .chocolate, hits: 1)),
             Cell(id: "n0", color: "#22C55E", special: nil, kind: .normal)],
            [Cell(id: "n1", color: "#22C55E", special: nil, kind: .normal),
             Cell(id: "n2", color: "#3B82F6", special: nil, kind: .normal)]
        ]
        let (next, spreadTo) = Engine.spreadChocolate(grid) { _ in 0 }
        #expect(spreadTo != nil)
        if let p = spreadTo {
            #expect(next[p.r][p.c]?.blocker?.type == .chocolate)
        }
        // Source still chocolate after spread.
        #expect(next[0][0]?.blocker?.type == .chocolate)
    }

    @Test func chocolateDoesNotSpreadOnEmptyBoard() {
        let grid: Grid = [[
            Cell(id: "p", color: "#F97316", special: nil, kind: .normal)
        ]]
        let (_, spreadTo) = Engine.spreadChocolate(grid) { _ in 0 }
        #expect(spreadTo == nil)
    }

    @Test func smartHintPrefersSpecialCreation() {
        // Row of 3 same-color tiles with a 4th nearby that becomes a 4-match
        // when swapped — should produce a striped special and beat any plain
        // 3-match alternative.
        let grid: Grid = [[
            Cell(id: "1", color: "#F97316", special: nil, kind: .normal),
            Cell(id: "2", color: "#F97316", special: nil, kind: .normal),
            Cell(id: "3", color: "#F97316", special: nil, kind: .normal),
            Cell(id: "4", color: "#22C55E", special: nil, kind: .normal),
            Cell(id: "5", color: "#F97316", special: nil, kind: .normal)
        ]]
        let hint = Engine.findHintMove(grid)
        #expect(hint != nil)
        if let (a, b) = hint {
            #expect(a == Pos(r: 0, c: 3) || b == Pos(r: 0, c: 3))
        }
    }

    @Test func ingredientDropsOffBottomRow() {
        let grid: Grid = [
            [Cell(id: "p", color: "#F97316", special: nil, kind: .normal),
             Cell(id: "q", color: "#22C55E", special: nil, kind: .normal)],
            [Cell(id: "i", color: "#F97316", special: nil, kind: .ingredient),
             Cell(id: "n", color: "#3B82F6", special: nil, kind: .normal)]
        ]
        let (next, collected) = Engine.collectIngredientsAtBottom(grid)
        #expect(collected == Set([Pos(r: 1, c: 0)]))
        #expect(next[1][0] == nil)
        #expect(next[1][1] != nil)
    }

    @Test func ingredientNotCollectedAboveBottom() {
        let grid: Grid = [
            [Cell(id: "i", color: "#F97316", special: nil, kind: .ingredient)],
            [Cell(id: "p", color: "#22C55E", special: nil, kind: .normal)]
        ]
        let (next, collected) = Engine.collectIngredientsAtBottom(grid)
        #expect(collected.isEmpty)
        #expect(next[0][0]?.kind == .ingredient)
    }

    @Test func livesRegenAndPiggyAndDoublerWorkEndToEnd() {
        Persistence.resetAll()

        // Lives: spending a life starts the timer; reading after a delay
        // returns the materialized count (we can't easily fast-forward time,
        // but we can verify the immediate baseline + countdown text format).
        Persistence.lives = Economy.livesMax
        Persistence.lives = Economy.livesMax - 1
        #expect(Persistence.lives == Economy.livesMax - 1)
        #expect(Persistence.secondsUntilNextLife > 0)
        #expect(Persistence.secondsUntilNextLife <= Economy.lifeRegenInterval + 1)
        #expect(!Persistence.nextLifeCountdownText.isEmpty)

        // Setting back to max clears the timer.
        Persistence.lives = Economy.livesMax
        #expect(Persistence.secondsUntilNextLife == 0)
        #expect(Persistence.nextLifeCountdownText.isEmpty)

        // Piggy: capped at the configured maximum.
        Persistence.addToPiggy(Economy.piggyMax + 500)
        #expect(Persistence.piggyCoins == Economy.piggyMax)
        #expect(Persistence.piggyIsFull)
        let pot = Persistence.emptyPiggy()
        #expect(pot == Economy.piggyMax)
        #expect(Persistence.piggyCoins == 0)

        // Coin doubler: inactive by default; extending makes it active and
        // doubles credited coins.
        #expect(!Persistence.coinDoublerActive)
        #expect(Persistence.applyCoinDoubler(50) == 50)
        Persistence.extendCoinDoubler(hours: 1)
        #expect(Persistence.coinDoublerActive)
        #expect(Persistence.applyCoinDoubler(50) == 100)

        Persistence.resetAll()
        #expect(Persistence.piggyCoins == 0)
        #expect(!Persistence.coinDoublerActive)
    }

    @Test func bossLevelsHaveExtraReward() {
        let cfg10 = Levels.config(for: 10)
        let cfg9 = Levels.config(for: 9)
        #expect(cfg10.isBoss)
        #expect(!cfg9.isBoss)
        #expect(Levels.bossReward(for: 10) != nil)
        #expect(Levels.bossReward(for: 9) == nil)
        if let bonus = Levels.bossReward(for: 100) {
            #expect(bonus.coins > 0)
            #expect(!bonus.isEmpty)
        }
    }

    @Test func chestsKeysAndVinesSeedIntoGeneratedBoards() {
        let chestLevel = (1...Levels.count).first { Levels.config(for: $0).layout.chestCount > 0 }
        let keyLevel = (1...Levels.count).first { Levels.config(for: $0).layout.keyCount > 0 }
        let vineLevel = (1...Levels.count).first { Levels.config(for: $0).layout.vineCount > 0 }

        #expect(chestLevel != nil)
        #expect(keyLevel != nil)
        #expect(vineLevel != nil)

        if let chestLevel {
            let config = Levels.config(for: chestLevel)
            let build = LevelBoardFactory.makeInitialBoard(config: config,
                                                           seed: LevelSeed.make(level: chestLevel, salt: 404),
                                                           minimumOpeningMoveScore: 0,
                                                           attempts: 1)
            let chests = build.grid.flatMap { $0 }.filter { $0?.blocker?.type == .chest }.count
            #expect(chests == config.layout.chestCount)
        }

        if let keyLevel {
            let config = Levels.config(for: keyLevel)
            let build = LevelBoardFactory.makeInitialBoard(config: config,
                                                           seed: LevelSeed.make(level: keyLevel, salt: 405),
                                                           minimumOpeningMoveScore: 0,
                                                           attempts: 1)
            let keys = build.grid.flatMap { $0 }.filter { $0?.kind == .key }.count
            #expect(keys == config.layout.keyCount)
        }

        if let vineLevel {
            let config = Levels.config(for: vineLevel)
            let build = LevelBoardFactory.makeInitialBoard(config: config,
                                                           seed: LevelSeed.make(level: vineLevel, salt: 406),
                                                           minimumOpeningMoveScore: 0,
                                                           attempts: 1)
            let vines = build.grid.flatMap { $0 }.filter { $0?.blocker?.type == .vine }.count
            #expect(vines == config.layout.vineCount)
        }
    }

    @Test func keysCollectAtBottomAndOpenChests() {
        var grid: Grid = [
            [
                Cell(id: "a", color: "#F97316", special: nil, kind: .normal),
                Cell(id: "b", color: "#F97316", special: nil, kind: .normal,
                     blocker: Blocker(type: .chest, hits: 1))
            ],
            [
                Cell(id: "key", color: "#FACC15", special: nil, kind: .key),
                Cell(id: "c", color: "#F97316", special: nil, kind: .normal)
            ]
        ]

        let keyResult = Engine.collectKeysAtBottom(grid)
        grid = keyResult.0
        #expect(keyResult.1 == Set([Pos(r: 1, c: 0)]))
        #expect(grid[1][0] == nil)

        let opened = Engine.openFirstChest(&grid)
        #expect(opened == Pos(r: 0, c: 1))
        #expect(grid[0][1]?.blocker == nil)
    }

    @Test func nearbyMatchOpensChestAndBiggerSpecialsExpandBlast() {
        var grid: Grid = [[
            Cell(id: "a", color: "#F97316", special: nil, kind: .normal),
            Cell(id: "b", color: "#F97316", special: nil, kind: .normal,
                 blocker: Blocker(type: .chest, hits: 1)),
            Cell(id: "c", color: "#F97316", special: nil, kind: .normal)
        ]]

        let opened = Engine.openAdjacentChests(&grid, near: Set([Pos(r: 0, c: 0)]))
        #expect(opened == Set([Pos(r: 0, c: 1)]))
        #expect(grid[0][1]?.blocker == nil)

        let bomb = Pos(r: 2, c: 2)
        let blastGrid: Grid = (0..<5).map { r in
            (0..<5).map { c in
                Cell(id: "\(r)-\(c)",
                     color: "#F97316",
                     special: r == bomb.r && c == bomb.c ? .bomb : nil,
                     kind: .normal)
            }
        }
        let normal = Engine.expandMatchesWithSpecials(blastGrid, Set([bomb]), bigger: false)
        let bigger = Engine.expandMatchesWithSpecials(blastGrid, Set([bomb]), bigger: true)
        #expect(normal.count == 9)
        #expect(bigger.count == 25)
    }

    @Test func ingredientGoalAppearsInGeneratedCatalog() {
        var hasIngredientGoal = false
        var hasIngredientLayout = false
        for n in 1...Levels.count {
            let cfg = Levels.config(for: n)
            if cfg.layout.ingredientCount > 0 { hasIngredientLayout = true }
            if case .collectIngredients = cfg.goal { hasIngredientGoal = true }
        }
        #expect(hasIngredientLayout)
        #expect(hasIngredientGoal)
    }

    private func boardSignature(_ grid: Grid) -> [String] {
        grid.flatMap { row in
            row.map { cell in
                guard let cell else { return "hole" }
                let kind: String
                switch cell.kind {
                case .normal: kind = "normal"
                case .ingredient: kind = "ingredient"
                case .key: kind = "key"
                }
                let blocker = cell.blocker.map {
                    "\($0.type)-\($0.hits)-\($0.requiredColor ?? "")"
                } ?? "none"
                return [
                    cell.color,
                    cell.special?.rawValue ?? "none",
                    kind,
                    blocker
                ].joined(separator: ":")
            }
        }
    }

    private func firstNode(named name: String, in node: SKNode) -> SKNode? {
        if node.name == name { return node }
        for child in node.children {
            if let found = firstNode(named: name, in: child) {
                return found
            }
        }
        return nil
    }

    @Test func medalBitmaskRoundTripsAllCombinations() {
        for bits in 0...7 {
            let set = Persistence.MedalSet(bitmask: bits)
            #expect(set.bitmask == bits)
            #expect(set.count == [set.noBoosters, set.movesToSpare, set.overshotGoal]
                .filter { $0 }.count)
        }
    }

    @Test func syrupBlockerClearsOnDirectHit() {
        var grid: Grid = [[
            Cell(id: "a", color: "#F97316", special: nil, kind: .normal,
                 blocker: Blocker(type: .syrup, hits: 1))
        ]]
        let result = Engine.clearMatches(&grid, matches: Set([Pos(r: 0, c: 0)]))
        #expect(result.cleared.isEmpty)
        #expect(result.damagedBlockers == Set([Pos(r: 0, c: 0)]))
        #expect(grid[0][0]?.blocker == nil)

        let second = Engine.clearMatches(&grid, matches: Set([Pos(r: 0, c: 0)]))
        #expect(second.cleared == Set([Pos(r: 0, c: 0)]))
        #expect(grid[0][0] == nil)
    }

    @Test func syrupLevelSeedingIsRare() {
        var syrupLevels = 0
        for n in 1...Levels.count {
            if Levels.config(for: n).layout.syrupTickEvery != nil {
                syrupLevels += 1
            }
        }
        // Late-campaign only, every 13 levels at most — so under 12% of the
        // catalog should be syrup levels (it's a *special* mechanic, not a
        // baseline).
        #expect(syrupLevels > 0)
        #expect(syrupLevels < Levels.count / 8)
    }

    @Test func dailyChallengeIsSharedAndDeterministic() {
        // Same instant → same key, number, level, and seed. Different days →
        // different boards. The seed must not depend on process-randomized
        // hashing or the user's calendar.
        let noon = Date(timeIntervalSince1970: 1_780_000_000)
        let a = Levels.dailyChallenge(on: noon)
        let b = Levels.dailyChallenge(on: noon.addingTimeInterval(3_600))
        #expect(a.dateKey == b.dateKey)
        #expect(a.seed == b.seed)
        #expect(a.number == b.number)
        #expect(a.level == b.level)

        let nextDay = Levels.dailyChallenge(on: noon.addingTimeInterval(86_400 * 2))
        #expect(nextDay.seed != a.seed)
        #expect(nextDay.number > a.number)

        #expect(LevelSeed.dailySeed(dateKey: "2026-06-11", level: 42)
             == LevelSeed.dailySeed(dateKey: "2026-06-11", level: 42))
        #expect(LevelSeed.dailySeed(dateKey: "2026-06-11", level: 42)
             != LevelSeed.dailySeed(dateKey: "2026-06-12", level: 42))

        // The full board build pipeline must reproduce identical grids from
        // the daily seed — this is the "everyone plays the same board" promise.
        let config = Levels.config(for: a.level)
        let first = LevelBoardFactory.makeInitialBoard(config: config, seed: a.seed)
        let second = LevelBoardFactory.makeInitialBoard(config: config, seed: a.seed)
        #expect(first.seed == second.seed)
        #expect(DailyShare.emojiGrid(for: first.grid) == DailyShare.emojiGrid(for: second.grid))
        #expect(!DailyShare.emojiGrid(for: first.grid).isEmpty)
    }

    @Test func dailyShareTextContainsResultAndBoard() {
        let challenge = Levels.dailyChallenge(on: Date(timeIntervalSince1970: 1_780_000_000))
        let config = Levels.config(for: challenge.level)
        let board = LevelBoardFactory.makeInitialBoard(config: config, seed: challenge.seed)
        let text = DailyShare.shareText(challenge: challenge,
                                        stars: 3,
                                        score: 12_345,
                                        movesToSpare: 4,
                                        startGrid: board.grid)
        #expect(text.contains("#\(challenge.number)"))
        #expect(text.contains("⭐⭐⭐"))
        #expect(text.contains(DailyShare.emojiGrid(for: board.grid)))
    }

    @Test func squareMatchesDetectAndFormFish() {
        func cell(_ color: String) -> Cell {
            Cell(id: color + "-\(Int.random(in: 0..<999999))", color: color, special: nil, kind: .normal)
        }
        // A 2x2 same-colour block in the top-left, nothing else uniform.
        let grid: Grid = [
            [cell("R"), cell("R"), cell("B")],
            [cell("R"), cell("R"), cell("G")],
            [cell("Y"), cell("B"), cell("G")]
        ]
        #expect(Engine.findSquares(grid).count == 1)
        #expect(Engine.createsSquare(grid, at: Pos(r: 0, c: 0)))
        #expect(!Engine.createsSquare(grid, at: Pos(r: 2, c: 2)))

        // A swap that forms a 2x2 (no 3-line) must count as a valid move.
        let g2: Grid = [
            [cell("R"), cell("R"), cell("B")],
            [cell("R"), cell("B"), cell("R")],
            [cell("Y"), cell("G"), cell("P")]
        ]
        let result = Engine.swapIfValid(g2, Pos(r: 1, c: 1), Pos(r: 1, c: 2))
        #expect(result.didSwap)

        // An unchanged square is not a legal move. This protects against stale
        // pre-matches accepting a swap of two identical cells.
        let unchanged = Engine.swapIfValid(grid, Pos(r: 0, c: 0), Pos(r: 0, c: 1))
        #expect(!unchanged.didSwap)
    }

    @Test func simulationResolvesSquareMatchesAndCreatesFish() {
        func cell(_ id: String, _ color: String) -> Cell {
            Cell(id: id, color: color, special: nil, kind: .normal)
        }
        var grid: Grid = [
            [cell("a", "R"), cell("b", "R"), cell("c", "B")],
            [cell("d", "R"), cell("e", "R"), cell("f", "G")],
            [cell("g", "Y"), cell("h", "B"), cell("i", "P")]
        ]
        var rng = SeededRandomNumberGenerator(seed: 42)
        var score = 0
        var collectedGoalTiles = 0
        var createdSpecials = 0
        var detonatedBombs = 0
        var collectedIngredients = 0
        var collectedKeys = 0
        var openedChests = 0

        let depth = LevelSimulationBot.resolveCascades(
            config: Levels.config(for: 1),
            grid: &grid,
            rng: &rng,
            score: &score,
            collectedGoalTiles: &collectedGoalTiles,
            createdSpecials: &createdSpecials,
            detonatedBombs: &detonatedBombs,
            collectedIngredients: &collectedIngredients,
            collectedKeys: &collectedKeys,
            openedChests: &openedChests
        )

        #expect(depth >= 1)
        #expect(score > 0)
        #expect(createdSpecials >= 1)
    }

    @Test func widgetLifeScheduleAdvancesUntilFull() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let firstLife = now.addingTimeInterval(60)
        let snapshot = WidgetSharedState.Snapshot(dateKey: "2033-05-18",
                                                  number: 1,
                                                  level: 1,
                                                  claimed: false,
                                                  streak: 0,
                                                  lives: 2,
                                                  livesMax: 5,
                                                  nextLifeAt: firstLife,
                                                  regenSeconds: 60)

        let dates = snapshot.regenerationDates(after: now,
                                               before: now.addingTimeInterval(600))
        #expect(dates == [
            firstLife,
            firstLife.addingTimeInterval(60),
            firstLife.addingTimeInterval(120)
        ])
        #expect(snapshot.livesNow(at: dates[0]) == 3)
        #expect(snapshot.livesNow(at: dates[2]) == 5)
    }

    @Test func liveActivityStateMaterializesRegeneratedLives() {
        guard #available(iOS 16.1, *) else { return }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let firstLife = now.addingTimeInterval(60)
        let state = LifeRegenAttributes.ContentState(lives: 2,
                                                     nextLifeAt: firstLife,
                                                     fullAt: firstLife.addingTimeInterval(120),
                                                     regenSeconds: 60)

        #expect(state.lives(at: now, maximum: 5) == 2)
        #expect(state.lives(at: firstLife, maximum: 5) == 3)
        #expect(state.lives(at: firstLife.addingTimeInterval(120), maximum: 5) == 5)
        #expect(state.nextLife(after: firstLife, maximum: 5)
                == firstLife.addingTimeInterval(60))
        #expect(state.nextLife(after: firstLife.addingTimeInterval(120), maximum: 5) == nil)
    }

    // MARK: - Sugar Tower

    @Test func towerFloorsAreDeterministicAndEscalate() {
        let week = "2100-W01"
        let a = TowerMode.floorConfig(weekKey: week, floor: 4, perks: [])
        let b = TowerMode.floorConfig(weekKey: week, floor: 4, perks: [])
        #expect(a.moves == b.moves && a.target == b.target && a.rows == b.rows)
        #expect(a.layout.blockerCount == b.layout.blockerCount)
        #expect(TowerMode.floorSeed(weekKey: week, floor: 4)
                == TowerMode.floorSeed(weekKey: week, floor: 4))
        #expect(TowerMode.floorSeed(weekKey: week, floor: 4)
                != TowerMode.floorSeed(weekKey: week, floor: 5))
        #expect(TowerMode.floorSeed(weekKey: "2100-W02", floor: 4)
                != TowerMode.floorSeed(weekKey: week, floor: 4))

        let early = TowerMode.floorConfig(weekKey: week, floor: 1, perks: [])
        let late = TowerMode.floorConfig(weekKey: week, floor: 12, perks: [])
        #expect(late.target > early.target)
        #expect(late.moves < early.moves)
        #expect(late.rows >= early.rows && late.colors >= early.colors)
        #expect(late.layout.blockerCount > 0)
        // Boosters are locked on every floor; the sentinel routes configs.
        #expect(early.modifiers.contains(.noBoosters) && late.modifiers.contains(.noBoosters))
        #expect(early.number == Levels.towerLevel && late.number == Levels.towerLevel)

        let weekKey = TowerMode.weekKey(for: Date(timeIntervalSince1970: 4_102_444_800))
        #expect(weekKey.count == 8 && weekKey.contains("-W"))
    }

    @Test func towerPerksShapeTheFloorConfig() {
        let week = "2100-W01"
        let plain = TowerMode.floorConfig(weekKey: week, floor: 6, perks: [])
        let perked = TowerMode.floorConfig(
            weekKey: week, floor: 6,
            perks: [.extraMoves, .extraMoves, .startBomb, .sweetSimplicity, .biggerBlasts])
        #expect(perked.moves == plain.moves + 6)
        #expect(perked.layout.startingBombs == 1)
        #expect(perked.colors == max(4, plain.colors - 1))
        #expect(perked.modifiers.contains(.specialsExplodeBigger))
        #expect(!plain.modifiers.contains(.specialsExplodeBigger))
    }

    @Test func towerPerkChoicesAreDeterministicAndDistinct() {
        let a = TowerMode.perkChoices(weekKey: "2100-W01", floor: 3)
        let b = TowerMode.perkChoices(weekKey: "2100-W01", floor: 3)
        #expect(a == b)
        #expect(a.count == 3 && Set(a).count == 3)
    }

    @Test func towerPerkStacksAreCapped() {
        let week = "2100-W01"
        let maxed = Array(repeating: TowerPerk.extraMoves, count: TowerPerk.maxStacks)

        // A maxed perk stops being offered, so the draft keeps presenting a
        // live decision instead of the same dominant card.
        let choices = TowerMode.perkChoices(weekKey: week, floor: 6, owned: maxed)
        #expect(!choices.contains(.extraMoves))
        #expect(choices.count == 3 && Set(choices).count == 3)
        // With nothing owned the full table is still on offer.
        #expect(TowerMode.perkChoices(weekKey: week, floor: 6, owned: []).count == 3)
        // Every perk maxed reopens the table rather than drafting nothing.
        let allMaxed = TowerPerk.allCases.flatMap {
            Array(repeating: $0, count: TowerPerk.maxStacks)
        }
        #expect(TowerMode.perkChoices(weekKey: week, floor: 6, owned: allMaxed).count == 3)

        // Extra copies past the cap buy nothing, so the escalation curve holds:
        // a hoarded stack cannot outrun the shrinking move budget.
        let capped = TowerMode.floorConfig(weekKey: week, floor: 12, perks: maxed)
        let hoarded = TowerMode.floorConfig(
            weekKey: week, floor: 12,
            perks: Array(repeating: TowerPerk.extraMoves, count: 12))
        #expect(capped.moves == hoarded.moves)
        let plain = TowerMode.floorConfig(weekKey: week, floor: 12, perks: [])
        #expect(capped.moves == plain.moves + 3 * TowerPerk.maxStacks)

        // The same cap applies to the other stacking perks.
        let bombs = Array(repeating: TowerPerk.startBomb, count: 9)
        #expect(TowerMode.floorConfig(weekKey: week, floor: 12, perks: bombs)
                    .layout.startingBombs == TowerPerk.maxStacks)
        let gold = Array(repeating: TowerPerk.goldRush, count: 9)
        #expect(TowerMode.coinReward(floor: 4, perks: gold)
                == TowerMode.coinReward(floor: 4,
                                        perks: Array(repeating: TowerPerk.goldRush,
                                                     count: TowerPerk.maxStacks)))
    }

    @Test func towerCoinRewardScalesWithMilestonesAndGoldRush() {
        #expect(TowerMode.coinReward(floor: 1, perks: []) == 40)
        #expect(TowerMode.coinReward(floor: 5, perks: []) == 180)
        #expect(TowerMode.coinReward(floor: 1, perks: [.goldRush]) == 60)
    }

    @Test func towerRunPersistsAndEndsWithBestFloor() {
        let d = UserDefaults.standard
        let savedBest = Persistence.towerBestFloor
        let savedRun = TowerMode.activeRun()
        defer {
            Persistence.towerBestFloor = savedBest
            if let savedRun {
                TowerMode.save(savedRun)
            } else {
                d.removeObject(forKey: Persistence.K.towerFloor)
                d.removeObject(forKey: Persistence.K.towerPerks)
                d.removeObject(forKey: Persistence.K.towerRunCoins)
                d.removeObject(forKey: Persistence.K.towerWeek)
            }
        }

        var run = TowerMode.startNewRun()
        #expect(run.floor == 1 && run.perks.isEmpty && run.coinsEarned == 0)

        run.floor = 7
        run.perks = [.goldRush, .extraMoves]
        run.coinsEarned = 300
        TowerMode.save(run)
        #expect(TowerMode.activeRun() == run)

        Persistence.towerBestFloor = 3
        TowerMode.endRun(run)
        #expect(TowerMode.activeRun() == nil)
        // Floor 7 was in progress, so 6 were cleared — beats the old best of 3.
        #expect(Persistence.towerBestFloor == 6)
    }

    @Test func towerAbandonedFloorEndsTheRun() {
        let d = UserDefaults.standard
        let savedBest = Persistence.towerBestFloor
        let savedRun = TowerMode.activeRun()
        defer {
            Persistence.towerBestFloor = savedBest
            if let savedRun {
                TowerMode.save(savedRun)
            } else {
                for key in [Persistence.K.towerFloor, Persistence.K.towerPerks,
                            Persistence.K.towerRunCoins, Persistence.K.towerWeek,
                            Persistence.K.towerFloorLive] {
                    d.removeObject(forKey: key)
                }
            }
        }

        // Between floors the run resumes untouched — that is what keeps
        // "Take a break (run saved)" an honest offer.
        var run = TowerMode.startNewRun()
        run.floor = 5
        TowerMode.save(run)
        Persistence.towerBestFloor = 0
        #expect(TowerMode.resume() == TowerResume(run: run, abandonedFloor: nil))
        #expect(TowerMode.activeRun()?.floor == 5)

        // Spending a move on the floor commits the player to finishing it.
        TowerMode.markFloorInProgress()
        #expect(TowerMode.activeRun()?.floorInProgress == true)

        // Walking out of that floor is a loss: the run ends and only the four
        // floors actually cleared count toward the best.
        let resumed = TowerMode.resume()
        #expect(resumed.run == nil)
        #expect(resumed.abandonedFloor == 5)
        #expect(TowerMode.activeRun() == nil)
        #expect(Persistence.towerBestFloor == 4)

        // The flag must not leak into the next run.
        let fresh = TowerMode.startNewRun()
        #expect(fresh.floorInProgress == false)
        #expect(TowerMode.resume().run?.floorInProgress == false)
    }

    @Test func towerFloorGoalsRotateAndStayFeasible() {
        let week = "2100-W01"
        var goals: Set<String> = []
        for floor in 1...30 {
            let config = TowerMode.floorConfig(weekKey: week, floor: floor, perks: [])
            goals.insert(config.goal.title)

            switch config.goal {
            case .score:
                #expect(config.target > 0)
            case .clearBlockers:
                // "Clear every blocker" must be a target that stops moving:
                // no rising syrup, no spreading chocolate, and no three-hit
                // crates eating a shrinking move budget.
                #expect(config.layout.blockerCount > 0)
                #expect(config.layout.syrupTickEvery == nil)
                #expect(config.layout.chocolateCount == 0)
                #expect(config.layout.crateCount == 0)
            case .collectColor(let index, let count):
                #expect(index >= 0 && index < config.colors)
                // Sized off the move budget: demanding enough to use most of
                // it, bounded well inside what a board of this size yields.
                #expect(count > 0 && count <= config.moves * 3)
            case .createSpecials(let count):
                #expect(count > 0 && count <= max(1, config.moves / 3))
            default:
                Issue.record("Tower floor \(floor) got an unsupported goal")
            }
        }
        // The point of the rotation: a climb is not twenty score attacks.
        #expect(goals.count >= 4)

        // A score floor is only a fight if the board can produce the points.
        // The move budget shrinks as floors rise, so an unbounded target turns
        // "hard" into "arithmetically impossible" — the simulator caught five
        // such floors before this was capped. Guarding points-per-move here
        // keeps that regression cheap to catch without running the bot.
        for floor in 1...40 {
            let config = TowerMode.floorConfig(weekKey: week, floor: floor, perks: [])
            guard case .score = config.goal else { continue }
            let pointsPerMove = Double(config.target) / Double(max(1, config.moves))
            #expect(pointsPerMove <= 420,
                    "Tower floor \(floor) needs \(Int(pointsPerMove)) points a move")
        }

        // Still deterministic per (week, floor) so the weekly tower is shared.
        #expect(TowerMode.floorConfig(weekKey: week, floor: 9, perks: []).goal
                == TowerMode.floorConfig(weekKey: week, floor: 9, perks: []).goal)
        // Floors 1-2 stay a plain score climb so the ladder teaches itself.
        #expect(TowerMode.floorConfig(weekKey: week, floor: 1, perks: []).goal == .score)
        #expect(TowerMode.floorConfig(weekKey: week, floor: 2, perks: []).goal == .score)
    }

    // MARK: - Daily missions

    @Test func dailyMissionsAreDeterministicPerDay() {
        let day = Date(timeIntervalSince1970: 4_102_444_800) // far future, off live data
        let a = DailyMissions.missions(on: day)
        let b = DailyMissions.missions(on: day)
        #expect(a == b)
        #expect(a.count == DailyMissions.missionsPerDay)
        #expect(Set(a.map(\.kind)).count == a.count)
        for mission in a {
            #expect(mission.target > 0)
            #expect(mission.rewardCoins > 0)
        }
        let nextDay = DailyMissions.missions(on: day.addingTimeInterval(86_400))
        #expect(Set(a.map(\.id)).isDisjoint(with: nextDay.map(\.id)))
    }

    @Test func missionContributionsMapEventsToMatchingKinds() {
        let missions = [
            DailyMission(id: "t-clearTiles", kind: .clearTiles, target: 100, rewardCoins: 50),
            DailyMission(id: "t-winLevels", kind: .winLevels, target: 2, rewardCoins: 80),
            DailyMission(id: "t-earnScore", kind: .earnScore, target: 4_000, rewardCoins: 50)
        ]
        let clears = DailyMissions.contributions(for: .tilesCleared(5), missions: missions)
        #expect(clears.count == 1)
        #expect(clears.first?.id == "t-clearTiles" && clears.first?.amount == 5)

        let wins = DailyMissions.contributions(for: .levelWon, missions: missions)
        #expect(wins.count == 1 && wins.first?.id == "t-winLevels")

        // Events with no matching mission today contribute nothing.
        #expect(DailyMissions.contributions(for: .chainReaction, missions: missions).isEmpty)
        #expect(DailyMissions.contributions(for: .tilesCleared(0), missions: missions).isEmpty)
    }

    @Test func missionProgressAccumulatesAndClaimsOnce() {
        let day = Date(timeIntervalSince1970: 4_102_444_800)
        defer {
            UserDefaults.standard.removeObject(forKey: Persistence.K.missionProgress)
            UserDefaults.standard.removeObject(forKey: Persistence.K.missionClaimed)
        }
        guard let mission = DailyMissions.missions(on: day).first else {
            Issue.record("no missions generated")
            return
        }
        // An earlier test's `resetAll()` may have left the reset lock active,
        // which zeroes all persistence reads until the next synced write.
        UserDefaults.standard.set(false, forKey: Persistence.K.resetLockActive)
        UserDefaults.standard.removeObject(forKey: Persistence.K.missionProgress)
        UserDefaults.standard.removeObject(forKey: Persistence.K.missionClaimed)

        Persistence.addMissionProgress(id: mission.id, amount: mission.target - 1)
        #expect(!DailyMissions.isComplete(mission))
        #expect(DailyMissions.claim(mission) == nil)

        Persistence.addMissionProgress(id: mission.id, amount: 1)
        #expect(DailyMissions.isComplete(mission))

        let cashBefore = Persistence.cash
        let coins = DailyMissions.claim(mission)
        #expect(coins != nil && coins! >= mission.rewardCoins)
        #expect(Persistence.cash == cashBefore + (coins ?? 0))
        Persistence.cash = cashBefore

        // Second claim is a no-op.
        #expect(DailyMissions.claim(mission) == nil)

        // Progress writes for a new day prune the old day's entries.
        let nextDayMission = DailyMissions.missions(on: day.addingTimeInterval(86_400))[0]
        Persistence.addMissionProgress(id: nextDayMission.id, amount: 1)
        #expect(Persistence.missionProgress(id: mission.id) == 0)
    }

    // MARK: - Turn feedback policy

    @Test func feedbackTiersEscalateWithDepthAndClearSize() {
        #expect(TurnFeedbackPolicy.tier(depth: 1, cleared: 3) == .match)
        #expect(TurnFeedbackPolicy.tier(depth: 1, cleared: 4) == .match)
        #expect(TurnFeedbackPolicy.tier(depth: 2, cleared: 3) == .nice)
        #expect(TurnFeedbackPolicy.tier(depth: 1, cleared: 5) == .nice)
        #expect(TurnFeedbackPolicy.tier(depth: 3, cleared: 3) == .big)
        #expect(TurnFeedbackPolicy.tier(depth: 1, cleared: 7) == .big)
        #expect(TurnFeedbackPolicy.tier(depth: 4, cleared: 3) == .huge)
        #expect(TurnFeedbackPolicy.tier(depth: 1, cleared: 9) == .huge)
        #expect(TurnFeedbackPolicy.tier(depth: 5, cleared: 3) == .epic)
        #expect(TurnFeedbackPolicy.tier(depth: 1, cleared: 10) == .huge)
        // The louder of the two axes wins.
        #expect(TurnFeedbackPolicy.tier(depth: 2, cleared: 10) == .huge)
    }

    @Test func feedbackChannelsUnlockStrictlyByTier() {
        // A plain 3-match: no screen-wide channel fires.
        let match = TurnFeedbackPolicy.feedback(depth: 1, cleared: 3)
        #expect(!match.showsBanner && !match.showsBeam)
        #expect(match.shakeIntensity == nil && !match.spawnsConfetti)
        #expect(match.haptic == .light)

        // A lone bomb (9 tiles in one step) shakes but must not confetti.
        let bomb = TurnFeedbackPolicy.feedback(depth: 1, cleared: 9)
        #expect(bomb.showsBanner && !bomb.showsBeam)
        #expect(bomb.shakeIntensity != nil && !bomb.spawnsConfetti)

        // Confetti stays exclusive to the top tier.
        for depth in 1...4 {
            #expect(!TurnFeedbackPolicy.feedback(depth: depth, cleared: 3).spawnsConfetti)
        }
        #expect(TurnFeedbackPolicy.feedback(depth: 6, cleared: 3).spawnsConfetti)

        // Each successive tier is at least as loud on every channel.
        let ordered = (1...5).map { TurnFeedbackPolicy.feedback(depth: $0, cleared: 3) }
        for (quieter, louder) in zip(ordered, ordered.dropFirst()) {
            #expect(louder.tier > quieter.tier)
            #expect((louder.shakeIntensity ?? 0) >= (quieter.shakeIntensity ?? 0))
            #expect(louder.showsBanner || !quieter.showsBanner)
            #expect(!louder.showsBeam)
        }
    }

}
