import WidgetKit
import SwiftUI

/// Home/lock-screen widget for the shared daily challenge: today's board
/// number, whether it's been cleared, and the streak. Reloads at local
/// midnight when a fresh board drops.
struct DailyChallengeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSharedState.Snapshot?

    var isCurrentDay: Bool {
        snapshot?.isCurrent(at: date) ?? false
    }
}

struct DailyChallengeProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyChallengeEntry {
        DailyChallengeEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyChallengeEntry) -> Void) {
        completion(DailyChallengeEntry(date: Date(), snapshot: WidgetSharedState.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyChallengeEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSharedState.read()
        let midnight = WidgetSharedState.nextMidnight(after: now)
        let dates = [now] + (snapshot?.regenerationDates(after: now, before: midnight) ?? [])
        let entries = dates.map { DailyChallengeEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

struct DailyChallengeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyChallengeEntry

    private var streak: Int { entry.snapshot?.streak ?? 0 }
    private var cleared: Bool { entry.isCurrentDay && (entry.snapshot?.claimed ?? false) }

    private var titleText: String {
        guard let snap = entry.snapshot, entry.isCurrentDay else {
            return String(localized: "Daily Challenge")
        }
        return String(localized: "Daily #\(snap.number)")
    }

    private var statusText: String {
        if cleared { return String(localized: "Cleared ✓") }
        if let snap = entry.snapshot, entry.isCurrentDay {
            return String(localized: "Level \(snap.level) — ready!")
        }
        return String(localized: "New board ready!")
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(cleared ? "✓" : "🍒")
                    .font(.system(size: 18))
                Text("🔥\(streak)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(titleText)
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                Text(String(localized: "🔥 \(streak)-day streak"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🍒")
                        .font(.title3)
                    Spacer()
                    Text("🔥\(streak)")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(titleText)
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.primary)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(cleared ? .green : .pink)
                if let snap = entry.snapshot {
                    Text("❤️ \(snap.livesNow(at: entry.date))/\(snap.livesMax)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DailyChallengeWidget: Widget {
    let kind = "SugarShiftDailyChallenge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyChallengeProvider()) { entry in
            DailyChallengeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.96),
                                            Color(red: 0.98, green: 0.85, blue: 0.91)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                }
        }
        .configurationDisplayName(String(localized: "Daily Challenge"))
        .description(String(localized: "Today's shared board and your streak."))
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}
