import SwiftUI

struct ExercisesTabView: View {
    @Environment(WorkoutStore.self) private var store

    private var grouped: [MuscleGroup: [Exercise]] {
        Dictionary(grouping: store.allExercises, by: \.muscleGroup)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MuscleGroup.allCases) { group in
                    if let exercises = grouped[group], !exercises.isEmpty {
                        Section(group.displayName) {
                            ForEach(exercises) { exercise in
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    HStack {
                                        Text(exercise.name)
                                        if exercise.isCustom {
                                            Text("Custom")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.blue.opacity(0.15), in: Capsule())
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        NewExerciseView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct ExerciseDetailView: View {
    @Environment(WorkoutStore.self) private var store
    let exercise: Exercise

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
            Section("Stats") {
                LabeledContent("Muscle group", value: exercise.muscleGroup.displayName)
                let best = store.bestOneRepMax(for: exercise.id)
                LabeledContent("Best est. 1RM", value: best > 0 ? Stats.formattedWeight(best) : "—")
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
                                    ? "\(Stats.formattedWeight(set.weight))×\(set.reps)"
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
}
