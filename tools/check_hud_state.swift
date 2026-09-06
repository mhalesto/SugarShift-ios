// Native checks for the production ObjectiveTracker and HUDScoreProgress.
// No simulator, app launch, inventory writes, or network calls.
import Foundation

@main struct HUDStateChecks {
    static func main() throws {
        var tracker = ObjectiveTracker(objectives: [.breakBlockers(count: 4)])
        tracker.consume(.blockerDestroyed(type: .ice, count: 2))
        tracker.consume(.blockerDestroyed(type: .lock, count: 1))
        precondition(tracker.progresses[0].current == 3)
        precondition(tracker.destroyedBlockers[.ice] == 2 && tracker.destroyedBlockers[.lock] == 1)
        precondition(!tracker.isComplete)
        let snapshot = tracker
        tracker.consume(.blockerDestroyed(type: .jelly, count: 1))
        precondition(tracker.isComplete)
        tracker = snapshot
        precondition(!tracker.isComplete && tracker.destroyedBlockers[.jelly] == nil)
        tracker.consume(.blockerDestroyed(type: .ice, count: -4))
        precondition(tracker == snapshot)
        let encoded = try JSONEncoder().encode(tracker)
        let roundTrip = try JSONDecoder().decode(ObjectiveTracker.self, from: encoded)
        precondition(roundTrip == tracker)
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacy.removeValue(forKey: "destroyedBlockers")
        let restored = try JSONDecoder().decode(ObjectiveTracker.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(restored.progresses[0].current == 3 && restored.destroyedBlockers.isEmpty)
        let thresholds = (one: 8_000, two: 9_000, three: 10_000)
        precondition(HUDScoreProgress.fraction(score: 0, thresholds: thresholds) == 0)
        for (index, score) in [8_000, 9_000, 10_000].enumerated() {
            precondition(abs(HUDScoreProgress.fraction(score: score, thresholds: thresholds) - HUDScoreProgress.starStops[index]) < 0.0001)
        }
        let fractions = stride(from: 0, through: 14_000, by: 50).map { HUDScoreProgress.fraction(score: $0, thresholds: thresholds) }
        precondition(zip(fractions, fractions.dropFirst()).allSatisfy { $0 <= $1 })
        precondition(fractions.allSatisfy { (0...1).contains($0) })
        print("PASS: objective totals, per-type counters, Undo snapshot, legacy decoding, and score/star alignment")
    }
}
