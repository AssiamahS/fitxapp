import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.history.isEmpty {
                    ContentUnavailableView("No workouts yet",
                                           systemImage: "figure.strengthtraining.traditional",
                                           description: Text("Finish your first workout and it will show up here."))
                } else {
                    List {
                        ForEach(store.history) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                HistoryRow(workout: workout)
                            }
                        }
                        .onDelete { store.deleteWorkouts(at: $0) }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct HistoryRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.title)
                .font(.headline)
            Text(workout.startDate, format: .dateTime.weekday(.wide).day().month())
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(Stats.formattedDuration(workout.duration), systemImage: "stopwatch")
                Label(Stats.formattedVolume(workout.totalVolume), systemImage: "scalemass")
                Label("\(workout.completedSetCount) sets", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(workout.startDate, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Duration", value: Stats.formattedDuration(workout.duration))
                LabeledContent("Volume", value: Stats.formattedVolume(workout.totalVolume))
                LabeledContent("Sets", value: "\(workout.completedSetCount)")
                if !workout.notes.isEmpty {
                    Text(workout.notes)
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
                            Text(wex.exercise.usesWeight
                                 ? "\(Stats.formattedWeight(set.weight)) × \(set.reps)"
                                 : "\(set.reps) reps")
                            Spacer()
                            if wex.exercise.usesWeight && set.weight > 0 && set.reps > 0 {
                                Text("1RM \(Stats.formattedWeight(Stats.epleyOneRepMax(weight: set.weight, reps: set.reps)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
