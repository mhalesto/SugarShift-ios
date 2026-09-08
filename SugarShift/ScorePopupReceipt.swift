import Foundation

struct ScorePopupReceipt: Equatable {
    let position: Pos
    let points: Int

    static func grouped(result: ClearResult, preClear: [Pos: Cell], pointsPerTile: Int,
                        multiplier: Int, doublesBananas: Bool, groupCount: Int) -> [ScorePopupReceipt] {
        let positions = result.cleared.union(result.damagedBlockers).sorted {
            $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r
        }
        guard !positions.isEmpty, pointsPerTile > 0, multiplier > 0 else { return [] }
        let count = min(4, min(positions.count, max(1, groupCount)))
        return (0..<count).map { index in
            let start = index * positions.count / count
            let end = (index + 1) * positions.count / count
            let group = positions[start..<end]
            let credits = group.reduce(0) { sum, p in
                let cleared = result.cleared.contains(p)
                return sum + (cleared ? 1 : 0) + (result.damagedBlockers.contains(p) ? 1 : 0)
                    + (cleared && doublesBananas && preClear[p]?.piece?.color == .banana ? 1 : 0)
            }
            return ScorePopupReceipt(position: positions[(start + end - 1) / 2],
                                     points: credits * pointsPerTile * multiplier)
        }
    }
}
