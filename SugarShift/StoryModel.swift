import Foundation

// MARK: - Data, independent of SpriteKit and campaign mechanics

struct StoryChapter: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let sceneIDs: [String]
    var unlockCondition: UnlockCondition = .always
    var metadata: [String: String] = [:]
}

struct StoryScene: Codable, Equatable, Identifiable {
    let id: String
    let chapterID: String
    let title: String
    let settingID: String
    let entryBeatID: String
    let beats: [StoryBeat]
    var triggers: [StoryTrigger] = []
    var unlockCondition: UnlockCondition = .always
    var completionFlags: Set<String> = []
    var metadata: [String: String] = [:]

    func beat(id: String) -> StoryBeat? { beats.first { $0.id == id } }

    /// Diagnostics for future authored scenes; never repairs a broken branch by
    /// choosing a different response or awarding a completion.
    var validationIssues: [String] {
        var issues: [String] = []
        let ids = Set(beats.map(\.id))
        if ids.count != beats.count { issues.append("Duplicate beat IDs") }
        if !ids.contains(entryBeatID) { issues.append("Missing entry beat") }
        for beat in beats {
            if !beat.choices.isEmpty && beat.nextBeatID != nil {
                issues.append("Beat \(beat.id) has both a choice and an automatic destination")
            }
            if Set(beat.choices.map(\.id)).count != beat.choices.count {
                issues.append("Beat \(beat.id) has duplicate choice IDs")
            }
            let destinations = beat.choices.map(\.nextBeatID) + [beat.nextBeatID].compactMap { $0 }
            for destination in destinations where !ids.contains(destination) {
                issues.append("Beat \(beat.id) links to missing beat \(destination)")
            }
        }
        var visited: Set<String> = []
        var pending = [entryBeatID]
        while let id = pending.popLast() {
            guard visited.insert(id).inserted, let beat = beat(id: id) else { continue }
            pending.append(contentsOf: beat.choices.map(\.nextBeatID))
            if let next = beat.nextBeatID { pending.append(next) }
        }
        if !ids.isSubset(of: visited) { issues.append("Unreachable beats") }
        if !beats.contains(where: { visited.contains($0.id) && $0.isTerminal }) {
            issues.append("No reachable ending")
        }
        return issues
    }
}

enum StoryTrigger: Codable, Equatable {
    case beforeLevel(Int), afterLevel(Int)
    case worldUnlock(String), worldCompletion(String)
    case starMilestone(Int), specialEvent(String)
}

struct StoryBeat: Codable, Equatable, Identifiable {
    let id: String
    let dialogue: DialogueLine
    let characterIDs: [String]
    var propID: String? = nil
    var choices: [StoryChoice] = []
    var nextBeatID: String? = nil
    var metadata: [String: String] = [:]

    var isTerminal: Bool { choices.isEmpty && nextBeatID == nil }
}

struct DialogueLine: Codable, Equatable, Identifiable {
    let id: String
    let speakerID: String
    let text: String
    var expression: CharacterExpression = .warm
    var metadata: [String: String] = [:]
}

struct StoryChoice: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let nextBeatID: String
    var flags: Set<String> = []
    var metadata: [String: String] = [:]
}

indirect enum UnlockCondition: Codable, Equatable {
    case always
    case levelReached(Int)
    case sceneCompleted(String)
    case flag(String)
    case characterUnlocked(String)
    case levelCompleted(Int)
    case worldUnlocked(String)
    case worldCompleted(String)
    case starsEarned(Int)
    case all([UnlockCondition])
    case any([UnlockCondition])

    func isSatisfied(in context: StoryUnlockContext) -> Bool {
        switch self {
        case .always: return true
        case .levelReached(let level): return context.highestUnlockedLevel >= level
        case .sceneCompleted(let id): return context.completedSceneIDs.contains(id)
        case .flag(let id): return context.flags.contains(id)
        case .characterUnlocked(let id): return context.unlockedCharacterIDs.contains(id)
        case .levelCompleted(let level): return context.completedLevels.contains(level)
        case .worldUnlocked(let id): return context.unlockedWorldIDs.contains(id)
        case .worldCompleted(let id): return context.completedWorldIDs.contains(id)
        case .starsEarned(let count): return context.totalStars >= count
        case .all(let conditions): return conditions.allSatisfy { $0.isSatisfied(in: context) }
        case .any(let conditions): return conditions.contains { $0.isSatisfied(in: context) }
        }
    }
}

struct StoryUnlockContext: Equatable {
    let highestUnlockedLevel: Int
    let completedSceneIDs: Set<String>
    let flags: Set<String>
    let unlockedCharacterIDs: Set<String>
    var completedLevels: Set<Int> = []
    var unlockedWorldIDs: Set<String> = []
    var completedWorldIDs: Set<String> = []
    var totalStars: Int = 0
}

// MARK: - Characters and an expandable, asset-independent avatar

enum CharacterRole: String, Codable, CaseIterable {
    case player, grandparent, parent, guide, supporting
    case sibling, friend, classmate, teacher, neighbour, worldResident
}

enum CharacterExpression: String, Codable, CaseIterable {
    case neutral, warm, curious, thoughtful, hopeful
    case happy, excited, sad, worried, surprised, proud, angry, thinking, laughing
}

struct CharacterDefinition: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let role: CharacterRole
    let portraitID: String
    let expressions: [CharacterExpression]
    let relationship: String
    var unlocked: Bool
    var metadata: [String: String] = [:]
}

/// Stable part IDs allow future artwork and wardrobe content without changing
/// save keys. Color is presentation data; parts grant no gameplay advantages.
struct AvatarPart: Codable, Equatable, Identifiable {
    let id: String
    var colorHex: String
    var metadata: [String: String] = [:]
}

struct AvatarConfiguration: Codable, Equatable {
    var base = "orchard-child"
    var skin = AvatarPart(id: "warm-brown", colorHex: "#BC7957")
    var hair = AvatarPart(id: "soft-crop", colorHex: "#472C3A")
    var outfit = AvatarPart(id: "orchard-overalls", colorHex: "#E65F91")
    var shoes = AvatarPart(id: "garden-boots", colorHex: "#735049")
    var accessories: [AvatarPart] = []
    var glasses: AvatarPart? = nil
    var hat: AvatarPart? = nil
    var backpack: AvatarPart? = nil
    var metadata: [String: String] = [:]

    static let starter = AvatarConfiguration()
}

extension AvatarConfiguration {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        base = try values.decodeIfPresent(String.self, forKey: .base) ?? base
        skin = try values.decodeIfPresent(AvatarPart.self, forKey: .skin) ?? skin
        hair = try values.decodeIfPresent(AvatarPart.self, forKey: .hair) ?? hair
        outfit = try values.decodeIfPresent(AvatarPart.self, forKey: .outfit) ?? outfit
        shoes = try values.decodeIfPresent(AvatarPart.self, forKey: .shoes) ?? shoes
        accessories = try values.decodeIfPresent([AvatarPart].self, forKey: .accessories) ?? []
        glasses = try values.decodeIfPresent(AvatarPart.self, forKey: .glasses)
        hat = try values.decodeIfPresent(AvatarPart.self, forKey: .hat)
        backpack = try values.decodeIfPresent(AvatarPart.self, forKey: .backpack)
        metadata = try values.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}

enum CharacterCatalog {
    static let all: [CharacterDefinition] = [
        .init(id: "player", displayName: String(localized: "You"), role: .player,
              portraitID: "orchard-child", expressions: CharacterExpression.allCases,
              relationship: String(localized: "Our newest explorer"), unlocked: true),
        .init(id: "grandpa", displayName: String(localized: "Grandpa"), role: .grandparent,
              portraitID: "grandpa-cedar", expressions: CharacterExpression.allCases,
              relationship: String(localized: "Your grandfather"), unlocked: true,
              metadata: ["home": "orchard-house", "keepsake": "memory-box"]),
        .init(id: "parent", displayName: String(localized: "Mum"), role: .parent,
              portraitID: "parent-juniper", expressions: CharacterExpression.allCases,
              relationship: String(localized: "Your mother"), unlocked: false,
              metadata: ["home": "orchard-house"])
    ]

    static func definition(for id: String) -> CharacterDefinition? {
        all.first { $0.id == id }
    }
}

// MARK: - One opening. New chapters can use the same graph and presentation.

enum StoryCatalog {
    static let chapters: [StoryChapter] = [
        .init(id: "family-roots", title: String(localized: "Family roots"),
              summary: String(localized: "An old map. A familiar home. A new beginning."),
              sceneIDs: ["the-memory-box"])
    ]

    static let opening = StoryScene(
        id: "the-memory-box", chapterID: "family-roots",
        title: String(localized: "The memory box"), settingID: "orchard-house",
        entryBeatID: "grandpas-box",
        beats: [
            .init(id: "grandpas-box",
                  dialogue: .init(id: "grandpa-keepsake", speakerID: "grandpa",
                    text: String(localized: "Come closer. I found our old memory box. This map holds places our family loves — and tonight, its paths are glowing!"),
                    expression: .thoughtful),
                  characterIDs: ["grandpa", "player"], propID: "memory-box",
                  nextBeatID: "your-question"),
            .init(id: "your-question",
                  dialogue: .init(id: "grandpa-invitation", speakerID: "grandpa",
                    text: String(localized: "The fireflies have lost their light, and frost is covering the fruit. The map is asking for a little help. Shall we look?"),
                    expression: .hopeful),
                  characterIDs: ["grandpa", "player"], propID: "orchard-map",
                  choices: [
                    .init(id: "ask-about-place", title: String(localized: "What is this place?"),
                          nextBeatID: "a-place-to-belong", flags: ["opening.curiosity"]),
                    .init(id: "offer-help", title: String(localized: "I'll help."),
                          nextBeatID: "a-helping-hand", flags: ["opening.help"])
                  ]),
            .init(id: "a-place-to-belong",
                  dialogue: .init(id: "grandpa-remembers", speakerID: "grandpa",
                    text: String(localized: "A doorway to places in our memories. Your mum and I followed these paths once. Now they're opening for you."),
                    expression: .warm),
                  characterIDs: ["grandpa", "player"], propID: "orchard-map",
                  nextBeatID: "mum-comes-home"),
            .init(id: "a-helping-hand",
                  dialogue: .init(id: "grandpa-thanks", speakerID: "grandpa",
                    text: String(localized: "I was hoping you'd say that. We don't have to bring it all back today. One small start, together."),
                    expression: .hopeful),
                  characterIDs: ["grandpa", "player"], propID: "orchard-map",
                  nextBeatID: "mum-comes-home"),
            .init(id: "mum-comes-home",
                  dialogue: .init(id: "mum-recognises-map", speakerID: "parent",
                    text: String(localized: "Is that our old map? I remember that patch! Start with a few fruits. We'll be right here cheering you on."),
                    expression: .warm),
                  characterIDs: ["grandpa", "parent", "player"], propID: "orchard-map",
                  nextBeatID: "a-new-beginning"),
            .init(id: "a-new-beginning",
                  dialogue: .init(id: "grandpa-first-step", speakerID: "grandpa",
                    text: String(localized: "Shall we take the first step? Match the fruits, follow your goals, and let's see where our map leads."),
                    expression: .hopeful),
                  characterIDs: ["grandpa", "parent", "player"], propID: "orchard-map")
        ], triggers: [.beforeLevel(1)], completionFlags: ["opening.finished"],
        metadata: ["entry": "home", "handoff": "campaign"])

    static var scenes: [StoryScene] { [opening] }
}

enum StoryAdvanceResult: Equatable { case advanced, completed, invalid }

/// A playthrough is a small value. Replays never share its cursor or choices
/// with the saved first playthrough.
struct StoryPresentation: Equatable {
    let scene: StoryScene
    let isReplay: Bool
    private(set) var beatID: String
    private(set) var selectedChoices: [String: String]
    private(set) var flags: Set<String>
    private(set) var revealedCharacterIDs: Set<String>
    private(set) var isFinished = false

    init(scene: StoryScene, isReplay: Bool, beatID: String? = nil,
         selectedChoices: [String: String] = [:], flags: Set<String> = [],
         revealedCharacterIDs: Set<String> = []) {
        self.scene = scene
        self.isReplay = isReplay
        self.beatID = beatID.flatMap { scene.beat(id: $0)?.id } ?? scene.entryBeatID
        self.selectedChoices = selectedChoices
        self.flags = flags
        self.revealedCharacterIDs = revealedCharacterIDs
        if let beat = scene.beat(id: self.beatID) {
            self.revealedCharacterIDs.formUnion(beat.characterIDs)
        }
    }

    var currentBeat: StoryBeat? { scene.beat(id: beatID) }

    @discardableResult
    mutating func advance(choosing choiceID: String? = nil) -> StoryAdvanceResult {
        guard !isFinished, let beat = currentBeat else { return .invalid }
        let nextID: String?
        let choice: StoryChoice?
        if beat.choices.isEmpty {
            guard choiceID == nil else { return .invalid }
            choice = nil
            nextID = beat.nextBeatID
        } else {
            guard let choiceID, let selected = beat.choices.first(where: { $0.id == choiceID }) else {
                return .invalid
            }
            choice = selected
            nextID = selected.nextBeatID
        }
        if let nextID, scene.beat(id: nextID) == nil { return .invalid }
        if let choice {
            selectedChoices[beat.id] = choice.id
            flags.formUnion(choice.flags)
        }
        guard let nextID, let next = scene.beat(id: nextID) else {
            flags.formUnion(scene.completionFlags)
            isFinished = true
            return .completed
        }
        beatID = nextID
        revealedCharacterIDs.formUnion(next.characterIDs)
        return .advanced
    }
}
