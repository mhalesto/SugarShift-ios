// Runs the production timing policy directly, without booting iOS or Xcode.
// swiftc -D WORLD_COMBO_CHECKS SugarShift/WorldComboPolicy.swift tools/check_world_combo.swift -o /tmp/ss-world-check
#if WORLD_COMBO_CHECKS
import Foundation

@main struct WorldComboChecks {
    static func main() {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        check(WorldComboPolicy.sequence(cue: .ordinary, style: .eruption, affectedCount: 42, reduceMotion: false) == nil,
              "An ordinary clear must never trigger a world hero")
        check(WorldComboPolicy.sequence(cue: .powerfulPair, style: .eruption, affectedCount: 0, reduceMotion: false) == nil,
              "A clear that affects nothing must not trigger a world hero")
        let eruption = WorldComboPolicy.sequence(cue: .powerfulPair, style: .eruption, affectedCount: 42, reduceMotion: false)
        check(eruption != nil, "A resolved high-value special pair must get an eruption sequence")
        check((eruption?.impactAt ?? 0) > 0, "Eruption must anticipate before impact")
        check((eruption?.finishesAt ?? 0) >= (eruption?.lastTileImpactAt ?? 0) + 0.20,
              "Input cannot return before the last tile finishes popping")
        let whale = WorldComboPolicy.sequence(cue: .megaSmash, style: .whaleWave, affectedCount: 999, reduceMotion: false)
        check(whale != nil && (whale?.particleCount ?? 999) <= 48 && (whale?.linkCount ?? 999) <= 16,
              "Earned mega effects must cap particles and links on very large boards")
        let reduced = WorldComboPolicy.sequence(cue: .powerfulPair, style: .eruption, affectedCount: 42, reduceMotion: true)
        check(reduced?.impactAt == 0 && reduced?.particleCount == 0 && reduced?.shakeStrength == 0,
              "Reduce Motion removes travel, debris and shake without suppressing the clear")
        if failures.isEmpty { print("PASS: world combo trigger, timing, cleanup and accessibility checks") }
        else { failures.forEach { print("FAIL: \($0)") }; exit(1) }
    }
}
#endif
