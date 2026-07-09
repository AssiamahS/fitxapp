import SwiftUI
import WatchKit

/// Native-Workout-style vertical pager: controls | live metrics | exercise log.
struct WatchSessionPager: View {
    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            WatchControlsView()
                .tag(0)
            WatchMetricsView()
                .tag(1)
            WatchWorkoutView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .navigationBarBackButtonHidden(true)
    }
}

struct WatchControlsView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var showingCancelConfirm = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack {
                    Button {
                        finish()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    Text("Finish")
                        .font(.caption2)
                }
                VStack {
                    Button(role: .destructive) {
                        showingCancelConfirm = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    Text("Discard")
                        .font(.caption2)
                }
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $showingCancelConfirm) {
            Button("Discard", role: .destructive) {
                WorkoutSessionManager.shared.discard()
                store.cancelActiveWorkout()
                Connectivity.shared.sendLiveEnded()
            }
            Button("Keep Going", role: .cancel) {}
        }
    }

    private func finish() {
        WorkoutSessionManager.shared.end { avgHR, maxHR, kcal in
            if let finished = store.finishActiveWorkout(avgHeartRate: avgHR,
                                                        maxHeartRate: maxHR,
                                                        activeCalories: kcal) {
                Connectivity.shared.send(workout: finished)
            }
            Connectivity.shared.sendLiveEnded()
        }
    }
}

struct WatchMetricsView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        let manager = WorkoutSessionManager.shared
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                if let start = manager.startDate ?? store.activeWorkout?.startDate {
                    Text(Stats.formattedDuration(context.date.timeIntervalSince(start)))
                        .font(.system(.title2, design: .rounded).bold())
                        .monospacedDigit()
                        .foregroundStyle(.yellow)
                }

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                        .font(.system(.title, design: .rounded).bold())
                        .monospacedDigit()
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(manager.activeCalories))")
                        .font(.system(.title3, design: .rounded).bold())
                        .monospacedDigit()
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let workout = store.activeWorkout {
                    Text("\(workout.completedSetCount) sets · \(Stats.formattedVolume(workout.totalVolume, unit: store.settings.weightUnit))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let remaining = store.restTimer.remaining(at: context.date)
                if remaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundStyle(.blue)
                        Text(Stats.formattedDuration(remaining))
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WatchWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var showingPicker = false

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
                }
                .navigationTitle(workout.wrappedValue.title)
            }
        }
        .sheet(isPresented: $showingPicker) {
            WatchExercisePicker { exercise in
                store.addExerciseToActiveWorkout(exercise)
            }
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

/// Plays the "rest is over" tap when the timer actually runs out.
enum RestHaptics {
    static func schedule(for timer: RestTimer) {
        guard let end = timer.endDate else { return }
        Task {
            let delay = end.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            // Only fire if the timer wasn't skipped or extended in the meantime.
            if let current = timer.endDate, abs(current.timeIntervalSince(end)) < 0.5 {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}
