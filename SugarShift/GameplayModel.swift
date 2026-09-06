import Foundation

/// Stable gameplay identity for the seven match-piece families. Rendering and
/// legacy hex tokens are adapters; match logic can depend on this type without
/// depending on art or UIKit.
enum PieceColor: String, CaseIterable, Codable, Hashable {
    case orange
    case grape
    case blueberry
    case leaf
    case banana
    case heart
    case strawberry

    static let legacyPalette: [String] = [
        "#F97316", "#22D3EE", "#10B981", "#A78BFA",
        "#F59E0B", "#EF4444", "#EC4899"
    ]

    var legacyToken: String {
        PieceColor.legacyPalette[PieceColor.allCases.firstIndex(of: self) ?? 0]
    }

    static func fromLegacyPaletteIndex(_ index: Int) -> PieceColor {
        let colors = PieceColor.allCases
        guard !colors.isEmpty else { return .orange }
        // The removed eighth mango identity intentionally folds into orange.
        if index == 7 { return .orange }
        return colors[max(0, index) % colors.count]
    }

    static func fromLegacyToken(_ token: String) -> PieceColor {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let index = legacyPalette.firstIndex(where: { $0.lowercased() == normalized }) {
            return fromLegacyPaletteIndex(index)
        }
        switch normalized {
        case "orange", "r", "red", "mango": return .orange
        case "grape", "g", "purple": return .grape
        case "blueberry", "b", "blue", "cyan": return .blueberry
        case "leaf", "l", "green": return .leaf
        case "banana", "y", "yellow", "amber": return .banana
        case "heart", "h": return .heart
        case "strawberry", "p", "pink": return .strawberry
        default:
            var hash = 0
            for scalar in normalized.unicodeScalars {
                hash = (hash &* 31) &+ Int(scalar.value)
            }
            return fromLegacyPaletteIndex(Int(hash.magnitude % UInt(PieceColor.allCases.count)))
        }
    }
}

enum CellKind: String, Codable, Hashable {
    case normal
    case ingredient
    case key
}

enum BoardTileKind: String, CaseIterable, Codable, Hashable {
    case normal
    case portal
    case conveyor
    case cake
    case cookie
    case waffle
    case chocolate
    case frosting
    case candy
}

enum BlockerType: String, CaseIterable, Codable, Hashable {
    case ice
    case lock
    case jelly
    case crate
    case colorLock = "color-lock"
    case chest
    case vine
    case chocolate
    case syrup
    case countdown
    case honey
    case stone
    case cage
    case licorice
    case solidX = "solid-x"
    case cream
    case bubble
    case magicFrost = "magic-frost"
    case donut
}

enum BlockerDestructionRule: String, CaseIterable, Codable, Hashable {
    case directMatch
    case adjacentMatch
    case special
    case combo
    case hammer
    case key
    case indestructible
}

struct BlockerRules: Equatable, Codable {
    let canContainPiece: Bool
    let canFall: Bool
    let blocksMovement: Bool
    let blocksBlast: Bool
    let spreads: Bool
    let clearsPieceWithLayer: Bool
    let destructionRules: Set<BlockerDestructionRule>

    func canBeDamaged(by source: BlockerDamageSource, adjacent: Bool) -> Bool {
        guard !destructionRules.contains(.indestructible) else { return false }
        if adjacent, !destructionRules.contains(.adjacentMatch) { return false }
        switch source {
        case .normalMatch:
            return destructionRules.contains(adjacent ? .adjacentMatch : .directMatch)
        case .special:
            return destructionRules.contains(.special)
        case .combo:
            return destructionRules.contains(.combo)
        case .hammer:
            return destructionRules.contains(.hammer)
        case .key:
            return destructionRules.contains(.key)
        }
    }
}

extension BlockerType {
    /// The sole gameplay policy table for obstacle behavior. Callers ask the
    /// model instead of growing feature-specific switches in scene code.
    var rules: BlockerRules {
        let normal: Set<BlockerDestructionRule> = [.directMatch, .special, .combo, .hammer]
        let adjacent: Set<BlockerDestructionRule> = [.directMatch, .adjacentMatch, .special, .combo, .hammer]
        switch self {
        case .ice, .bubble:
            return BlockerRules(canContainPiece: true, canFall: false,
                                blocksMovement: false, blocksBlast: false,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: normal)
        case .jelly:
            return BlockerRules(canContainPiece: true, canFall: false,
                                blocksMovement: false, blocksBlast: false,
                                spreads: false, clearsPieceWithLayer: true,
                                destructionRules: normal)
        case .honey, .lock, .cage, .colorLock, .vine, .syrup, .countdown:
            return BlockerRules(canContainPiece: true, canFall: false,
                                blocksMovement: true, blocksBlast: false,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: normal)
        case .crate, .stone, .cream, .donut:
            return BlockerRules(canContainPiece: false, canFall: false,
                                blocksMovement: true, blocksBlast: false,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: adjacent)
        case .licorice:
            return BlockerRules(canContainPiece: false, canFall: false,
                                blocksMovement: true, blocksBlast: true,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: [.adjacentMatch, .special, .combo, .hammer])
        case .solidX:
            return BlockerRules(canContainPiece: false, canFall: false,
                                blocksMovement: true, blocksBlast: true,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: [.indestructible])
        case .magicFrost:
            return BlockerRules(canContainPiece: true, canFall: false,
                                blocksMovement: false, blocksBlast: false,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: [.special, .combo, .hammer])
        case .chest:
            return BlockerRules(canContainPiece: false, canFall: false,
                                blocksMovement: true, blocksBlast: false,
                                spreads: false, clearsPieceWithLayer: false,
                                destructionRules: [.adjacentMatch, .special, .combo, .hammer, .key])
        case .chocolate:
            return BlockerRules(canContainPiece: false, canFall: false,
                                blocksMovement: true, blocksBlast: false,
                                spreads: true, clearsPieceWithLayer: false,
                                destructionRules: adjacent)
        }
    }
}

struct Blocker: Codable, Hashable {
    var type: BlockerType
    var hits: Int
    var requiredColor: String? = nil
    var countdown: Int? = nil
    var layer: Int
    var requiredKeys: Int? = nil

    init(type: BlockerType,
         hits: Int,
         requiredColor: String? = nil,
         countdown: Int? = nil,
         layer: Int? = nil,
         requiredKeys: Int? = nil) {
        self.type = type
        self.hits = max(1, hits)
        self.requiredColor = requiredColor
        self.countdown = countdown
        self.layer = max(1, layer ?? hits)
        self.requiredKeys = requiredKeys
    }
}

struct Piece: Codable, Hashable {
    var id: String
    var color: PieceColor
    var legacyColorToken: String
    var special: Special?
    var kind: CellKind

    init(id: String,
         color: PieceColor,
         special: Special? = nil,
         kind: CellKind = .normal,
         legacyColorToken: String? = nil) {
        self.id = id
        self.color = color
        self.legacyColorToken = legacyColorToken ?? color.legacyToken
        self.special = special
        self.kind = kind
    }

    init(id: String,
         legacyColorToken: String,
         special: Special? = nil,
         kind: CellKind = .normal) {
        self.init(id: id,
                  color: PieceColor.fromLegacyToken(legacyColorToken),
                  special: special,
                  kind: kind,
                  legacyColorToken: legacyColorToken)
    }
}

struct BoardTile: Codable, Hashable {
    var kind: BoardTileKind
    var blocker: Blocker?

    init(kind: BoardTileKind = .normal, blocker: Blocker? = nil) {
        self.kind = kind
        self.blocker = blocker
    }
}

/// A playable board slot. `nil` in Grid remains a shape hole; an empty playable
/// slot is a non-nil Cell whose piece is nil and whose fixed tile metadata stays.
struct Cell: Codable, Hashable {
    var piece: Piece?
    var tile: BoardTile

    init(piece: Piece?, tile: BoardTile = BoardTile()) {
        self.piece = piece
        self.tile = tile
    }

    init(id: String,
         color: String,
         special: Special?,
         kind: CellKind,
         blocker: Blocker? = nil) {
        piece = Piece(id: id,
                      legacyColorToken: color,
                      special: special,
                      kind: kind)
        tile = BoardTile(blocker: blocker)
    }

    var id: String {
        get { piece?.id ?? "" }
        set {
            if piece == nil { piece = Piece(id: newValue, color: .orange) }
            else { piece?.id = newValue }
        }
    }

    var color: String {
        get { piece?.legacyColorToken ?? PieceColor.orange.legacyToken }
        set {
            if piece == nil { piece = Piece(id: "", legacyColorToken: newValue) }
            else {
                piece?.legacyColorToken = newValue
                piece?.color = PieceColor.fromLegacyToken(newValue)
            }
        }
    }

    var special: Special? {
        get { piece?.special }
        set {
            if piece == nil, newValue != nil { piece = Piece(id: "", color: .orange) }
            piece?.special = newValue
        }
    }

    var kind: CellKind {
        get { piece?.kind ?? .normal }
        set {
            if piece == nil { piece = Piece(id: "", color: .orange, kind: newValue) }
            else { piece?.kind = newValue }
        }
    }

    var blocker: Blocker? {
        get { tile.blocker }
        set { tile.blocker = newValue }
    }

    var hasPiece: Bool { piece != nil }
    var isMatchable: Bool { hasPiece && kind == .normal && blocker?.type.rules.canContainPiece != false }
    var isMovementBlocked: Bool { blocker?.type.rules.blocksMovement == true }
}

enum BlockerDamageSource: String, Codable, Hashable {
    case normalMatch
    case special
    case combo
    case hammer
    case key
}

struct ClearContext: Equatable, Codable {
    var source: BlockerDamageSource
    var damagesAdjacentBlockers: Bool
    var respectsBlastWalls: Bool

    init(source: BlockerDamageSource = .normalMatch,
         damagesAdjacentBlockers: Bool = true,
         respectsBlastWalls: Bool = true) {
        self.source = source
        self.damagesAdjacentBlockers = damagesAdjacentBlockers
        self.respectsBlastWalls = respectsBlastWalls
    }

    static let normal = ClearContext()
    static let normalIncludingAdjacent = ClearContext(damagesAdjacentBlockers: true)
    static let special = ClearContext(source: .special)
    static let combo = ClearContext(source: .combo)
    static let hammer = ClearContext(source: .hammer)
}

struct SpecialActivationStage: Equatable {
    let index: Int
    let origin: Pos
    let special: Special
    let positions: Set<Pos>
}

struct SpecialActivationResolution: Equatable {
    let positions: Set<Pos>
    let stages: [SpecialActivationStage]
}
