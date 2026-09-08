import SpriteKit

/// The narrow adapter between resolved mechanical facts and the world animator.
extension GameScene {
    /// Resolution shares the board's clock, including existing slow-motion cues.
    /// A restart cancels this one transition before installing the next board.
    func scheduleBoardResolution(after duration: TimeInterval, _ action: @escaping (GameScene) -> Void) {
        worldNode.run(.sequence([.wait(forDuration: max(0, duration)), .run { [weak self] in
            guard let self else { return }
            action(self)
        }]), withKey: "boardResolutionTransition")
    }

    @discardableResult
    func presentResolvedClear(_ result: ClearResult,
                              delay: (Pos) -> TimeInterval = { _ in 0 }) -> TimeInterval {
        var sources: [Pos: SKNode] = [:]
        for p in result.cleared.union(result.damagedBlockers) {
            sources[p] = nodes[p.r][p.c]
        }
        let duration = worldEffects.animateClear(result, sources: sources, delay: delay)
        for p in result.cleared { nodes[p.r][p.c] = nil }
        for event in result.presentationEvents {
            if case .blockerHit(_, let blocker) = event, blocker.type == .chocolate {
                chocolateDamagedThisTurn = true
            }
        }
        return duration
    }

    /// Subtotals preserve the exact scoring receipt, including double-credit
    /// piece/layer clears and the real banana modifier. No invented popup values.
    func presentClearScore(_ result: ClearResult, preClear: [Pos: Cell],
                           pointsPerTile: Int, multiplier: Int,
                           delay: (Pos) -> TimeInterval = { _ in 0 }) {
        let affected = result.cleared.union(result.damagedBlockers).sorted {
            $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r
        }
        let groupCount = SignatureMotion.isReduced ? 1 : min(4, max(1, affected.count / 8))
        let groups = ScorePopupReceipt.grouped(result: result, preClear: preClear,
            pointsPerTile: pointsPerTile, multiplier: multiplier,
            doublesBananas: levelConfig.modifiers.contains(.bananaScoreDouble), groupCount: groupCount)
        for group in groups {
            Effects.showScorePopup(group.points,
                at: point(forRow: group.position.r, col: group.position.c), in: self,
                color: worldTheme.glowColor, delay: SignatureMotion.isReduced ? 0 : delay(group.position),
                maxVisible: groupCount)
        }
    }
}

/// A bounded rhythm over the real footprint. This neither computes nor changes
/// damage. Direct matches start first; secondary special origins follow in order.
struct CascadePresentationTiming {
    let activations: [Pos]
    let matched: Set<Pos>
    let specials: [SpecialPresentationPlan]
    private let activationTimes: [Pos: TimeInterval]

    init(events: [GamePresentationEvent], matched: Set<Pos>, specials: [SpecialPresentationPlan] = []) {
        let origins = events.compactMap { event -> Pos? in
            if case .specialActivated(let p, _) = event { return p }
            return nil
        }
        activations = origins
        self.matched = matched
        self.specials = specials
        var pending: [Pos: TimeInterval] = [:]
        var times: [Pos: TimeInterval] = [:]
        for (index, origin) in origins.filter({ matched.contains($0) }).enumerated() {
            pending[origin] = 0.05 + Double(min(index, 8)) * 0.035
        }
        // Visit each real activation once. A secondary special waits for the
        // beam/fish that reaches it; cycles cannot keep extending the sequence.
        while times.count < origins.count {
            if pending.isEmpty, let next = origins.first(where: { times[$0] == nil }) {
                pending[next] = 0.05 + Double(min(times.count, 8)) * 0.035
            }
            guard let next = pending.min(by: {
                $0.value == $1.value
                    ? ($0.key.r == $1.key.r ? $0.key.c < $1.key.c : $0.key.r < $1.key.r)
                    : $0.value < $1.value
            }) else { break }
            pending.removeValue(forKey: next.key)
            let time = min(0.65, next.value)
            times[next.key] = time
            guard let source = specials.first(where: { $0.origin == next.key }) else { continue }
            for target in origins where times[target] == nil && !matched.contains(target) && source.footprint.contains(target) {
                let arrival = time + max(0.045, source.travelDelay(to: target))
                pending[target] = min(pending[target] ?? arrival, arrival)
            }
        }
        activationTimes = times
    }

    func activationDelay(_ position: Pos) -> TimeInterval {
        activationTimes[position] ?? 0
    }

    func delay(_ position: Pos) -> TimeInterval {
        if activations.contains(position) { return activationDelay(position) }
        guard !activations.isEmpty, !matched.contains(position) else { return 0 }
        let arrivals = specials.filter { activations.contains($0.origin) && $0.footprint.contains(position) }
            .map { activationDelay($0.origin) + $0.travelDelay(to: position) }
        if let first = arrivals.min() { return min(0.90, first) }
        return activations.map { origin in
            activationDelay(origin) + 0.025 * Double(max(abs(position.r - origin.r), abs(position.c - origin.c)))
        }.min().map { min(0.42, $0) } ?? 0
    }
}
