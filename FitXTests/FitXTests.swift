import XCTest

final class FitXTests: XCTestCase {
    private var tempDir: URL!
    private var store: WorkoutStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = WorkoutStore(directory: tempDir)
    }

    override func tearDownWithError() throws {
        store = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Seeding

    func testStarterTemplatesSeededOnFirstLaunch() {
        XCTAssertEqual(store.templates.count, 3)
        XCTAssertEqual(store.templates.map(\.name), ["Push Day", "Pull Day", "Leg Day"])
    }

    func testSeedingOnlyHappensOnce() {
        store.deleteTemplates(at: IndexSet(integersIn: 0..<store.templates.count))
        XCTAssertTrue(store.templates.isEmpty)

        let reloaded = WorkoutStore(directory: tempDir)
        XCTAssertTrue(reloaded.templates.isEmpty, "wiping templates must survive a relaunch")
    }

    // MARK: - Workout lifecycle

    func testStartWorkoutFromTemplateCreatesPlannedSets() {
        let template = store.templates[0]
        let workout = store.startWorkout(from: template)

        XCTAssertEqual(workout.title, "Push Day")
        XCTAssertEqual(workout.exercises.count, template.exercises.count)
        for (planned, wex) in zip(template.exercises, workout.exercises) {
            XCTAssertEqual(wex.sets.count, planned.plannedSets)
            XCTAssertEqual(wex.exercise.id, planned.exercise.id)
            XCTAssertTrue(wex.sets.allSatisfy { !$0.isCompleted })
        }
        XCTAssertNotNil(store.activeWorkout)
    }

    func testFinishWorkoutKeepsOnlyCompletedSetsAndMovesToHistory() {
        store.startEmptyWorkout(title: "Test")
        store.addExerciseToActiveWorkout(ExerciseLibrary.exercise(named: "Bench Press"))
        store.addExerciseToActiveWorkout(ExerciseLibrary.exercise(named: "Squat"))

        store.activeWorkout?.exercises[0].sets = [
            WorkoutSet(weight: 60, reps: 8, isCompleted: true),
            WorkoutSet(weight: 60, reps: 8, isCompleted: false),
        ]
        store.activeWorkout?.exercises[1].sets = [
            WorkoutSet(weight: 100, reps: 5, isCompleted: false),
        ]

        let finished = store.finishActiveWorkout()

        XCTAssertNotNil(finished)
        XCTAssertNil(store.activeWorkout)
        XCTAssertEqual(store.history.count, 1)
        // Squat had no completed sets, so only Bench Press survives.
        XCTAssertEqual(finished?.exercises.count, 1)
        XCTAssertEqual(finished?.exercises[0].sets.count, 1)
        XCTAssertEqual(finished?.completedSetCount, 1)
        XCTAssertNotNil(finished?.endDate)
    }

    func testFinishWithNoCompletedSetsDiscardsWorkout() {
        store.startEmptyWorkout(title: "Empty")
        store.addExerciseToActiveWorkout(ExerciseLibrary.exercise(named: "Bench Press"))

        let finished = store.finishActiveWorkout()

        XCTAssertNil(finished)
        XCTAssertNil(store.activeWorkout)
        XCTAssertTrue(store.history.isEmpty)
    }

    func testCancelClearsActiveWorkoutWithoutHistory() {
        store.startEmptyWorkout(title: "Cancelled")
        store.cancelActiveWorkout()

        XCTAssertNil(store.activeWorkout)
        XCTAssertTrue(store.history.isEmpty)
    }

    // MARK: - Persistence

    func testStateSurvivesRelaunch() {
        store.startEmptyWorkout(title: "Persisted")
        store.addExerciseToActiveWorkout(ExerciseLibrary.exercise(named: "Deadlift"))
        store.activeWorkout?.exercises[0].sets = [WorkoutSet(weight: 120, reps: 5, isCompleted: true)]
        store.finishActiveWorkout()
        store.addCustomExercise(name: "Sled Push", muscleGroup: .fullBody)

        let reloaded = WorkoutStore(directory: tempDir)

        XCTAssertEqual(reloaded.history.count, 1)
        XCTAssertEqual(reloaded.history[0].title, "Persisted")
        XCTAssertEqual(reloaded.history[0].exercises[0].sets[0].weight, 120)
        XCTAssertEqual(reloaded.customExercises.map(\.name), ["Sled Push"])
    }

    func testActiveWorkoutSurvivesRelaunch() {
        store.startEmptyWorkout(title: "Mid-workout")
        store.addExerciseToActiveWorkout(ExerciseLibrary.exercise(named: "Squat"))
        store.save()

        let reloaded = WorkoutStore(directory: tempDir)

        XCTAssertEqual(reloaded.activeWorkout?.title, "Mid-workout")
        XCTAssertEqual(reloaded.activeWorkout?.exercises.count, 1)
    }

    // MARK: - Import / dedupe (watch sync path)

    func testImportWorkoutSortsByDateAndDeduplicates() {
        var older = Workout(title: "Older")
        older.startDate = Date(timeIntervalSince1970: 1_000)
        older.endDate = Date(timeIntervalSince1970: 2_000)
        var newer = Workout(title: "Newer")
        newer.startDate = Date(timeIntervalSince1970: 5_000)
        newer.endDate = Date(timeIntervalSince1970: 6_000)

        store.importWorkout(older)
        store.importWorkout(newer)
        store.importWorkout(older) // duplicate — must be ignored

        XCTAssertEqual(store.history.count, 2)
        XCTAssertEqual(store.history.map(\.title), ["Newer", "Older"])
    }

    // MARK: - Exercise stats

    func testLastSetsReturnsMostRecentCompletedSets() {
        let bench = ExerciseLibrary.exercise(named: "Bench Press")

        var old = Workout(title: "Old")
        old.startDate = Date(timeIntervalSince1970: 1_000)
        old.exercises = [WorkoutExercise(exercise: bench, sets: [WorkoutSet(weight: 50, reps: 10, isCompleted: true)])]
        var recent = Workout(title: "Recent")
        recent.startDate = Date(timeIntervalSince1970: 9_000)
        recent.exercises = [WorkoutExercise(exercise: bench, sets: [WorkoutSet(weight: 65, reps: 6, isCompleted: true)])]

        store.importWorkout(old)
        store.importWorkout(recent)

        let last = store.lastSets(for: bench.id)
        XCTAssertEqual(last.count, 1)
        XCTAssertEqual(last[0].weight, 65)
    }

    func testBestOneRepMaxScansAllHistory() {
        let squat = ExerciseLibrary.exercise(named: "Squat")
        var workout = Workout(title: "Legs")
        workout.exercises = [WorkoutExercise(exercise: squat, sets: [
            WorkoutSet(weight: 100, reps: 5, isCompleted: true),
            WorkoutSet(weight: 140, reps: 1, isCompleted: true),
            WorkoutSet(weight: 200, reps: 10, isCompleted: false), // not completed — ignored
        ])]
        store.importWorkout(workout)

        // 100kg × 5 → Epley ≈ 116.7, beats the 140 single.
        XCTAssertEqual(store.bestOneRepMax(for: squat.id), 100 * (1 + 5.0 / 30.0), accuracy: 0.01)
    }

    func testEpleyOneRepMax() {
        XCTAssertEqual(Stats.epleyOneRepMax(weight: 100, reps: 1), 100)
        XCTAssertEqual(Stats.epleyOneRepMax(weight: 100, reps: 10), 100 * (1 + 10.0 / 30.0), accuracy: 0.001)
        XCTAssertEqual(Stats.epleyOneRepMax(weight: 0, reps: 10), 0)
        XCTAssertEqual(Stats.epleyOneRepMax(weight: 100, reps: 0), 0)
    }

    func testTotalVolumeCountsOnlyCompletedSets() {
        var workout = Workout(title: "Volume")
        workout.exercises = [WorkoutExercise(exercise: ExerciseLibrary.exercise(named: "Bench Press"), sets: [
            WorkoutSet(weight: 60, reps: 8, isCompleted: true),   // 480
            WorkoutSet(weight: 60, reps: 8, isCompleted: false),  // ignored
            WorkoutSet(weight: 80, reps: 5, isCompleted: true),   // 400
        ])]
        XCTAssertEqual(workout.totalVolume, 880, accuracy: 0.001)
    }

    // MARK: - Rest timer

    func testRestTimerCountdownAndExtension() {
        let timer = RestTimer()
        let t0 = Date(timeIntervalSince1970: 0)

        timer.start(seconds: 90, from: t0)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(30)), 60, accuracy: 0.001)

        timer.add(seconds: 30)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(30)), 90, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(1_000)), 0)

        timer.stop()
        XCTAssertEqual(timer.remaining(at: t0), 0)
        XCTAssertFalse(timer.isRunning)
    }

    // MARK: - Misc

    func testDefaultTitleFollowsTimeOfDay() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        let morning = Calendar.current.date(from: components)!
        components.hour = 19
        let evening = Calendar.current.date(from: components)!

        XCTAssertEqual(WorkoutStore.defaultTitle(for: morning), "Morning Workout")
        XCTAssertEqual(WorkoutStore.defaultTitle(for: evening), "Evening Workout")
    }

    func testWorkoutCodableRoundTrip() throws {
        var workout = Workout(title: "Round Trip")
        workout.exercises = [WorkoutExercise(exercise: ExerciseLibrary.exercise(named: "Deadlift"),
                                             sets: [WorkoutSet(weight: 142.5, reps: 3, isCompleted: true)])]
        workout.endDate = workout.startDate.addingTimeInterval(3_600)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Workout.self, from: encoder.encode(workout))

        XCTAssertEqual(decoded.id, workout.id)
        XCTAssertEqual(decoded.exercises[0].sets[0].weight, 142.5)
        XCTAssertEqual(decoded.totalVolume, workout.totalVolume)
    }

    func testExerciseLibraryHasNoDuplicateIDs() {
        let ids = ExerciseLibrary.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
