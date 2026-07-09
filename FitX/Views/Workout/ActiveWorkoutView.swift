import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var showingCancelConfirm = false
    @State private var showingFinishConfirm = false
    @State private var showingExercisePicker = false
    @State private var plateTarget: PlateTarget?

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                if let workout = Binding($store.activeWorkout) {
                    WorkoutFormView(workout: workout,
                                    showingExercisePicker: $showingExercisePicker,
                                    plateTarget: $plateTarget)
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
            .sheet(item: $plateTarget) { target in
                PlateCalculatorView(targetKg: target.kg, unit: store.settings.weightUnit)
                    .presentationDetents([.medium])
            }
        }
    }
}

struct PlateTarget: Identifiable {
    let id = UUID()
    var kg: Double
}

struct WorkoutFormView: View {
    @Binding var workout: Workout
    @Binding var showingExercisePicker: Bool
    @Binding var plateTarget: PlateTarget?
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        List {
            Section {
                TextField("Workout title", text: $workout.title)
                    .font(.headline)
                HStack {
                    ElapsedTimeView(start: workout.startDate)
                    Spacer()
                    if let metrics = store.watchMetrics, metrics.isFresh() {
                        Label("\(Int(metrics.heartRate))", systemImage: "heart.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    }
                    Text("Volume: \(Stats.formattedVolume(workout.totalVolume, unit: store.settings.weightUnit))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach($workout.exercises) { $wex in
                Section {
                    ExerciseHeaderRow(wex: $wex, workout: $workout, plateTarget: $plateTarget)

                    SetColumnHeader(exercise: wex.exercise, unit: store.settings.weightUnit)

                    ForEach($wex.sets) { $set in
                        SetRow(set: $set,
                               number: (wex.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1,
                               exercise: wex.exercise) {
                            store.restTimer.start(seconds: store.settings.restSeconds)
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
                        } else if let previous = store.previousSet(for: wex.exercise.id, at: 0) {
                            newSet.weight = previous.weight
                            newSet.reps = previous.reps
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
}

struct ExerciseHeaderRow: View {
    @Binding var wex: WorkoutExercise
    @Binding var workout: Workout
    @Binding var plateTarget: PlateTarget?
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(wex.exercise.name)
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Menu {
                    if wex.exercise.usesWeight {
                        Button {
                            let kg = wex.sets.first(where: { !$0.isCompleted })?.weight
                                ?? wex.sets.last?.weight ?? 60
                            plateTarget = PlateTarget(kg: kg)
                        } label: {
                            Label("Plate Calculator", systemImage: "circle.circle")
                        }
                    }
                    Button("Remove Exercise", role: .destructive) {
                        workout.exercises.removeAll { $0.id == wex.id }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            TextField("Notes", text: $wex.notes, axis: .vertical)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SetColumnHeader: View {
    let exercise: Exercise
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            Text("SET")
                .frame(width: 28)
            Text("PREVIOUS")
                .frame(maxWidth: .infinity)
            if exercise.isCardio {
                Text("MIN").frame(maxWidth: .infinity)
                Text("KM").frame(maxWidth: .infinity)
            } else {
                if exercise.usesWeight {
                    Text(unit.suffix.uppercased()).frame(maxWidth: .infinity)
                }
                Text("REPS").frame(maxWidth: .infinity)
            }
            Image(systemName: "checkmark")
                .frame(width: 28)
        }
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
    }
}

struct SetRow: View {
    @Binding var set: WorkoutSet
    let number: Int
    let exercise: Exercise
    var onCompleted: () -> Void
    @Environment(WorkoutStore.self) private var store

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

            // Hevy's "previous" column: last session's matching set, tap to copy.
            Button {
                if let previous {
                    set.weight = previous.weight
                    set.reps = previous.reps
                }
            } label: {
                Text(previousLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            if exercise.isCardio {
                TextField("min", value: durationMinutesBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                TextField("km", value: distanceKmBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                if exercise.usesWeight {
                    TextField(store.settings.weightUnit.suffix, value: weightBinding, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                TextField("reps", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button {
                set.isCompleted.toggle()
                if set.isCompleted { onCompleted() }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                    if isPR {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 28)
        }
    }

    private var previous: WorkoutSet? {
        store.previousSet(for: exercise.id, at: number - 1)
    }

    private var previousLabel: String {
        guard let previous else { return "—" }
        return exercise.usesWeight
            ? "\(Stats.formattedWeight(previous.weight, unit: store.settings.weightUnit))×\(previous.reps)"
            : "\(previous.reps)"
    }

    private var isPR: Bool {
        return set.isCompleted && exercise.usesWeight
            && Insights.wouldBePR(exerciseID: exercise.id, weight: set.weight, reps: set.reps,
                                  history: store.history)
    }

    private var weightBinding: Binding<Double> {
        let unit = store.settings.weightUnit
        return Binding(
            get: { (unit.fromKg(set.weight) * 10).rounded() / 10 },
            set: { set.weight = unit.toKg($0) }
        )
    }

    private var durationMinutesBinding: Binding<Double> {
        Binding(
            get: { ((set.durationSeconds ?? 0) / 60 * 10).rounded() / 10 },
            set: { set.durationSeconds = $0 > 0 ? $0 * 60 : nil }
        )
    }

    private var distanceKmBinding: Binding<Double> {
        Binding(
            get: { ((set.distanceMeters ?? 0) / 1000 * 100).rounded() / 100 },
            set: { set.distanceMeters = $0 > 0 ? $0 * 1000 : nil }
        )
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
