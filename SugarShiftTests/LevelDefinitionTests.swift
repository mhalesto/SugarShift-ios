import Foundation
import Testing
@testable import SugarShift

@Suite(.serialized)
@MainActor
struct LevelDefinitionTests {

    @Test func firstLevelUsesSpecifiedGeometryAndThreeCollectionObjectives() throws {
        let definition = try #require(Levels.definition(for: 1))

        #expect(definition.id == 1)
        #expect(definition.boardWidth == 7)
        #expect(definition.boardHeight == 6)
        #expect(definition.activeCells.count == 42)
        #expect(definition.pieceTypes == [.orange, .grape, .blueberry])
        #expect(definition.moves == 28)
        #expect(definition.objectives == [
            .collectPieces(color: .orange, count: 10),
            .collectPieces(color: .grape, count: 10),
            .collectPieces(color: .blueberry, count: 10)
        ])
        #expect(try definition.validated() == definition)

        let config = Levels.config(for: 1)
        #expect(config.rows == 6)
        #expect(config.cols == 7)
        #expect(config.objectives == definition.objectives)
    }

    @Test func objectiveTrackerCompletesOnlyAfterEveryObjectiveTarget() {
        let objectives: [LevelObjective] = [
            .collectPieces(color: .orange, count: 3),
            .breakIce(count: 2),
            .reachScore(500),
            .comboObjective(minimumDepth: 3, count: 1)
        ]
        var tracker = ObjectiveTracker(objectives: objectives)

        tracker.consume(.piecesCleared(color: .orange, count: 4))
        tracker.consume(.iceBroken(count: 1))
        tracker.consume(.scoreEarned(650))
        tracker.consume(.combo(depth: 2))

        #expect(tracker.progress(for: objectives[0]).current == 3)
        #expect(tracker.progress(for: objectives[1]).current == 1)
        #expect(tracker.progress(for: objectives[2]).current == 500)
        #expect(tracker.progress(for: objectives[3]).current == 0)
        #expect(!tracker.isComplete)

        tracker.consume(.iceBroken(count: 1))
        tracker.consume(.combo(depth: 3))

        #expect(tracker.isComplete)
        #expect(tracker.progressFraction == 1)
    }

    @Test func decodingRejectsDisconnectedActiveCells() throws {
        let valid = try #require(Levels.definition(for: 1))
        let encoded = try JSONEncoder().encode(valid)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["activeCells"] = [
            ["row": 0, "column": 0],
            ["row": 0, "column": 1],
            ["row": 5, "column": 6]
        ]
        let invalid = try JSONSerialization.data(withJSONObject: object)

        do {
            _ = try JSONDecoder().decode(LevelDefinition.self, from: invalid)
            Issue.record("Disconnected active cells should fail decoding validation")
        } catch let error as LevelDefinitionValidationError {
            #expect(error == .disconnectedActiveCells)
        }
    }

    @Test func decodingRejectsImpossiblePieceObjective() throws {
        let valid = try #require(Levels.definition(for: 1))
        let encoded = try JSONEncoder().encode(valid)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let unsupported = LevelObjective.collectPieces(color: .strawberry, count: 5)
        object["objectives"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([unsupported]))
        let invalid = try JSONSerialization.data(withJSONObject: object)

        do {
            _ = try JSONDecoder().decode(LevelDefinition.self, from: invalid)
            Issue.record("An objective for an unavailable piece should fail decoding validation")
        } catch let error as LevelDefinitionValidationError {
            #expect(error == .objectiveUsesUnavailablePiece(.strawberry))
        }
    }

    @Test func objectiveVictoryAndScoreStarsAreIndependent() {
        let config = Levels.config(for: 1)
        let belowOneStar = LevelAttemptPerformance(score: config.starThresholds.one - 1,
                                                   movesLeft: 20,
                                                   movesAtStart: config.moves,
                                                   maxCascadeDepth: 5,
                                                   createdSpecials: 8,
                                                   detonatedBombs: 3,
                                                   objectiveProgress: 1)
        let atThreeStars = LevelAttemptPerformance(score: config.starThresholds.three,
                                                   movesLeft: 0,
                                                   movesAtStart: config.moves,
                                                   maxCascadeDepth: 1,
                                                   createdSpecials: 0,
                                                   detonatedBombs: 0,
                                                   objectiveProgress: 1)

        #expect(LevelScoring.stars(for: config, performance: belowOneStar, won: true) == 0)
        #expect(LevelScoring.stars(for: config, performance: atThreeStars, won: true) == 3)
        #expect(LevelScoring.stars(for: config, performance: atThreeStars, won: false) == 0)
    }

    @Test func replayCannotReduceCompletionOrBestScore() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        CampaignProgress.recordCompletion(level: 4, score: 2_400,
                                          at: Date(timeIntervalSince1970: 100), defaults: defaults)
        CampaignProgress.recordAttempt(level: 4, score: 200, defaults: defaults)

        let record = CampaignProgress.record(for: 4, defaults: defaults)
        #expect(record.bestScore == 2_400)
        #expect(record.attempts == 2)
        #expect(record.completedAt == Date(timeIntervalSince1970: 100))
        #expect(CampaignProgress.highestUnlockedLevel(currentLevel: 1,
                                                      levelCount: 8,
                                                      defaults: defaults,
                                                      legacyStars: { _ in 0 }) == 5)
    }

    @Test func supplementalRecordsPreserveLegacyStarsAndEconomyKeys() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(3, forKey: "ss.stars.7")
        defaults.set(9_999, forKey: "ss.cash")
        defaults.set(4, forKey: "ss.lives")

        #expect(CampaignProgress.isCompleted(level: 7,
                                             defaults: defaults,
                                             legacyStars: { defaults.integer(forKey: "ss.stars.\($0)") }))
        CampaignProgress.recordAttempt(level: 7, score: 700, defaults: defaults)

        #expect(defaults.integer(forKey: "ss.stars.7") == 3)
        #expect(defaults.integer(forKey: "ss.cash") == 9_999)
        #expect(defaults.integer(forKey: "ss.lives") == 4)
        #expect(defaults.data(forKey: CampaignProgress.storageKey) != nil)
    }

    @Test func blockerRemovalUpdatesBothSpecificAndGeneralGoalsAndUndoRestoresThem() {
        let objectives: [LevelObjective] = [.breakBlockers(count: 2), .breakIce(count: 1),
                                           .destroySpecificBlocker(type: .chest, count: 1)]
        var tracker = ObjectiveTracker(objectives: objectives)
        tracker.consume(.blockerDestroyed(type: .ice, count: 1))
        let snapshot = tracker
        tracker.consume(.blockerDestroyed(type: .chest, count: 1))
        #expect(tracker.isComplete)
        tracker = snapshot
        #expect(!tracker.isComplete)
        #expect(tracker.progress(for: objectives[0]).current == 1)
        #expect(tracker.progress(for: objectives[2]).current == 0)
    }

    @Test func legacyMixedDropAndBossGoalsCannotBeReplacedByScore() {
        let mixed = LevelGoal.collectIngredientsAndKeys(ingredients: 2, keys: 1)
            .objectives(targetScore: 1_000, blockerCount: 3)
        #expect(mixed == [.collectIngredients(count: 2), .collectKeys(count: 1)])
        var tracker = ObjectiveTracker(objectives: mixed + [.breakBossShield(count: 2)])
        tracker.consume(.ingredientsCollected(count: 2))
        tracker.consume(.keysCollected(count: 1))
        tracker.consume(.scoreEarned(100_000))
        #expect(!tracker.isComplete)
        tracker.consume(.bossShieldDamaged(count: 2))
        #expect(tracker.isComplete)
        #expect(Levels.config(for: 10).objectives.contains(.breakBossShield(count: 2)))
    }

    @Test func definitionRejectsZeroWeightsSelfPortalsAndUnseededBlockerObjectives() throws {
        let valid = try #require(Levels.definition(for: 1))
        let base = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        let invalidChanges: [(String, Any, LevelDefinitionValidationError)] = [
            ("spawnWeights", try JSONSerialization.jsonObject(with: JSONEncoder().encode([
                PieceColor.orange: 1.0, .grape: 0.0, .blueberry: 1.0])), .invalidSpawnWeights),
            ("portals", [["from": ["row": 0, "column": 0], "to": ["row": 0, "column": 0]]], .invalidPortals),
            ("objectives", try JSONSerialization.jsonObject(with: JSONEncoder().encode([
                LevelObjective.breakIce(count: 1)])), .impossibleObjective(.breakIce(count: 1)))
        ]
        for (key, value, expected) in invalidChanges {
            var data = base
            data[key] = value
            do {
                _ = try JSONDecoder().decode(LevelDefinition.self, from: JSONSerialization.data(withJSONObject: data))
                Issue.record("Invalid \(key) should fail authoring validation")
            } catch let error as LevelDefinitionValidationError {
                #expect(error == expected)
            }
        }
    }

    @Test func onboardingBoardsHaveLegalMovesBeforeBlockersAreIntroduced() throws {
        for level in 1...15 {
            let config = Levels.config(for: level)
            let definition = try #require(config.definition)
            #expect(try definition.validated() == definition)
            let result = LevelBoardFactory.makeInitialBoard(config: config, seed: UInt64(level))
            #expect(Engine.hasAnyMoves(result.grid))
            #expect(result.grid.flatMap { $0 }.compactMap { $0 }.allSatisfy { $0.blocker == nil })
        }
        #expect(Levels.config(for: 16).layout.blockerCount > 0)
    }

    @Test func startingAnAbandonedAttemptCountsWithoutDoubleCountingResult() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        CampaignProgress.recordStart(level: 1, defaults: defaults)
        #expect(CampaignProgress.record(for: 1, defaults: defaults).attempts == 1)
        CampaignProgress.recordStart(level: 1, defaults: defaults)
        CampaignProgress.recordResult(level: 1, score: 800, won: true, defaults: defaults)
        #expect(CampaignProgress.record(for: 1, defaults: defaults).attempts == 2)
        #expect(CampaignProgress.isCompleted(level: 1, defaults: defaults, legacyStars: { _ in 0 }))
        #expect(CampaignProgress.highestUnlockedLevel(currentLevel: 12, levelCount: 20,
                                                      defaults: defaults, legacyStars: { _ in 0 }) == 12)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "LevelDefinitionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
