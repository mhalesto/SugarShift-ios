#if DEBUG
import SpriteKit

extension GameScene {
    /// Test-only readout of real engine state; does not seed counters, perform
    /// moves or expose a shipping cheat. UI tests still swipe the actual board.
    func updateUITestReadout() {
        guard UserDefaults.standard.bool(forKey: "ss.dev.uiTesting"), let view else { return }
        var state: [String: Any] = ["moves": movesLeft, "score": score,
                                   "phase": gamePhase.rawValue, "resolving": isResolving,
                                   "cash": cash, "lives": Persistence.lives,
                                   "hammer": hammerCount, "booster": String(describing: boosterMode),
                                   "objectiveProgress": objectiveTracker.progressFraction]
        if canAcceptBoardInput, let move = Engine.findHintMove(grid) {
            let a = convertPoint(toView: point(forRow: move.0.r, col: move.0.c))
            let b = convertPoint(toView: point(forRow: move.1.r, col: move.1.c))
            state["swipe"] = [a.x / view.bounds.width, a.y / view.bounds.height,
                               b.x / view.bounds.width, b.y / view.bounds.height]
        }
        let hammer = boosterCircles["Hammer"].map { convertPoint(toView: $0.convert(.zero, to: self)) }
        if let hammer { state["hammerPoint"] = [hammer.x / view.bounds.width, hammer.y / view.bounds.height] }
        if let data = try? JSONSerialization.data(withJSONObject: state), let value = String(data: data, encoding: .utf8) {
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = "ss.game"
            view.accessibilityLabel = "Sugar Shift gameplay"
            view.accessibilityValue = value
        }
    }
}
#endif
