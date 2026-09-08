import Foundation
import Testing
@testable import SugarShift

struct PresentationEventTests {
    @Test func layeredIceReportsDamageThenReleaseWithoutClearingFruit() throws {
        let p = Pos(r: 0, c: 0)
        let fruit = Piece(id: "frozen", color: .strawberry)
        var grid: Grid = [[Cell(piece: fruit, tile: BoardTile(blocker: Blocker(type: .ice, hits: 2)))]]
        let first = Engine.clearMatches(&grid, matches: [p])
        #expect(first.cleared.isEmpty)
        #expect(first.damagedBlockers == [p])
        #expect(first.presentationEvents.count == 2)
        #expect(first.presentationEvents.contains(.blockerDamaged(at: p,
            before: Blocker(type: .ice, hits: 2), after: Blocker(type: .ice, hits: 1))))
        let final = Engine.clearMatches(&grid, matches: [p])
        #expect(grid[0][0]?.piece == fruit)
        #expect(final.presentationEvents.contains(.blockerDestroyed(at: p, blocker: Blocker(type: .ice, hits: 1))))
        #expect(!final.presentationEvents.contains(.pieceDestroyed(at: p, piece: fruit)))
    }

    @Test func blockedDamageCannotInventAHitOrAnObjectiveFlight() {
        let p = Pos(r: 0, c: 0)
        var grid: Grid = [[Cell(piece: Piece(id: "fruit", color: .grape),
            tile: BoardTile(blocker: Blocker(type: .magicFrost, hits: 1)))]]
        let result = Engine.clearMatches(&grid, matches: [p])
        #expect(result.presentationEvents.isEmpty)
        #expect(result.affectedCount == 0)
    }

    @Test func adjacentBlockerGetsOneHitAndNoFalsePieceMatch() {
        let origin = Pos(r: 0, c: 0), neighbour = Pos(r: 0, c: 1)
        var grid: Grid = [[Cell(piece: Piece(id: "match", color: .orange)),
            Cell(piece: nil, tile: BoardTile(blocker: Blocker(type: .stone, hits: 2)))]]
        let result = Engine.clearMatches(&grid, matches: [origin])
        let hits = result.presentationEvents.filter { if case .blockerHit = $0 { return true }; return false }
        #expect(hits.count == 1)
        #expect(grid[0][1]?.blocker?.hits == 1)
        #expect(!result.cleared.contains(neighbour))
    }

    @Test func collateralSpecialsAreActivatedWithoutBeingCalledDirectMatches() {
        let a = Pos(r: 0, c: 0), b = Pos(r: 0, c: 1)
        let first = Piece(id: "first", color: .orange, special: .stripedRow)
        let second = Piece(id: "second", color: .grape, special: .wrapped)
        var grid: Grid = [[Cell(piece: first), Cell(piece: second)]]
        let result = Engine.clearMatches(&grid, matches: [a, b], matchedPositions: [a])
        #expect(result.presentationEvents.contains(.pieceMatched(at: a, piece: first)))
        #expect(!result.presentationEvents.contains(.pieceMatched(at: b, piece: second)))
        #expect(result.presentationEvents.contains(.specialActivated(at: b, special: .wrapped)))
        #expect(result.presentationEvents.contains(.specialChainTriggered(positions: [a, b])))
    }

    @Test func eventOrderDoesNotDependOnSetInsertionOrder() {
        let positions = [Pos(r: 0, c: 2), Pos(r: 0, c: 0), Pos(r: 0, c: 1)]
        var first: Grid = [[Cell(piece: Piece(id: "a", color: .orange)),
                           Cell(piece: Piece(id: "b", color: .grape)),
                           Cell(piece: Piece(id: "c", color: .banana))]]
        var second = first
        let a = Engine.clearMatches(&first, matches: Set(positions))
        let b = Engine.clearMatches(&second, matches: Set(positions.reversed()))
        #expect(a.presentationEvents == b.presentationEvents)
        #expect(first == second)
    }

    @Test func capturePreservesRefillAndRandomGeneratorState() {
        let grid: Grid = [[Cell(piece: Piece(id: "traveller", color: .orange)), Cell(piece: nil)],
                          [Cell(piece: nil), Cell(piece: nil)]]
        let portals = [LevelPortal(from: Pos(r: 0, c: 0), to: Pos(r: 1, c: 1))]
        var plainRNG = SeededRandomNumberGenerator(seed: 274)
        var eventRNG = SeededRandomNumberGenerator(seed: 274)
        let plain = Engine.collapseAndRefill(grid, colors: ["R", "G", "B"], cascadeBoost: 0.3,
            portals: portals, rng: &plainRNG)
        let captured = Engine.collapseAndRefillResult(grid, colors: ["R", "G", "B"], cascadeBoost: 0.3,
            portals: portals, rng: &eventRNG)
        #expect(plain == captured.grid)
        #expect(plainRNG.next() == eventRNG.next())
        #expect(captured.portalTransfers == [.init(pieceID: "traveller", from: Pos(r: 0, c: 0), to: Pos(r: 1, c: 1))])
        for event in captured.presentationEvents {
            if case .pieceCreated(let position, let piece) = event {
                #expect(captured.grid[position.r][position.c]?.piece == piece)
            }
        }
    }

    @Test func occupiedAndCyclicPortalsEmitNoTransfer() {
        let a = Pos(r: 0, c: 0), b = Pos(r: 0, c: 1)
        let grid: Grid = [[Cell(piece: Piece(id: "a", color: .orange)),
                           Cell(piece: Piece(id: "b", color: .grape))]]
        var rng = SeededRandomNumberGenerator(seed: 2)
        let occupied = Engine.collapseAndRefillResult(grid, colors: ["R"],
            portals: [.init(from: a, to: b)], rng: &rng)
        #expect(occupied.portalTransfers.isEmpty)
        let cycle = Engine.collapseAndRefillResult(grid, colors: ["R"],
            portals: [.init(from: a, to: b), .init(from: b, to: a)], rng: &rng)
        #expect(cycle.portalTransfers.isEmpty)
    }

    @Test func popupsExactlyPartitionScoreIncludingLayerAndBananaCredits() {
        let p = Pos(r: 0, c: 0), q = Pos(r: 0, c: 1)
        let result = ClearResult(cleared: [p, q], damagedBlockers: [p])
        let preClear = [p: Cell(piece: Piece(id: "banana", color: .banana)),
                        q: Cell(piece: Piece(id: "orange", color: .orange))]
        let receipts = ScorePopupReceipt.grouped(result: result, preClear: preClear,
            pointsPerTile: 10, multiplier: 3, doublesBananas: true, groupCount: 4)
        #expect(receipts.count == 2)
        #expect(receipts.reduce(0) { $0 + $1.points } == 120)
        #expect(receipts.first?.points == 90)
    }

    @Test func blockerHitsAloneNeverCountAsCollection() {
        let blocker = Blocker(type: .ice, hits: 2)
        #expect(!ObjectivePresentationPolicy.contributes(.blockerHit(at: Pos(r: 0, c: 0), blocker: blocker),
                                                        to: .breakIce(count: 3)))
        #expect(ObjectivePresentationPolicy.contributes(.blockerDestroyed(at: Pos(r: 0, c: 0), blocker: blocker),
                                                       to: .breakIce(count: 3)))
    }

    @Test func worldMaterialsKeepTheirIdentityAndGravity() {
        let examples: [(String, String, AnimationMaterial)] = [
            ("firefly", "combo_firefly_jar", .firefly), ("firefly", "blocker_vine_crate", .vine),
            ("ice", "blocker_ice_03", .ice), ("honey", "combo_honey_jar", .honey),
            ("volcano", "blocker_magma", .lava), ("coral", "objective_pearl", .water),
            ("cloud", "blocker_cloud", .cloud), ("golden", "combo_honey_jar", .amber),
            ("sahara", "objective_scarab", .scarab), ("galaxy", "blocker_asteroid", .cosmic),
            ("sakura", "blocker_pink_crystal", .crystal)
        ]
        for (world, asset, material) in examples {
            #expect(WorldAnimationProfile.material(worldID: world, asset: asset) == material)
        }
        #expect(WorldAnimationProfile.profile(for: .stone, worldID: "coral").gravity < 0)
        #expect(WorldAnimationProfile.profile(for: .cosmic, worldID: "galaxy").gravity < 0)
    }

    @Test func fishFlightRetainsTheRealDestinationAfterClear() throws {
        let origin = Pos(r: 0, c: 0), target = Pos(r: 0, c: 2)
        var grid: Grid = [[Cell(piece: Piece(id: "fish", color: .orange, special: .fish)),
                          Cell(piece: Piece(id: "safe", color: .grape)),
                          Cell(piece: Piece(id: "target", color: .banana))]]
        let plans = SpecialPresentationPlan.capture(in: grid, positions: [origin, target],
            fishDestinations: [origin: target], bigger: false)
        _ = Engine.clearMatches(&grid, matches: [origin, target])
        let plan = try #require(plans.first)
        #expect(plan.destinations == [target])
        #expect(plan.footprint == [origin, target])
        #expect(grid[target.r][target.c]?.piece == nil)
        #expect(grid[0][1]?.piece?.id == "safe")
    }

    @Test func rocketPresentationStopsAtTheSameWallAsTheEngine() throws {
        let origin = Pos(r: 0, c: 0), behindWall = Pos(r: 3, c: 0)
        let grid: Grid = [[Cell(piece: Piece(id: "rocket", color: .orange, special: .rocket))],
                          [Cell(piece: Piece(id: "near", color: .grape))],
                          [Cell(piece: nil, tile: BoardTile(blocker: Blocker(type: .solidX, hits: 3)))],
                          [Cell(piece: Piece(id: "safe", color: .banana))]]
        let expanded = Engine.expandMatchesWithSpecials(grid, [origin])
        let plan = try #require(SpecialPresentationPlan.capture(in: grid, positions: expanded,
            fishDestinations: [:], bigger: false).first)
        #expect(!plan.footprint.contains(behindWall))
        #expect(plan.footprint == expanded)
    }

    @Test func secondaryStripeWaitsForItsFishAndStillKeepsDirectMatchesFast() {
        let fish = Pos(r: 0, c: 0), stripe = Pos(r: 0, c: 3)
        let grid: Grid = [[Cell(piece: Piece(id: "fish", color: .orange, special: .fish)),
                          Cell(piece: Piece(id: "a", color: .grape)),
                          Cell(piece: Piece(id: "b", color: .banana)),
                          Cell(piece: Piece(id: "stripe", color: .grape, special: .stripedRow))]]
        let plans = SpecialPresentationPlan.capture(in: grid, positions: [fish, stripe],
            fishDestinations: [fish: stripe], bigger: false)
        let events: [GamePresentationEvent] = [.specialActivated(at: fish, special: .fish),
                                             .specialActivated(at: stripe, special: .stripedRow)]
        let timing = CascadePresentationTiming(events: events, matched: [fish], specials: plans)
        #expect(timing.activationDelay(stripe) >= timing.activationDelay(fish) + SpecialPresentationPlan.seekerTravelDuration)
        let simultaneousMatch = CascadePresentationTiming(events: events, matched: [fish, stripe], specials: plans)
        #expect(simultaneousMatch.activationDelay(stripe) < timing.activationDelay(stripe))
    }
}
