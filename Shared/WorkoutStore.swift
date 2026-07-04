import Foundation
import Observation

@Observable
final class WorkoutStore {
    private struct State: Codable {
        var history: [Workout] = []
        var templates: [WorkoutTemplate] = []
        var customExercises: [Exercise] = []
        var activeWorkout: Workout? = nil
    }

    private(set) var history: [Workout] = []
    private(set) var templates: [WorkoutTemplate] = []
    private(set) var customExercises: [Exercise] = []
    var activeWorkout: Workout?
    let restTimer = RestTimer()

    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("fitx-store.json")
        let existed = FileManager.default.fileExists(atPath: fileURL.path)
        load()
        if !existed {
            templates = ExerciseLibrary.starterTemplates
            save()
        }
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FitX", isDirectory: true)
    }

    // MARK: - Workout lifecycle

    @discardableResult
    func startEmptyWorkout(title: String? = nil) -> Workout {
        let workout = Workout(title: title ?? Self.defaultTitle())
        activeWorkout = workout
        save()
        return workout
    }

    @discardableResult
    func startWorkout(from template: WorkoutTemplate) -> Workout {
        var workout = Workout(title: template.name)
        workout.exercises = template.exercises.map { planned in
            WorkoutExercise(exercise: planned.exercise,
                            sets: (0..<max(1, planned.plannedSets)).map { _ in WorkoutSet() })
        }
        activeWorkout = workout
        save()
        return workout
    }

    /// Discards incomplete sets (and exercises left with none), stamps the end
    /// date and moves the workout into history. Returns nil — and saves nothing —
    /// when no set was completed at all.
    @discardableResult
    func finishActiveWorkout(at endDate: Date = Date()) -> Workout? {
        guard var workout = activeWorkout else { return nil }
        workout.endDate = endDate
        workout.exercises = workout.exercises.map { wex in
            var wex = wex
            wex.sets.removeAll { !$0.isCompleted }
            return wex
        }
        workout.exercises.removeAll { $0.sets.isEmpty }
        activeWorkout = nil
        restTimer.stop()
        guard !workout.exercises.isEmpty else {
            save()
            return nil
        }
        history.insert(workout, at: 0)
        save()
        return workout
    }

    func cancelActiveWorkout() {
        activeWorkout = nil
        restTimer.stop()
        save()
    }

    func addExerciseToActiveWorkout(_ exercise: Exercise) {
        guard activeWorkout != nil else { return }
        activeWorkout?.exercises.append(WorkoutExercise(exercise: exercise, sets: [WorkoutSet()]))
        save()
    }

    // MARK: - History

    /// Merge a workout coming from the watch. Ignores duplicates by id.
    func importWorkout(_ workout: Workout) {
        guard !history.contains(where: { $0.id == workout.id }) else { return }
        history.append(workout)
        history.sort { $0.startDate > $1.startDate }
        save()
    }

    func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where history.indices.contains(index) {
            history.remove(at: index)
        }
        save()
    }

    /// Completed sets from the most recent workout containing this exercise.
    func lastSets(for exerciseID: String) -> [WorkoutSet] {
        for workout in history {
            guard let match = workout.exercises.first(where: { $0.exercise.id == exerciseID }) else { continue }
            let done = match.sets.filter(\.isCompleted)
            if !done.isEmpty { return done }
        }
        return []
    }

    func bestOneRepMax(for exerciseID: String) -> Double {
        var best = 0.0
        for workout in history {
            for wex in workout.exercises where wex.exercise.id == exerciseID {
                for set in wex.sets where set.isCompleted {
                    best = max(best, Stats.epleyOneRepMax(weight: set.weight, reps: set.reps))
                }
            }
        }
        return best
    }

    // MARK: - Templates

    func addTemplate(_ template: WorkoutTemplate) {
        templates.append(template)
        save()
    }

    func updateTemplate(_ template: WorkoutTemplate) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index] = template
        save()
    }

    func deleteTemplates(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where templates.indices.contains(index) {
            templates.remove(at: index)
        }
        save()
    }

    // MARK: - Exercises

    var allExercises: [Exercise] {
        (ExerciseLibrary.all + customExercises).sorted { $0.name < $1.name }
    }

    @discardableResult
    func addCustomExercise(name: String, muscleGroup: MuscleGroup, usesWeight: Bool = true) -> Exercise {
        let exercise = Exercise(id: "custom-\(UUID().uuidString)",
                                name: name,
                                muscleGroup: muscleGroup,
                                usesWeight: usesWeight,
                                isCustom: true)
        customExercises.append(exercise)
        save()
        return exercise
    }

    static func defaultTitle(for date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        case 17..<22: return "Evening Workout"
        default: return "Night Workout"
        }
    }

    // MARK: - Persistence

    func save() {
        let state = State(history: history,
                          templates: templates,
                          customExercises: customExercises,
                          activeWorkout: activeWorkout)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("FitX: failed to save store: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(State.self, from: data) else { return }
        history = state.history
        templates = state.templates
        customExercises = state.customExercises
        activeWorkout = state.activeWorkout
    }
}
