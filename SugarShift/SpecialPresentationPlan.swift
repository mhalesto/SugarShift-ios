import Foundation

/// Captured before clearing. Rendering must never select a fresh destination
/// from the board after the engine has removed its target.
struct SpecialPresentationPlan {
    let origin: Pos
    let special: Special
    let color: String
    let footprint: Set<Pos>
    let destinations: [Pos]

    static let seekerTravelDuration: TimeInterval = 0.24

    static func capture(in grid: Grid, positions: Set<Pos>, fishDestinations: [Pos: Pos],
                        bigger: Bool) -> [SpecialPresentationPlan] {
        let origins = positions.filter { grid[$0.r][$0.c]?.special != nil }.sorted {
            $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r
        }
        return origins.compactMap { origin in
            guard let cell = grid[origin.r][origin.c], let special = cell.special else { return nil }
            let targets = fishDestinations[origin].map { [$0] } ?? []
            let stages = Engine.resolveSpecialActivationStaged(grid, special: special, at: origin,
                targetColor: cell.color, rankedTargets: targets, bigger: bigger,
                excludingSpecialsAt: Set(origins)).stages
            return SpecialPresentationPlan(origin: origin, special: special, color: cell.color,
                footprint: stages.reduce(into: Set<Pos>([origin])) { $0.formUnion($1.positions) },
                destinations: stages.map(\.origin))
        }
    }

    func travelDelay(to position: Pos) -> TimeInterval {
        let distance = Double(max(abs(position.r - origin.r), abs(position.c - origin.c)))
        switch special {
        case .fish: return Self.seekerTravelDuration + 0.04
        case .ufo: return 0.12 + distance * 0.012
        case .colorBomb: return 0.10 + min(0.15, distance * 0.018)
        case .rocket: return 0.06 + min(0.20, distance * 0.026)
        default: return min(0.22, distance * 0.025)
        }
    }
}
