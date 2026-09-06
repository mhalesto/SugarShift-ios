import Foundation

/// Presentation timing only. No board mutation, world-specific matching rules,
/// currency or random gameplay decisions belong in this layer.
enum WorldComboStyle { case eruption, whaleWave }
enum WorldComboCue { case ordinary, powerfulPair, megaSmash }

struct WorldComboSequence {
    let impactAt: TimeInterval
    let lastTileImpactAt: TimeInterval
    let finishesAt: TimeInterval
    let particleCount: Int
    let linkCount: Int
    let shakeStrength: Double
}

enum WorldComboPolicy {
    static func sequence(cue: WorldComboCue, style: WorldComboStyle,
                         affectedCount: Int, reduceMotion: Bool) -> WorldComboSequence? {
        guard cue != .ordinary, affectedCount > 0 else { return nil }
        if reduceMotion {
            return WorldComboSequence(impactAt: 0, lastTileImpactAt: 0,
                finishesAt: 0.22, particleCount: 0, linkCount: 0, shakeStrength: 0)
        }
        let anticipation: TimeInterval = style == .eruption ? 0.18 : 0.24
        return WorldComboSequence(impactAt: anticipation,
            lastTileImpactAt: anticipation + 0.14, finishesAt: anticipation + 0.42,
            particleCount: min(48, min(affectedCount, 24) * 2),
            linkCount: min(16, affectedCount), shakeStrength: style == .eruption ? 9 : 5)
    }
}
