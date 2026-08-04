import Foundation

/// How loudly a single cascade step celebrates. Tiers are strictly ordered:
/// every screen-wide channel (banner, shake, confetti) unlocks at a
/// higher tier than the one before it, so big moments stay distinguishable
/// from routine matches. Pure and deterministic — this is the first slice of
/// turn resolution lifted out of `GameScene+SwapCascade` behind a testable
/// seam.
enum ClearFeedbackTier: Int, Comparable, CaseIterable {
    /// Any ordinary clear: score popup, tile bursts, light haptic.
    case match
    /// First rung of celebration: banner + medium haptic.
    case nice
    /// Adds a small screen shake. Directional beams belong only to specials.
    case big
    /// Success haptic and a strong shake.
    case huge
    /// Confetti. Reserved for genuinely deep cascades.
    case epic

    static func < (lhs: ClearFeedbackTier, rhs: ClearFeedbackTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ClearFeedback: Equatable {
    enum Haptic: Equatable {
        case light
        case medium
        case success
    }

    let tier: ClearFeedbackTier
    let showsBanner: Bool
    let showsBeam: Bool
    /// Screen-shake amplitude in points; nil means no shake.
    let shakeIntensity: Double?
    let spawnsConfetti: Bool
    let haptic: Haptic
}

enum TurnFeedbackPolicy {

    static func tier(depth: Int, cleared: Int) -> ClearFeedbackTier {
        let byDepth: ClearFeedbackTier
        switch depth {
        case ..<2:  byDepth = .match
        case 2:     byDepth = .nice
        case 3:     byDepth = .big
        case 4:     byDepth = .huge
        default:    byDepth = .epic
        }
        let byCleared: ClearFeedbackTier
        switch cleared {
        case ..<5:   byCleared = .match
        case 5...6:  byCleared = .nice
        case 7...8:  byCleared = .big
        default:     byCleared = .huge
        }
        return max(byDepth, byCleared)
    }

    static func feedback(depth: Int, cleared: Int) -> ClearFeedback {
        let tier = tier(depth: depth, cleared: cleared)
        let shake: Double?
        switch tier {
        case .match, .nice: shake = nil
        case .big:          shake = 6
        case .huge:         shake = 9
        case .epic:         shake = 12
        }
        let haptic: ClearFeedback.Haptic
        switch tier {
        case .match:       haptic = .light
        case .nice, .big:  haptic = .medium
        case .huge, .epic: haptic = .success
        }
        return ClearFeedback(tier: tier,
                             showsBanner: tier >= .nice,
                             showsBeam: false,
                             shakeIntensity: shake,
                             spawnsConfetti: tier == .epic,
                             haptic: haptic)
    }
}
