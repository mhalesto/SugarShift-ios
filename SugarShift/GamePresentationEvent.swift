import Foundation

/// Semantic facts only. No textures, UIKit, timing or world names enter the engine.
enum GamePresentationEvent: Equatable {
    case pieceMatched(at: Pos, piece: Piece)
    case pieceDestroyed(at: Pos, piece: Piece)
    case pieceCreated(at: Pos, piece: Piece)
    case blockerHit(at: Pos, blocker: Blocker)
    case blockerDamaged(at: Pos, before: Blocker, after: Blocker)
    case blockerDestroyed(at: Pos, blocker: Blocker)
    case objectiveItemCollected(at: Pos, objectiveIndex: Int)
    case objectiveCompleted(index: Int)
    case specialCreated(at: Pos, special: Special)
    case specialActivated(at: Pos, special: Special)
    case specialChainTriggered(positions: [Pos])
    case cascadeStarted
    case cascadeAdvanced(depth: Int)
    case comboTriggered(kind: SpecialComboKind, positions: [Pos])
    case worldComboTriggered(positions: [Pos])
    case portalEntered(from: Pos, to: Pos)
    case boardSettled

    var position: Pos? {
        switch self {
        case .pieceMatched(let p, _), .pieceDestroyed(let p, _), .pieceCreated(let p, _),
             .blockerHit(let p, _), .blockerDamaged(let p, _, _), .blockerDestroyed(let p, _),
             .objectiveItemCollected(let p, _), .specialCreated(let p, _), .specialActivated(let p, _): return p
        case .portalEntered(let p, _): return p
        case .specialChainTriggered(let positions), .worldComboTriggered(let positions),
             .comboTriggered(_, let positions): return positions.first
        default: return nil
        }
    }
}

/// Values collected at the engine boundary; existing callers can keep using Grid.
struct BoardRefillResult {
    let grid: Grid
    let presentationEvents: [GamePresentationEvent]
    let portalTransfers: [PortalPresentationTransfer]
}

struct PortalPresentationTransfer: Equatable {
    let pieceID: String
    let from: Pos
    let to: Pos
}

/// Presentation selects only actual contributors to an objective's recorded delta.
/// The tracker remains the sole authority for progress and completion.
enum ObjectivePresentationPolicy {
    static func contributes(_ event: GamePresentationEvent, to objective: LevelObjective) -> Bool {
        switch (objective, event) {
        case (.collectPieces(let color, _), .pieceDestroyed(_, let piece)):
            return piece.color == color
        case (.destroySpecificBlocker(let type, _), .blockerDestroyed(_, let blocker)):
            return blocker.type == type
        case (.breakBlockers, .blockerDestroyed): return true
        case (.breakIce, .blockerDestroyed(_, let blocker)): return blocker.type == .ice
        case (.clearJelly, .blockerDestroyed(_, let blocker)): return blocker.type == .jelly
        case (.clearChocolate, .blockerDestroyed(_, let blocker)): return blocker.type == .chocolate
        case (.freePieces, .blockerDestroyed(_, let blocker)):
            return [.lock, .colorLock, .cage, .vine].contains(blocker.type)
        case (.createSpecials, .specialCreated): return true
        case (.detonateBombs, .specialActivated(_, .bomb)): return true
        default: return false
        }
    }
}
