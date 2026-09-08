import Foundation

/// Additive local story storage. This type never imports, resets, or writes the
/// campaign/economy persistence layer. The host supplies progression for gates.
final class StoryStore {
    static let shared = StoryStore()
    static let storageKey = "ss.story.foundation.v1"

    private let defaults: UserDefaults
    private(set) var state: StorySaveState

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(StorySaveState.self, from: data) {
            state = saved
        } else {
            state = StorySaveState()
        }
    }

    var avatar: AvatarConfiguration { state.avatar }

    var characters: [CharacterDefinition] {
        CharacterCatalog.all.map { definition in
            var character = definition
            character.unlocked = definition.unlocked || state.unlockedCharacterIDs.contains(definition.id)
            return character
        }
    }

    func saveAvatar(_ avatar: AvatarConfiguration) {
        state.avatar = avatar
        persist()
    }

    /// Call at the home-to-play boundary, using actual saved progression.
    /// Existing players keep their place and can replay the opening explicitly.
    /// An unfinished opening resumes on the last displayed beat after relaunch.
    func openingPresentation(highestUnlockedLevel: Int,
                             hasCompletedAnyLevel: Bool = false) -> StoryPresentation? {
        if !state.openingEligibilityEvaluated || highestUnlockedLevel > 1 || hasCompletedAnyLevel {
            state.openingEligibilityEvaluated = true
            state.suppressedForExistingProgress = highestUnlockedLevel > 1 || hasCompletedAnyLevel
            persist()
        }
        guard !state.suppressedForExistingProgress else { return nil }
        return presentation(for: StoryCatalog.opening, highestUnlockedLevel: highestUnlockedLevel)
    }

    /// Replays are intentionally transient: skip, alternate choices, and the
    /// ending cannot overwrite a canonical cursor, completion, or character.
    func replayOpening() -> StoryPresentation {
        StoryPresentation(scene: StoryCatalog.opening, isReplay: true)
    }

    func presentation(for scene: StoryScene, highestUnlockedLevel: Int) -> StoryPresentation? {
        presentation(for: scene, context: unlockContext(highestUnlockedLevel: highestUnlockedLevel))
    }

    /// The host supplies real campaign milestones. With no matching authored
    /// scene this returns nil, so normal level transitions stay uninterrupted.
    func presentation(triggeredBy trigger: StoryTrigger, context: StoryUnlockContext) -> StoryPresentation? {
        for scene in StoryCatalog.scenes where scene.triggers.contains(trigger) {
            if let result = presentation(for: scene, context: context) { return result }
        }
        return nil
    }

    func presentation(for scene: StoryScene, context: StoryUnlockContext) -> StoryPresentation? {
        guard !state.completedSceneIDs.contains(scene.id),
              scene.validationIssues.isEmpty,
              scene.unlockCondition.isSatisfied(in: context),
              StoryCatalog.chapters.first(where: { $0.id == scene.chapterID })?.unlockCondition.isSatisfied(in: context) != false else {
            return nil
        }
        let presentation = StoryPresentation(scene: scene, isReplay: false,
            beatID: state.beatByScene[scene.id],
            selectedChoices: state.choicesByScene[scene.id] ?? [:],
            flags: state.flags, revealedCharacterIDs: state.unlockedCharacterIDs)
        record(presentation)
        persist()
        return presentation
    }

    func unlockContext(highestUnlockedLevel: Int) -> StoryUnlockContext {
        StoryUnlockContext(highestUnlockedLevel: max(1, highestUnlockedLevel),
            completedSceneIDs: state.completedSceneIDs, flags: state.flags,
            unlockedCharacterIDs: state.unlockedCharacterIDs)
    }

    @discardableResult
    func advance(_ presentation: inout StoryPresentation,
                 choosing choiceID: String? = nil) -> StoryAdvanceResult {
        let result = presentation.advance(choosing: choiceID)
        guard result != .invalid, !presentation.isReplay else { return result }
        // A dismissed card cannot turn a skipped/completed story into an active
        // one if its host still holds an old presentation value.
        guard !state.completedSceneIDs.contains(presentation.scene.id) else { return result }
        record(presentation)
        if result == .completed {
            state.completedSceneIDs.insert(presentation.scene.id)
            state.beatByScene.removeValue(forKey: presentation.scene.id)
            if state.activeSceneID == presentation.scene.id { state.activeSceneID = nil }
        }
        persist()
        return result
    }

    func skip(_ presentation: StoryPresentation) {
        guard !presentation.isReplay,
              !state.completedSceneIDs.contains(presentation.scene.id) else { return }
        record(presentation)
        state.completedSceneIDs.insert(presentation.scene.id)
        state.skippedSceneIDs.insert(presentation.scene.id)
        state.flags.formUnion(presentation.scene.completionFlags)
        state.beatByScene.removeValue(forKey: presentation.scene.id)
        if state.activeSceneID == presentation.scene.id { state.activeSceneID = nil }
        persist()
    }

    private func record(_ presentation: StoryPresentation) {
        state.activeSceneID = presentation.scene.id
        state.beatByScene[presentation.scene.id] = presentation.beatID
        state.choicesByScene[presentation.scene.id] = presentation.selectedChoices
        state.flags.formUnion(presentation.flags)
        state.unlockedCharacterIDs.formUnion(presentation.revealedCharacterIDs)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct StorySaveState: Codable, Equatable {
    var schemaVersion = 1
    var openingEligibilityEvaluated = false
    var suppressedForExistingProgress = false
    var activeSceneID: String? = nil
    var beatByScene: [String: String] = [:]
    var choicesByScene: [String: [String: String]] = [:]
    var completedSceneIDs: Set<String> = []
    var skippedSceneIDs: Set<String> = []
    var flags: Set<String> = []
    var unlockedCharacterIDs: Set<String> = ["grandpa", "player"]
    var avatar = AvatarConfiguration.starter
    var metadata: [String: String] = [:]
}

extension StorySaveState {
    /// New optional fields get safe defaults when a future chapter extends this
    /// record. Existing part IDs, choices, and metadata remain intact.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        openingEligibilityEvaluated = try values.decodeIfPresent(Bool.self, forKey: .openingEligibilityEvaluated) ?? false
        suppressedForExistingProgress = try values.decodeIfPresent(Bool.self, forKey: .suppressedForExistingProgress) ?? false
        activeSceneID = try values.decodeIfPresent(String.self, forKey: .activeSceneID)
        beatByScene = try values.decodeIfPresent([String: String].self, forKey: .beatByScene) ?? [:]
        choicesByScene = try values.decodeIfPresent([String: [String: String]].self, forKey: .choicesByScene) ?? [:]
        completedSceneIDs = try values.decodeIfPresent(Set<String>.self, forKey: .completedSceneIDs) ?? []
        skippedSceneIDs = try values.decodeIfPresent(Set<String>.self, forKey: .skippedSceneIDs) ?? []
        flags = try values.decodeIfPresent(Set<String>.self, forKey: .flags) ?? []
        unlockedCharacterIDs = try values.decodeIfPresent(Set<String>.self, forKey: .unlockedCharacterIDs) ?? unlockedCharacterIDs
        avatar = try values.decodeIfPresent(AvatarConfiguration.self, forKey: .avatar) ?? .starter
        metadata = try values.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}
