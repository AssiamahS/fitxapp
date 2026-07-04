import SwiftUI

struct WatchWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var showingPicker = false
    @State private var showingCancelConfirm = false

    var body: some View {
        @Bindable var store = store
        Group {
            if let workout = Binding($store.activeWorkout) {
                List {
                    if store.restTimer.isRunning {
                        WatchRestTimerRow(timer: store.restTimer)
                    }

                    ForEach(workout.exercises) { $wex in
                        NavigationLink {
                            WatchExerciseView(wex: $wex)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wex.exercise.name)
                                    .lineLimit(1)
                                Text("\(wex.completedSetCount)/\(wex.sets.count) sets")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }

                    Section {
                        Button {
                            if let finished = store.finishActiveWorkout() {
                                Connectivity.shared.send(workout: finished)
                            }
                        } label: {
                            Label("Finish", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            showingCancelConfirm = true
                        } label: {
                            Label("Discard", systemImage: "xmark.circle")
                        }
                    }
                }
                .navigationTitle(workout.wrappedValue.title)
            }
        }
        .sheet(isPresented: $showingPicker) {
            WatchExercisePicker { exercise in
                store.addExerciseToActiveWorkout(exercise)
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $showingCancelConfirm) {
            Button("Discard", role: .destructive) {
                store.cancelActiveWorkout()
            }
            Button("Keep Going", role: .cancel) {}
        }
    }
}

struct WatchRestTimerRow: View {
    var timer: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = timer.remaining(at: context.date)
            if remaining > 0 {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.blue)
                    Text(Stats.formattedDuration(remaining))
                        .font(.headline)
                        .monospacedDigit()
                    Spacer()
                    Button("Skip") { timer.stop() }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
        }
    }
}
