import SwiftUI
import Charts

struct ExerciseDetailView: View {
    @Environment(WorkoutStore.self) private var store
    let exercise: Exercise
    @State private var chartMode: ChartMode = .oneRepMax

    enum ChartMode: String, CaseIterable, Identifiable {
        case oneRepMax = "1RM"
        case volume = "Volume"
        var id: String { rawValue }
    }

    private var insight: ExerciseInsight {
        Insights.insight(for: exercise.id, history: store.history)
    }

    private var historyEntries: [(workout: Workout, sets: [WorkoutSet])] {
        store.history.compactMap { workout in
            guard let wex = workout.exercises.first(where: { $0.exercise.id == exercise.id }) else {
                return nil
            }
            let done = wex.sets.filter(\.isCompleted)
            return done.isEmpty ? nil : (workout, done)
        }
    }

    var body: some View {
        List {
            if ExerciseInfo.hasMedia(for: exercise.id) {
                Section {
                    ExerciseMediaView(exerciseID: exercise.id)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                LabeledContent("Muscle group", value: exercise.muscleGroup.displayName)
                if let last = insight.lastPerformed {
                    LabeledContent("Last performed") {
                        Text(last, format: .dateTime.day().month().year())
                    }
                }
                if insightText != nil || insight.trend != .new {
                    HStack {
                        Text("Trend")
                        Spacer()
                        TrendBadge(insight: insight)
                    }
                }
                if let insightText {
                    Text(insightText)
                        .font(.caption)
                        .foregroundStyle(insight.isStale || insight.trend == .declining ? .red : .secondary)
                }
            }

            if exercise.usesWeight && !insight.sessions.isEmpty {
                Section("Records") {
                    recordsGrid
                }
            }

            if insight.sessions.count >= 2 {
                Section("Progress") {
                    Picker("Chart", selection: $chartMode) {
                        ForEach(ChartMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    chart
                        .frame(height: 180)
                        .padding(.vertical, 4)
                }
            }

            let instructions = ExerciseInfo.instructions(for: exercise.id)
            if !instructions.isEmpty {
                Section("How to do it") {
                    ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 18, height: 18)
                                .background(.blue.opacity(0.15), in: Circle())
                                .foregroundStyle(.blue)
                            Text(step)
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section("History") {
                if historyEntries.isEmpty {
                    Text("No sets logged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(historyEntries, id: \.workout.id) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.workout.startDate, format: .dateTime.day().month().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.sets.map { set in
                                exercise.usesWeight
                                    ? "\(Stats.formattedWeight(set.weight, unit: store.settings.weightUnit))×\(set.reps)"
                                    : "\(set.reps)"
                            }.joined(separator: ", "))
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var insightText: String? {
        if insight.isStale, let weeks = insight.weeksSinceLast {
            return "You haven't hit this move in \(weeks) weeks."
        }
        switch insight.trend {
        case .declining:
            return "Declining — down \(String(format: "%.0f", abs(insight.trendPercent)))% vs your previous sessions."
        case .improving:
            return "Improving — up \(String(format: "%.0f", insight.trendPercent))% vs your previous sessions."
        default:
            return nil
        }
    }

    private var recordsGrid: some View {
        let unit = store.settings.weightUnit
        let bestE1RM = insight.sessions.map(\.score).max() ?? 0
        let bestWeight = historyEntries.flatMap(\.sets).map(\.weight).max() ?? 0
        let bestReps = historyEntries.flatMap(\.sets).map(\.reps).max() ?? 0
        let bestSession = insight.sessions.map(\.totalVolume).max() ?? 0
        return HStack(spacing: 8) {
            StatCard(title: "Best 1RM", value: Stats.formattedWeight(bestE1RM, unit: unit),
                     icon: "trophy.fill", tint: .yellow)
            StatCard(title: "Top weight", value: Stats.formattedWeight(bestWeight, unit: unit),
                     icon: "scalemass.fill", tint: .blue)
            StatCard(title: "Most reps", value: "\(bestReps)", icon: "repeat", tint: .green)
            StatCard(title: "Best session", value: Stats.formattedVolume(bestSession, unit: unit),
                     icon: "chart.bar.fill", tint: .purple)
        }
    }

    @ViewBuilder
    private var chart: some View {
        let unit = store.settings.weightUnit
        let sessions = insight.sessions.suffix(15)
        switch chartMode {
        case .oneRepMax:
            Chart(sessions, id: \.date) { session in
                LineMark(x: .value("Date", session.date),
                         y: .value("1RM", unit.fromKg(session.score)))
                    .foregroundStyle(.blue)
                PointMark(x: .value("Date", session.date),
                          y: .value("1RM", unit.fromKg(session.score)))
                    .foregroundStyle(.blue)
            }
            .chartYAxisLabel(exercise.usesWeight ? "est. 1RM (\(unit.suffix))" : "reps")
        case .volume:
            Chart(sessions, id: \.date) { session in
                BarMark(x: .value("Date", session.date),
                        y: .value("Volume", unit.fromKg(session.totalVolume)))
                    .foregroundStyle(.purple)
            }
            .chartYAxisLabel("volume (\(unit.suffix))")
        }
    }
}
