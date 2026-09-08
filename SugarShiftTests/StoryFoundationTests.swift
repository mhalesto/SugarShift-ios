import Foundation
import Testing
@testable import SugarShift

/// Pure story/save contracts. These tests deliberately never construct a scene,
/// touch the shared defaults suite, or award campaign progress or currency.
struct StoryFoundationTests {
    @Test func openingBranchesReplyDifferentlyThenRejoinTheFamily() throws {
        var curious = StoryPresentation(scene: StoryCatalog.opening, isReplay: true)
        #expect(curious.advance() == .advanced)
        #expect(curious.currentBeat?.choices.count == 2)
        var helpful = curious

        #expect(curious.advance(choosing: "ask-about-place") == .advanced)
        #expect(helpful.advance(choosing: "offer-help") == .advanced)
        #expect(curious.currentBeat?.dialogue.text != helpful.currentBeat?.dialogue.text)
        #expect(curious.advance() == .advanced)
        #expect(helpful.advance() == .advanced)
        #expect(curious.beatID == helpful.beatID)
        #expect(curious.currentBeat?.dialogue.speakerID == "parent")
        #expect(curious.advance() == .advanced)
        #expect(curious.advance() == .completed)
        #expect(curious.advance() == .invalid)
    }

    @Test func aChoiceCannotBeBypassedOrReplacedWithAnUnknownID() {
        var presentation = StoryPresentation(scene: StoryCatalog.opening, isReplay: true)
        #expect(presentation.advance() == .advanced)
        let decisionBeat = presentation.beatID
        #expect(presentation.advance() == .invalid)
        #expect(presentation.advance(choosing: "missing-choice") == .invalid)
        #expect(presentation.beatID == decisionBeat)
        #expect(presentation.selectedChoices.isEmpty)
    }

    @Test func closingAndRelaunchingResumesTheChosenResponse() throws {
        try withStore { store, defaults in
            var presentation = try #require(store.openingPresentation(highestUnlockedLevel: 1))
            #expect(store.advance(&presentation) == .advanced)
            #expect(store.advance(&presentation, choosing: "offer-help") == .advanced)

            let relaunched = StoryStore(defaults: defaults)
            let resumed = try #require(relaunched.openingPresentation(highestUnlockedLevel: 1))
            #expect(resumed.beatID == presentation.beatID)
            #expect(resumed.selectedChoices.values.contains("offer-help"))
            #expect(resumed.currentBeat?.dialogue.speakerID == "grandpa")
        }
    }

    @Test func completedOpeningDoesNotReplayWhenOldLevelsAreVisited() throws {
        try withStore { store, defaults in
            var presentation = try #require(store.openingPresentation(highestUnlockedLevel: 1))
            finishOpening(&presentation, in: store)
            let relaunched = StoryStore(defaults: defaults)
            #expect(relaunched.openingPresentation(highestUnlockedLevel: 1) == nil)
            #expect(relaunched.state.completedSceneIDs.contains(StoryCatalog.opening.id))
            #expect(!relaunched.state.skippedSceneIDs.contains(StoryCatalog.opening.id))
        }
    }

    @Test func skippingPersistsAndStillLeavesExplicitReplayAvailable() throws {
        try withStore { store, defaults in
            let presentation = try #require(store.openingPresentation(highestUnlockedLevel: 1))
            store.skip(presentation)
            let relaunched = StoryStore(defaults: defaults)
            #expect(relaunched.openingPresentation(highestUnlockedLevel: 1) == nil)
            #expect(relaunched.state.skippedSceneIDs.contains(StoryCatalog.opening.id))
            #expect(relaunched.replayOpening().beatID == StoryCatalog.opening.entryBeatID)
            #expect(relaunched.replayOpening().isReplay)
        }
    }

    @Test func anExistingCampaignIsExcludedEvenAfterReturningToLevelOne() throws {
        try withStore { store, defaults in
            #expect(store.openingPresentation(highestUnlockedLevel: 36) == nil)
            let relaunched = StoryStore(defaults: defaults)
            #expect(relaunched.openingPresentation(highestUnlockedLevel: 1) == nil)
            #expect(relaunched.state.suppressedForExistingProgress)
            #expect(relaunched.state.completedSceneIDs.isEmpty)
        }
    }

    @Test func aCompletedFirstLevelCountsAsAnExistingCampaign() throws {
        try withStore { store, _ in
            #expect(store.openingPresentation(highestUnlockedLevel: 1,
                                             hasCompletedAnyLevel: true) == nil)
            #expect(store.state.suppressedForExistingProgress)
        }
    }

    @Test func replayCannotOverwriteCanonicalChoiceOrAnUnfinishedCursor() throws {
        try withStore { store, defaults in
            var original = try #require(store.openingPresentation(highestUnlockedLevel: 1))
            #expect(store.advance(&original) == .advanced)
            #expect(store.advance(&original, choosing: "offer-help") == .advanced)
            let savedBeforeReplay = defaults.data(forKey: StoryStore.storageKey)

            var replay = store.replayOpening()
            finishOpening(&replay, in: store, choiceID: "ask-about-place")
            store.skip(store.replayOpening())
            #expect(defaults.data(forKey: StoryStore.storageKey) == savedBeforeReplay)
            #expect(store.openingPresentation(highestUnlockedLevel: 1)?.beatID == original.beatID)
        }
    }

    @Test func appearanceAndStorySavesNeverTouchExistingEconomyKeys() throws {
        try withStore { store, defaults in
            let legacyValues = ["ss.currentLevel": 46, "ss.cash": 217,
                                "ss.lives": 3, "ss.hammerCount": 2]
            for (key, value) in legacyValues { defaults.set(value, forKey: key) }
            var avatar = AvatarConfiguration.starter
            avatar.outfit = AvatarPart(id: "raincoat", colorHex: "#57BDAD")
            avatar.accessories = [AvatarPart(id: "round-glasses", colorHex: "#472D55")]
            store.saveAvatar(avatar)
            var replay = store.replayOpening()
            finishOpening(&replay, in: store)
            #expect(StoryStore(defaults: defaults).avatar == avatar)
            for (key, value) in legacyValues { #expect(defaults.integer(forKey: key) == value) }
        }
    }

    @Test func nestedUnlockConditionsRequireTheirActualDependencies() {
        let condition = UnlockCondition.all([
            .levelReached(16),
            .any([.sceneCompleted("opening"), .flag("family-invitation")]),
            .characterUnlocked("parent")
        ])
        let early = StoryUnlockContext(highestUnlockedLevel: 15,
            completedSceneIDs: ["opening"], flags: [], unlockedCharacterIDs: ["parent"])
        let invited = StoryUnlockContext(highestUnlockedLevel: 16,
            completedSceneIDs: [], flags: ["family-invitation"], unlockedCharacterIDs: ["parent"])
        #expect(!condition.isSatisfied(in: early))
        #expect(condition.isSatisfied(in: invited))
    }

    @Test func everyOpeningRouteHasAValidDestinationAndCharacter() throws {
        let scene = StoryCatalog.opening
        #expect(scene.validationIssues.isEmpty)
        let characters = Set(CharacterCatalog.all.map(\.id))
        for beat in scene.beats {
            #expect(characters.contains(beat.dialogue.speakerID))
            #expect(Set(beat.characterIDs).isSubset(of: characters))
        }
        let encoded = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryScene.self, from: encoded)
        var presentation = StoryPresentation(scene: decoded, isReplay: true)
        #expect(presentation.advance() == .advanced)
        #expect(presentation.advance(choosing: "offer-help") == .advanced)
        #expect(presentation.currentBeat?.dialogue.speakerID == "grandpa")
    }

    @Test func unfinishedOpeningYieldsToProgressMadeElsewhere() throws {
        try withStore { store, _ in
            #expect(store.openingPresentation(highestUnlockedLevel: 1) != nil)
            #expect(store.openingPresentation(highestUnlockedLevel: 12) == nil)
            #expect(store.openingPresentation(highestUnlockedLevel: 1) == nil)
            #expect(store.replayOpening().isReplay)
        }
    }

    @Test func avatarDecodesOldSavesAndRoundTripsNewAccessorySlots() throws {
        let legacy = try JSONDecoder().decode(AvatarConfiguration.self, from: Data("{}".utf8))
        #expect(legacy == .starter)
        try withStore { store, defaults in
            var avatar = legacy
            avatar.hat = AvatarPart(id: "sun-hat", colorHex: "#F4D892")
            avatar.backpack = AvatarPart(id: "explorer-pack", colorHex: "#4BB5A1")
            avatar.glasses = AvatarPart(id: "round-glasses", colorHex: "#432A48")
            store.saveAvatar(avatar)
            #expect(StoryStore(defaults: defaults).avatar == avatar)
        }
    }

    @Test func worldAndStarGatesUseSuppliedMilestones() {
        var context = StoryUnlockContext(highestUnlockedLevel: 31, completedSceneIDs: [],
            flags: [], unlockedCharacterIDs: ["player"])
        context.completedLevels = [30]
        context.unlockedWorldIDs = ["honey"]
        context.completedWorldIDs = ["ice"]
        context.totalStars = 42
        #expect(UnlockCondition.all([.levelCompleted(30), .worldUnlocked("honey"),
            .worldCompleted("ice"), .starsEarned(40)]).isSatisfied(in: context))
        #expect(!UnlockCondition.worldCompleted("honey").isSatisfied(in: context))
        #expect(!UnlockCondition.starsEarned(43).isSatisfied(in: context))
    }

    private func finishOpening(_ presentation: inout StoryPresentation,
                               in store: StoryStore, choiceID: String = "offer-help") {
        // Bounded so a broken graph fails instead of hanging the test runner.
        for _ in 0..<12 {
            let choice = presentation.currentBeat?.choices.isEmpty == false ? choiceID : nil
            let result = store.advance(&presentation, choosing: choice)
            if result == .completed { return }
            #expect(result == .advanced)
        }
        Issue.record("The opening did not reach its gameplay handoff.")
    }

    private func withStore(_ body: (StoryStore, UserDefaults) throws -> Void) throws {
        let suite = "SugarShift.StoryFoundationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(StoryStore(defaults: defaults), defaults)
    }
}
