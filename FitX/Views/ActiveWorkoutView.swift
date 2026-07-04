import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var showingCancelConfirm = false
    @State private var showingFinishConfirm = false
    @State private var showingExercisePicker = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                if let workout = Binding($store.activeWorkout) {
                    WorkoutFormView(workout: workout, showingExercisePicker: $showingExercisePicker)
                } else {
                    // Cover is about to dismiss (workout finished/cancelled).
                    Color.clear
                }
            }
            .navigationTitle(store.activeWorkout?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive) {
                        showingCancelConfirm = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        showingFinishConfirm = true
                    }
                    .bold()
                }
            }
            .safeAreaInset(edge: .bottom) {
                RestTimerBar(timer: store.restTimer)
            }
            .confirmationDialog("Discard this workout?",
                                isPresented: $showingCancelConfirm,
                                titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    store.cancelActiveWorkout()
                }
                Button("Keep Going", role: .cancel) {}
            }
            .confirmationDialog("Finish workout? Incomplete sets will be discarded.",
                                isPresented: $showingFinishConfirm,
                                titleVisibility: .visible) {
                Button("Finish Workout") {
                    store.finishActiveWorkout()
                }
                Button("Keep Going", role: .cancel) {}
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    store.addExerciseToActiveWorkout(exercise)
                }
            }
        }
    }
}

struct WorkoutFormView: View {
    @Binding var workout: Workout
    @Binding var showingExercisePicker: Bool
    @Environment(WorkoutStore.self) private var store

    init(workout: Binding<Workout>, showingExercisePicker: Binding<Bool>) {
        _workout = workout
        _showingExercisePicker = showingExercisePicker
    }

    var body: some View {
        List {
            Section {
                TextField("Workout title", text: $workout.title)
                    .font(.headline)
                HStack {
                    ElapsedTimeView(start: workout.startDate)
                    Spacer()
                    Text("Volume: \(Stats.formattedVolume(workout.totalVolume))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach($workout.exercises) { $wex in
                Section {
                    HStack {
                        Text(wex.exercise.name)
                            .font(.headline)
                        Spacer()
                        Menu {
                            Button("Remove Exercise", role: .destructive) {
                                workout.exercises.removeAll { $0.id == wex.id }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }

                    let previous = store.lastSets(for: wex.exercise.id)
                    if !previous.isEmpty {
                        Text("Previous: " + previous.map { setSummary($0, usesWeight: wex.exercise.usesWeight) }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($wex.sets) { $set in
                        SetRow(set: $set,
                               number: (wex.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1,
                               usesWeight: wex.exercise.usesWeight) {
                            store.restTimer.start(seconds: AppConfig.defaultRestSeconds)
                        }
                    }
                    .onDelete { offsets in
                        $wex.wrappedValue.sets.remove(atOffsets: offsets)
                    }

                    Button {
                        var newSet = WorkoutSet()
                        if let last = wex.sets.last {
                            newSet.weight = last.weight
                            newSet.reps = last.reps
                        }
                        $wex.wrappedValue.sets.append(newSet)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(.subheadline)
                    }
                }
            }

            Section {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func setSummary(_ set: WorkoutSet, usesWeight: Bool) -> String {
        usesWeight ? "\(Stats.formattedWeight(set.weight))×\(set.reps)" : "\(set.reps)"
    }
}

struct SetRow: View {
    @Binding var set: WorkoutSet
    let number: Int
    let usesWeight: Bool
    var onCompleted: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(SetType.allCases) { type in
                    Button(type.displayName) { set.type = type }
                }
            } label: {
                Text(set.type.marker ?? "\(number)")
                    .font(.subheadline.bold())
                    .frame(width: 28, height: 28)
                    .background(markerColor.opacity(0.15), in: Circle())
                    .foregroundStyle(markerColor)
            }
            .buttonStyle(.plain)

            if usesWeight {
                TextField("kg", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            TextField("reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                set.isCompleted.toggle()
                if set.isCompleted { onCompleted() }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var markerColor: Color {
        switch set.type {
        case .normal: return .blue
        case .warmup: return .orange
        case .failure: return .red
        case .drop: return .purple
        }
    }
}

struct ElapsedTimeView: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Label(Stats.formattedDuration(context.date.timeIntervalSince(start)),
                  systemImage: "stopwatch")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

struct RestTimerBar: View {
    var timer: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = timer.remaining(at: context.date)
            if remaining > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(.blue)
                    Text(Stats.formattedDuration(remaining))
                        .font(.title3.bold())
                        .monospacedDigit()
                    ProgressView(value: timer.progress(at: context.date))
                    Button("+30s") { timer.add(seconds: 30) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Skip") { timer.stop() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding()
                .background(.thinMaterial)
            }
        }
    }
}
