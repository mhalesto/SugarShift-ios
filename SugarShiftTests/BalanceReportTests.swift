import XCTest
@testable import SugarShift

/// Runnable campaign balance report + aggregate regression guard.
///
/// Runs the deterministic, objective-aware bot across every level and attaches a
/// full per-level report (win rate / stars / moves-left / stuck rate / moves /
/// target) to the test results as `balance-report.txt`. Read it from Xcode's
/// test report, or from the command line with:
///   xcrun xcresulttool get --legacy --path <…>.xcresult --format json
///
/// Caveat: the bot now ranks immediate moves against the real objective and
/// urgent hazards, but it remains greedy: no multi-move setup, special-saving,
/// risk judgement, or long-horizon ingredient routing. Treat win rate as a
/// relative build-to-build signal, not a substitute for human playtests.
final class BalanceReportTests: XCTestCase {
    func testCampaignBalanceReport() {
        let rows = LevelDesignReport.simulationRows(levelRange: 1...Levels.count,
                                                    attemptsPerLevel: 15)
        func win(_ r: LevelSimulationSummary) -> Double {
            r.attempts > 0 ? Double(r.wins) / Double(r.attempts) : 0
        }

        var hardSpikes: [Int] = [], trivial: [Int] = [], stuck: [Int] = [], broken: [Int] = []
        var lines = ["level  win%  stars  movesLeft  stuck%  moves  target  warnings"]
        for r in rows {
            let w = win(r)
            let cfg = Levels.config(for: r.level)
            lines.append(String(format: "%4d  %4.0f  %4.1f  %7.1f  %5.0f  %5d  %6d  %@",
                                r.level, w * 100, r.averageStars, r.averageMovesLeft,
                                r.stuckBoardRate * 100, cfg.moves, cfg.target,
                                r.warnings.joined(separator: ";")))
            if w == 0 { broken.append(r.level) } else if w < 0.40 { hardSpikes.append(r.level) }
            if w > 0.98 && r.averageStars > 2.8 { trivial.append(r.level) }
            if r.stuckBoardRate > 0.15 { stuck.append(r.level) }
        }
        let avgWin = rows.map(win).reduce(0, +) / Double(max(1, rows.count))
        lines.append("")
        lines.append(String(format: "CAMPAIGN AVG WIN: %.1f%%", avgWin * 100))
        lines.append("HARD_SPIKES (<40%): \(hardSpikes)")
        lines.append("TRIVIAL (>98%, >2.8*): \(trivial)")
        lines.append("STUCK_PRONE (>15%): \(stuck)")
        lines.append("BOT_BLIND_SPOTS (0%, usually routing-heavy): \(broken)")

        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "balance-report.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Surface the headline in the failure-free path too (NSLog for the log).
        NSLog("SSBAL avg=%.0f spikes=%d trivial=%d stuck=%d broken=%d",
              avgWin * 100, hardSpikes.count, trivial.count, stuck.count, broken.count)

        // Aggregate guard only — catches catastrophic regressions (whole campaign
        // unwinnable or trivial). Per-level tuning needs human playtests.
        XCTAssertEqual(rows.count, Levels.count)
        XCTAssertGreaterThan(avgWin, 0.30, "Campaign far too hard — check balancedTarget")
        XCTAssertLessThan(avgWin, 0.98, "Campaign trivially easy — check balancedTarget")
    }

    /// The tower rotates objectives per floor, so each floor needs the same
    /// "is this actually winnable" evidence the campaign gets. The bot is
    /// greedy, so the guard is deliberately loose: it catches a floor whose
    /// goal the board can never satisfy, not a floor that is merely hard.
    func testTowerFloorBalanceReport() {
        let week = TowerMode.weekKey(for: Date(timeIntervalSince1970: 4_102_444_800))
        let topFloor = 20
        var lines = ["floor  win%  stars  movesLeft  moves  target  goal"]
        var unwinnableEarly: [Int] = []

        for floor in 1...topFloor {
            let config = TowerMode.floorConfig(weekKey: week, floor: floor, perks: [])
            let summary = LevelSimulationBot.simulate(config: config,
                                                      attempts: 10,
                                                      seed: 0x70B3 &+ UInt64(floor))
            let winRate = summary.winRate
            lines.append(String(format: "%5d  %4.0f  %5.1f  %7.1f  %5d  %6d  %@",
                                floor, winRate * 100, summary.averageStars,
                                summary.averageMovesLeft, config.moves, config.target,
                                config.goal.title))
            // Floors 1-10 are the part of the climb a player should reliably
            // reach; a 0% bot win there means the goal, not the difficulty,
            // is wrong.
            if floor <= 10, winRate == 0 { unwinnableEarly.append(floor) }
        }

        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "tower-balance-report.txt"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(unwinnableEarly.isEmpty,
                      "Tower floors with an unreachable goal: \(unwinnableEarly)")
    }
}
