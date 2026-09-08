import Foundation

/// Presentation timing only. No board mutation, world-specific matching rules,
/// currency or random gameplay decisions belong in this layer.
enum WorldComboStyle: CaseIterable { case sugar, frost, honey, eruption, whaleWave, rainbow, amber, firefly, sandstorm, cosmic, petal }
enum WorldComboCue { case ordinary, powerfulPair, megaSmash, worldSpecial }

struct WorldComboSequence {
    let impactAt: TimeInterval
    let lastTileImpactAt: TimeInterval
    let finishesAt: TimeInterval
    let particleCount: Int
    let linkCount: Int
    let shakeStrength: Double

    /// The same timestamp drives the tile and its travelling material cue.
    /// Presentation may shorten an authored delay, never invent another clear.
    func tileImpactDelay(normalDelay: TimeInterval) -> TimeInterval {
        impactAt + min(max(0, normalDelay), max(0, lastTileImpactAt - impactAt))
    }
}

enum WorldComboPolicy {
    static func sequence(cue: WorldComboCue, style: WorldComboStyle,
                         affectedCount: Int, reduceMotion: Bool) -> WorldComboSequence? {
        guard cue != .ordinary, affectedCount > 0 else { return nil }
        guard cue != .worldSpecial || affectedCount >= 12 else { return nil }
        if reduceMotion {
            return WorldComboSequence(impactAt: 0, lastTileImpactAt: 0,
                finishesAt: 0.22, particleCount: 0, linkCount: 0, shakeStrength: 0)
        }
        // Each material has its own rhythm. The longest full sequence is 1.22s;
        // the aftermath always includes the last tile's 0.18s clear animation.
        let anticipation: TimeInterval
        let travel: TimeInterval
        let settle: TimeInterval
        let shake: Double
        switch style {
        case .sugar:     (anticipation, travel, settle, shake) = (0.28, 0.25, 0.34, 3)
        case .frost:     (anticipation, travel, settle, shake) = (0.24, 0.22, 0.32, 4)
        case .honey:     (anticipation, travel, settle, shake) = (0.36, 0.28, 0.40, 3)
        case .eruption:  (anticipation, travel, settle, shake) = (0.40, 0.30, 0.40, 8)
        case .whaleWave: (anticipation, travel, settle, shake) = (0.50, 0.32, 0.40, 4)
        case .rainbow:   (anticipation, travel, settle, shake) = (0.34, 0.28, 0.36, 2)
        case .amber:     (anticipation, travel, settle, shake) = (0.28, 0.26, 0.34, 4)
        case .firefly:   (anticipation, travel, settle, shake) = (0.40, 0.34, 0.30, 0)
        case .sandstorm: (anticipation, travel, settle, shake) = (0.42, 0.28, 0.36, 3)
        case .cosmic:    (anticipation, travel, settle, shake) = (0.42, 0.30, 0.40, 5)
        case .petal:     (anticipation, travel, settle, shake) = (0.36, 0.30, 0.38, 0)
        }
        return WorldComboSequence(impactAt: anticipation,
            lastTileImpactAt: anticipation + travel, finishesAt: anticipation + travel + settle,
            particleCount: min(36, min(affectedCount, 18) * 2),
            linkCount: min(14, affectedCount), shakeStrength: shake)
    }
}
