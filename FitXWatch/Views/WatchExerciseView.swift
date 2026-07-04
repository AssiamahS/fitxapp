import SwiftUI

struct WatchExerciseView: View {
    @Binding var wex: WorkoutExercise
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        List {
            ForEach($wex.sets) { $set in
                NavigationLink {
                    WatchSetEditor(set: $set, usesWeight: wex.exercise.usesWeight) {
                        store.restTimer.start(seconds: AppConfig.defaultRestSeconds)
                    }
                } label: {
                    HStack {
                        Text("Set \((wex.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1)")
                        Spacer()
                        Text(wex.exercise.usesWeight
                             ? "\(Stats.formattedWeight(set.weight))×\(set.reps)"
                             : "\(set.reps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                    }
                }
            }

            Button {
                var newSet = WorkoutSet()
                if let last = wex.sets.last {
                    newSet.weight = last.weight
                    newSet.reps = last.reps
                }
                wex.sets.append(newSet)
            } label: {
                Label("Add Set", systemImage: "plus")
            }
        }
        .navigationTitle(wex.exercise.name)
    }
}

struct WatchSetEditor: View {
    @Binding var set: WorkoutSet
    let usesWeight: Bool
    var onCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if usesWeight {
                    Stepper(value: $set.weight, in: 0...500, step: 2.5) {
                        Text(Stats.formattedWeight(set.weight))
                            .font(.headline)
                    }
                }

                Stepper(value: $set.reps, in: 0...100, step: 1) {
                    Text("\(set.reps) reps")
                        .font(.headline)
                }

                Button {
                    set.isCompleted = true
                    onCompleted()
                    dismiss()
                } label: {
                    Label("Log Set", systemImage: "checkmark")
                }
                .tint(.green)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Set")
    }
}

struct WatchExercisePicker: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSelect: (Exercise) -> Void

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
                                Button(exercise.name) {
                                    onSelect(exercise)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
        }
    }
}
