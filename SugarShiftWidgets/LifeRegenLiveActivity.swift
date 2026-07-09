import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity for the life-regen timer: a heart meter with a live countdown
/// on the lock screen and in the Dynamic Island. Started by the app when the
/// player backgrounds with missing lives. Its display derives from wall-clock
/// dates so it keeps advancing while the app process is suspended.
@available(iOSApplicationExtension 16.1, *)
struct LifeRegenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LifeRegenAttributes.self) { context in
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                HStack(spacing: 12) {
                    heartMeter(context: context, at: timeline.date)
                    Spacer()
                    countdown(context: context, at: timeline.date)
                }
                .padding(14)
            }
            .activityBackgroundTint(Color(red: 0.99, green: 0.91, blue: 0.95))
            .activitySystemActionForegroundColor(.pink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        heartMeter(context: context, at: timeline.date)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        countdown(context: context, at: timeline.date)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(String(localized: "Lives are refilling — come back soon!"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text("❤️\(context.state.lives(at: timeline.date, maximum: context.attributes.livesMax))")
                        .font(.caption2.bold())
                }
            } compactTrailing: {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    if let next = context.state.nextLife(after: timeline.date,
                                                         maximum: context.attributes.livesMax) {
                        Text(timerInterval: timeline.date...max(timeline.date.addingTimeInterval(1), next),
                             countsDown: true)
                            .font(.caption2.monospacedDigit())
                            .frame(maxWidth: 44)
                    } else {
                        Text(String(localized: "Full!"))
                            .font(.caption2.bold())
                    }
                }
            } minimal: {
                Text("❤️")
            }
        }
    }

    @ViewBuilder
    private func heartMeter(context: ActivityViewContext<LifeRegenAttributes>, at date: Date) -> some View {
        let currentLives = context.state.lives(at: date, maximum: context.attributes.livesMax)
        VStack(alignment: .leading, spacing: 2) {
            Text("❤️ \(currentLives)/\(context.attributes.livesMax)")
                .font(.headline.bold())
            Text(String(localized: "SugarShift lives"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func countdown(context: ActivityViewContext<LifeRegenAttributes>, at date: Date) -> some View {
        if let next = context.state.nextLife(after: date, maximum: context.attributes.livesMax) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(timerInterval: date...max(date.addingTimeInterval(1), next),
                     countsDown: true)
                    .font(.title3.monospacedDigit().bold())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
                Text(String(localized: "next life"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(String(localized: "Full!"))
                .font(.title3.bold())
                .foregroundStyle(.green)
        }
    }
}
#endif
