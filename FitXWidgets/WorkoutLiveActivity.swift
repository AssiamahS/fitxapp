import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FitXWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenWorkoutView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.title, systemImage: "dumbbell.fill")
                        .font(.caption.bold())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .timer)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .frame(maxWidth: 60)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let rest = restRange(context.state) {
                        VStack(spacing: 2) {
                            HStack {
                                Text("Rest")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(timerInterval: rest, countsDown: true)
                                    .font(.headline.bold())
                                    .monospacedDigit()
                                    .frame(maxWidth: 70)
                            }
                            ProgressView(timerInterval: rest, countsDown: true)
                                .labelsHidden()
                                .tint(.blue)
                        }
                    } else {
                        HStack {
                            if let exercise = context.state.currentExercise {
                                Text(exercise)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(context.state.completedSets) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                if let rest = restRange(context.state) {
                    Text(timerInterval: rest, countsDown: true)
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                        .foregroundStyle(.blue)
                } else {
                    Text(context.state.startDate, style: .timer)
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.blue)
            }
        }
    }

    private func restRange(_ state: WorkoutActivityAttributes.ContentState) -> ClosedRange<Date>? {
        guard let end = state.restEndDate, end > Date() else { return nil }
        let start = end.addingTimeInterval(-(state.restTotalSeconds ?? 90))
        return start...end
    }
}

struct LockScreenWorkoutView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(state.title, systemImage: "dumbbell.fill")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(state.startDate, style: .timer)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(maxWidth: 70)
            }
            if let end = state.restEndDate, end > Date() {
                let start = end.addingTimeInterval(-(state.restTotalSeconds ?? 90))
                HStack {
                    Text("Rest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(timerInterval: start...end, countsDown: true)
                        .labelsHidden()
                        .tint(.blue)
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .frame(maxWidth: 60)
                }
            } else {
                HStack {
                    if let exercise = state.currentExercise {
                        Text(exercise)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(state.completedSets) sets done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
