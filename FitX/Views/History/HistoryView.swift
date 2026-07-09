import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store

    private var byMonth: [(month: Date, workouts: [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.history) { workout in
            calendar.dateInterval(of: .month, for: workout.startDate)?.start ?? workout.startDate
        }
        return grouped
            .map { (month: $0.key, workouts: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.history.isEmpty {
                    ContentUnavailableView("No workouts yet",
                                           systemImage: "figure.strengthtraining.traditional",
                                           description: Text("Finish your first workout and it will show up here."))
                } else {
                    List {
                        ForEach(byMonth, id: \.month) { section in
                            Section {
                                ForEach(section.workouts) { workout in
                                    NavigationLink {
                                        WorkoutDetailView(workout: workout)
                                    } label: {
                                        HistoryRow(workout: workout,
                                                   prCount: Insights.prSets(in: workout, history: store.history).count,
                                                   unit: store.settings.weightUnit)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteWorkouts(in: section.workouts, at: offsets)
                                }
                            } header: {
                                HStack {
                                    Text(section.month, format: .dateTime.month(.wide).year())
                                    Spacer()
                                    Text("\(section.workouts.count) workouts")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func deleteWorkouts(in workouts: [Workout], at offsets: IndexSet) {
        let ids = offsets.compactMap { workouts.indices.contains($0) ? workouts[$0].id : nil }
        let indices = IndexSet(store.history.enumerated()
            .filter { ids.contains($0.element.id) }
            .map(\.offset))
        store.deleteWorkouts(at: indices)
    }
}

struct HistoryRow: View {
    let workout: Workout
    var prCount: Int = 0
    var unit: WeightUnit = .kg

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title)
                    .font(.headline)
                if prCount > 0 {
                    Label("\(prCount)", systemImage: "flame.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            Text(workout.startDate, format: .dateTime.weekday(.wide).day().month())
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(Stats.formattedDuration(workout.duration), systemImage: "stopwatch")
                Label(Stats.formattedVolume(workout.totalVolume, unit: unit), systemImage: "scalemass")
                Label("\(workout.completedSetCount) sets", systemImage: "checkmark.circle")
                if let hr = workout.avgHeartRate {
                    Label("\(Int(hr))", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct WorkoutDetailView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    private var prSets: Set<UUID> {
        Insights.prSets(in: workout, history: store.history)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(workout.startDate, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Duration", value: Stats.formattedDuration(workout.duration))
                LabeledContent("Volume", value: Stats.formattedVolume(workout.totalVolume, unit: store.settings.weightUnit))
                LabeledContent("Sets", value: "\(workout.completedSetCount)")
                if !workout.notes.isEmpty {
                    Text(workout.notes)
                }
            }

            if workout.avgHeartRate != nil || workout.activeCalories != nil {
                Section("Apple Watch") {
                    if let avg = workout.avgHeartRate {
                        LabeledContent("Avg heart rate") {
                            Label("\(Int(avg)) bpm", systemImage: "heart.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    if let max = workout.maxHeartRate {
                        LabeledContent("Max heart rate") {
                            Label("\(Int(max)) bpm", systemImage: "bolt.heart.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    if let kcal = workout.activeCalories {
                        LabeledContent("Active calories") {
                            Label("\(Int(kcal)) kcal", systemImage: "flame.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            ForEach(workout.exercises) { wex in
                Section(wex.exercise.name) {
                    ForEach(Array(wex.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text(set.type.marker ?? "\(index + 1)")
                                .font(.subheadline.bold())
                                .frame(width: 24)
                                .foregroundStyle(.secondary)
                            Text(setLabel(set, exercise: wex.exercise))
                            if prSets.contains(set.id) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            if wex.exercise.usesWeight && set.weight > 0 && set.reps > 0 {
                                Text("1RM \(Stats.formattedWeight(Stats.epleyOneRepMax(weight: set.weight, reps: set.reps), unit: store.settings.weightUnit))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    store.repeatWorkout(workout)
                } label: {
                    Label("Repeat Workout", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.headline)
                }
                .disabled(store.activeWorkout != nil)
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setLabel(_ set: WorkoutSet, exercise: Exercise) -> String {
        if exercise.isCardio {
            var parts: [String] = []
            if let seconds = set.durationSeconds, seconds > 0 {
                parts.append(Stats.formattedDuration(seconds))
            }
            if let meters = set.distanceMeters, meters > 0 {
                parts.append(String(format: "%.2f km", meters / 1000))
            }
            if parts.isEmpty { parts.append("\(set.reps) reps") }
            return parts.joined(separator: " · ")
        }
        return exercise.usesWeight
            ? "\(Stats.formattedWeight(set.weight, unit: store.settings.weightUnit)) × \(set.reps)"
            : "\(set.reps) reps"
    }
}
