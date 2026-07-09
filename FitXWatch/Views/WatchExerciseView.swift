import SwiftUI
import WatchKit

struct WatchExerciseView: View {
    @Binding var wex: WorkoutExercise
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        List {
            // Same demo frames as the phone — tap a move, see how it's done.
            if ExerciseInfo.hasMedia(for: wex.exercise.id) {
                ExerciseMediaView(exerciseID: wex.exercise.id)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
            }

            let previous = store.lastSets(for: wex.exercise.id)
            if !previous.isEmpty {
                Text("Last: " + previous.map { summary($0) }.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach($wex.sets) { $set in
                NavigationLink {
                    WatchSetEditor(set: $set, usesWeight: wex.exercise.usesWeight) {
                        store.restTimer.start(seconds: store.settings.restSeconds)
                        RestHaptics.schedule(for: store.restTimer)
                    }
                } label: {
                    HStack {
                        Text("Set \((wex.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1)")
                        Spacer()
                        Text(summary(set))
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

    private func summary(_ set: WorkoutSet) -> String {
        wex.exercise.usesWeight
            ? "\(Stats.formattedWeight(set.weight, unit: store.settings.weightUnit))×\(set.reps)"
            : "\(set.reps)"
    }
}

struct WatchSetEditor: View {
    @Binding var set: WorkoutSet
    let usesWeight: Bool
    var onCompleted: () -> Void
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            if usesWeight {
                let unit = store.settings.weightUnit
                Stepper(value: weightBinding, in: 0...1000, step: unit == .kg ? 2.5 : 5) {
                    Text(Stats.formattedWeight(set.weight, unit: unit))
                        .font(.headline)
                }
            }

            Stepper(value: $set.reps, in: 0...100, step: 1) {
                Text("\(set.reps) reps")
                    .font(.headline)
            }

            Button {
                set.isCompleted = true
                WKInterfaceDevice.current().play(.success)
                onCompleted()
                dismiss()
            } label: {
                Label("Log Set", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .padding(.horizontal, 4)
        // Dial the weight with the crown — 2.5 kg / 5 lb per click.
        .focusable(usesWeight)
        .digitalCrownRotation(weightBinding,
                              from: 0,
                              through: 1000,
                              by: store.settings.weightUnit == .kg ? 2.5 : 5,
                              sensitivity: .medium,
                              isContinuous: false,
                              isHapticFeedbackEnabled: true)
        .navigationTitle("Set")
    }

    /// Steps in display units, stores kilograms.
    private var weightBinding: Binding<Double> {
        let unit = store.settings.weightUnit
        return Binding(
            get: { unit.fromKg(set.weight) },
            set: { set.weight = unit.toKg($0) }
        )
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
