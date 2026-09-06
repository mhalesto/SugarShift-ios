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
        // The hero must be readable before the impact. Reference clips reserve
        // a distinct travel/anticipation beat and an aftermath before refill.
        let anticipation: TimeInterval = style == .whaleWave ? 0.52 : 0.34
        return WorldComboSequence(impactAt: anticipation,
            lastTileImpactAt: anticipation + 0.32, finishesAt: anticipation + 0.76,
            particleCount: min(48, min(affectedCount, 24) * 2),
            linkCount: min(16, affectedCount), shakeStrength: style == .eruption ? 9 : 5)
    }
}
