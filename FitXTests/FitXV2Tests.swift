import XCTest

/// v2 features: insights/trends, PRs, nutrition math, unit conversion,
/// and store back-compat with v1 files.
final class FitXV2Tests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Helpers

    private func workout(daysAgo: Int, exercise: Exercise, sets: [(Double, Int)],
                         asOf now: Date = Date()) -> Workout {
        var workout = Workout(title: "W-\(daysAgo)")
        workout.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        workout.endDate = workout.startDate.addingTimeInterval(3600)
        workout.exercises = [WorkoutExercise(exercise: exercise,
                                             sets: sets.map { WorkoutSet(weight: $0.0, reps: $0.1, isCompleted: true) })]
        return workout
    }

    private let bench = ExerciseLibrary.exercise(named: "Bench Press")

    // MARK: - Insights: trends

    func testDecliningTrendDetected() {
        // Session best e1RM drops session over session: 100, 100, 95, 90.
        let history = [
            workout(daysAgo: 21, exercise: bench, sets: [(100, 1)]),
            workout(daysAgo: 14, exercise: bench, sets: [(100, 1)]),
            workout(daysAgo: 7, exercise: bench, sets: [(95, 1)]),
            workout(daysAgo: 1, exercise: bench, sets: [(90, 1)]),
        ]
        let insight = Insights.insight(for: bench.id, history: history)

        XCTAssertEqual(insight.trend, .declining)
        XCTAssertLessThan(insight.trendPercent, 0)
        XCTAssertEqual(insight.decliningStreak, 2)
        XCTAssertFalse(insight.isStale)
    }

    func testImprovingTrendDetected() {
        let history = [
            workout(daysAgo: 21, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 14, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 7, exercise: bench, sets: [(85, 5)]),
            workout(daysAgo: 1, exercise: bench, sets: [(90, 5)]),
        ]
        let insight = Insights.insight(for: bench.id, history: history)

        XCTAssertEqual(insight.trend, .improving)
        XCTAssertGreaterThan(insight.trendPercent, 0)
    }

    func testFewSessionsMeansNewTrend() {
        let history = [
            workout(daysAgo: 7, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 1, exercise: bench, sets: [(90, 5)]),
        ]
        XCTAssertEqual(Insights.insight(for: bench.id, history: history).trend, .new)
    }

    func testStaleAfterFourWeeksOff() {
        // "You haven't hit this move in 4 weeks."
        let history = [
            workout(daysAgo: 40, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 30, exercise: bench, sets: [(85, 5)]),
        ]
        let insight = Insights.insight(for: bench.id, history: history)

        XCTAssertTrue(insight.isStale)
        XCTAssertEqual(insight.weeksSinceLast, 4)
    }

    func testTrailingDeclineCount() {
        XCTAssertEqual(Insights.trailingDeclineCount([100, 95, 90]), 2)
        XCTAssertEqual(Insights.trailingDeclineCount([90, 95, 100]), 0)
        XCTAssertEqual(Insights.trailingDeclineCount([100, 110, 105, 100]), 2)
        XCTAssertEqual(Insights.trailingDeclineCount([]), 0)
        XCTAssertEqual(Insights.trailingDeclineCount([100]), 0)
    }

    func testCoachMessagesLeadWithWarnings() {
        let squat = ExerciseLibrary.exercise(named: "Squat")
        let history = [
            // Bench improving.
            workout(daysAgo: 21, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 14, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 7, exercise: bench, sets: [(85, 5)]),
            workout(daysAgo: 1, exercise: bench, sets: [(92, 5)]),
            // Squat abandoned 6 weeks ago.
            workout(daysAgo: 50, exercise: squat, sets: [(120, 5)]),
            workout(daysAgo: 43, exercise: squat, sets: [(120, 5)]),
        ]
        let messages = Insights.coachMessages(history: history, exercises: [bench, squat])

        XCTAssertFalse(messages.isEmpty)
        XCTAssertEqual(messages.first?.kind, .stale)
        XCTAssertEqual(messages.first?.exerciseID, squat.id)
        XCTAssertTrue(messages.contains { $0.kind == .improving && $0.exerciseID == bench.id })
    }

    // MARK: - Insights: freshness, streak, PRs

    func testMuscleFreshnessTracksMostRecentDay() {
        let history = [
            workout(daysAgo: 9, exercise: bench, sets: [(80, 5)]),
            workout(daysAgo: 3, exercise: bench, sets: [(80, 5)]),
        ]
        let freshness = Insights.muscleFreshness(history: history)

        XCTAssertEqual(freshness[.chest] ?? nil, 3)
        XCTAssertNil(freshness[.quads] ?? nil, "never-trained groups stay nil")
    }

    func testStreakCountsConsecutiveWeeks() {
        let now = Date()
        let history = [
            workout(daysAgo: 2, exercise: bench, sets: [(80, 5)], asOf: now),
            workout(daysAgo: 8, exercise: bench, sets: [(80, 5)], asOf: now),
            workout(daysAgo: 15, exercise: bench, sets: [(80, 5)], asOf: now),
            // gap — nothing 4 weeks back
            workout(daysAgo: 36, exercise: bench, sets: [(80, 5)], asOf: now),
        ]
        let streak = Insights.currentStreakWeeks(history: history, asOf: now)
        // Current week + the two before it are covered; the gap ends the run.
        XCTAssertGreaterThanOrEqual(streak, 2)
        XCTAssertLessThanOrEqual(streak, 3)
        XCTAssertEqual(Insights.currentStreakWeeks(history: [], asOf: now), 0)
    }

    func testPRSetsFlagOnlyNewRecords() {
        let old = workout(daysAgo: 10, exercise: bench, sets: [(100, 5)]) // e1RM ≈ 116.7
        let new = workout(daysAgo: 1, exercise: bench, sets: [(90, 5), (110, 5)]) // second beats it
        let history = [new, old]

        let prs = Insights.prSets(in: new, history: history)

        XCTAssertEqual(prs.count, 1)
        XCTAssertTrue(prs.contains(new.exercises[0].sets[1].id))
    }

    func testWouldBePRAgainstHistory() {
        let history = [workout(daysAgo: 10, exercise: bench, sets: [(100, 5)])]
        XCTAssertTrue(Insights.wouldBePR(exerciseID: bench.id, weight: 105, reps: 5, history: history))
        XCTAssertFalse(Insights.wouldBePR(exerciseID: bench.id, weight: 95, reps: 5, history: history))
        XCTAssertFalse(Insights.wouldBePR(exerciseID: bench.id, weight: 0, reps: 5, history: history))
    }

    // MARK: - Store v2

    func testFinishStampsWatchMetrics() {
        let store = WorkoutStore(directory: tempDir)
        store.startEmptyWorkout(title: "HR test")
        store.addExerciseToActiveWorkout(bench)
        store.activeWorkout?.exercises[0].sets = [WorkoutSet(weight: 60, reps: 8, isCompleted: true)]

        let finished = store.finishActiveWorkout(avgHeartRate: 132, maxHeartRate: 171, activeCalories: 245)

        XCTAssertEqual(finished?.avgHeartRate, 132)
        XCTAssertEqual(finished?.maxHeartRate, 171)
        XCTAssertEqual(finished?.activeCalories, 245)

        let reloaded = WorkoutStore(directory: tempDir)
        XCTAssertEqual(reloaded.history.first?.avgHeartRate, 132)
    }

    func testRepeatWorkoutCopiesSetsUncompleted() {
        let store = WorkoutStore(directory: tempDir)
        var past = Workout(title: "Push Day")
        past.exercises = [WorkoutExercise(exercise: bench, sets: [
            WorkoutSet(weight: 80, reps: 8, isCompleted: true),
            WorkoutSet(weight: 85, reps: 6, isCompleted: true),
        ])]
        store.importWorkout(past)

        let repeated = store.repeatWorkout(past)

        XCTAssertEqual(repeated.exercises.count, 1)
        XCTAssertEqual(repeated.exercises[0].sets.count, 2)
        XCTAssertEqual(repeated.exercises[0].sets[1].weight, 85)
        XCTAssertTrue(repeated.exercises[0].sets.allSatisfy { !$0.isCompleted })
        XCTAssertNotEqual(repeated.id, past.id)
    }

    func testPreviousSetMatchesIndex() {
        let store = WorkoutStore(directory: tempDir)
        var past = Workout(title: "Push Day")
        past.exercises = [WorkoutExercise(exercise: bench, sets: [
            WorkoutSet(weight: 80, reps: 8, isCompleted: true),
            WorkoutSet(weight: 85, reps: 6, isCompleted: true),
        ])]
        store.importWorkout(past)

        XCTAssertEqual(store.previousSet(for: bench.id, at: 0)?.weight, 80)
        XCTAssertEqual(store.previousSet(for: bench.id, at: 1)?.weight, 85)
        // Past the previous session's count → falls back to its last set.
        XCTAssertEqual(store.previousSet(for: bench.id, at: 5)?.weight, 85)
    }

    func testV1StoreFileStillLoads() throws {
        // A file written by FitX 0.1.x — no settings, no bodyWeights, no HR fields.
        let v1JSON = """
        {
          "history": [{
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Legacy",
            "startDate": "2026-06-01T10:00:00Z",
            "endDate": "2026-06-01T11:00:00Z",
            "exercises": [{
              "id": "22222222-2222-2222-2222-222222222222",
              "exercise": {"id": "bench-press", "name": "Bench Press", "muscleGroup": "chest",
                           "usesWeight": true, "isCustom": false},
              "sets": [{"id": "33333333-3333-3333-3333-333333333333", "type": "normal",
                        "weight": 60, "reps": 8, "isCompleted": true}],
              "notes": ""
            }],
            "notes": ""
          }],
          "templates": [],
          "customExercises": [],
          "activeWorkout": null
        }
        """
        try v1JSON.data(using: .utf8)!.write(to: tempDir.appendingPathComponent("fitx-store.json"))

        let store = WorkoutStore(directory: tempDir)

        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.history[0].title, "Legacy")
        XCTAssertEqual(store.history[0].exercises[0].sets[0].weight, 60)
        XCTAssertNil(store.history[0].avgHeartRate)
        // v1 files carry no settings, so the unit falls back to the locale default.
        XCTAssertEqual(store.settings.weightUnit, .defaultForLocale)
        XCTAssertTrue(store.bodyWeights.isEmpty)
        // v1 file existed, so starter templates must NOT be re-seeded over it.
        XCTAssertTrue(store.templates.isEmpty)
    }

    // MARK: - Units

    func testWeightUnitConversionRoundTrips() {
        XCTAssertEqual(WeightUnit.lb.fromKg(100), 220.462, accuracy: 0.01)
        XCTAssertEqual(WeightUnit.lb.toKg(WeightUnit.lb.fromKg(72.5)), 72.5, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.kg.fromKg(80), 80)
        XCTAssertEqual(Stats.formattedWeight(100, unit: .lb), "220.5 lb")
        XCTAssertEqual(Stats.formattedWeight(100, unit: .kg), "100 kg")
    }

    // MARK: - Nutrition

    func testDayTotalsSumOnlyThatDay() {
        let nutrition = NutritionStore(directory: tempDir)
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        nutrition.add(FoodEntry(date: today, meal: .breakfast, name: "Oats",
                                calories: 300, protein: 10, carbs: 54, fat: 6))
        nutrition.add(FoodEntry(date: today, meal: .lunch, name: "Chicken",
                                calories: 400, protein: 45, carbs: 0, fat: 12))
        nutrition.add(FoodEntry(date: yesterday, meal: .dinner, name: "Pizza",
                                calories: 800, protein: 30, carbs: 90, fat: 32))

        let totals = nutrition.totals(on: today)
        XCTAssertEqual(totals.calories, 700, accuracy: 0.001)
        XCTAssertEqual(totals.protein, 55, accuracy: 0.001)
        XCTAssertEqual(nutrition.entries(on: today, meal: .breakfast).count, 1)
        XCTAssertEqual(nutrition.entries(on: yesterday).count, 1)
    }

    func testNutritionPersistsAcrossRelaunch() {
        let nutrition = NutritionStore(directory: tempDir)
        nutrition.add(FoodEntry(name: "Eggs", calories: 155, protein: 13, carbs: 1, fat: 11))
        nutrition.updateTargets(MacroTargets(calories: 2500, protein: 180, carbs: 250, fat: 80))

        let reloaded = NutritionStore(directory: tempDir)

        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries[0].name, "Eggs")
        XCTAssertEqual(reloaded.targets.calories, 2500)
        XCTAssertEqual(reloaded.targets.protein, 180)
    }

    func testRecentFoodsDeduplicateByName() {
        let nutrition = NutritionStore(directory: tempDir)
        for _ in 0..<3 {
            nutrition.add(FoodEntry(name: "Banana", calories: 105, protein: 1, carbs: 27, fat: 0))
        }
        nutrition.add(FoodEntry(name: "Apple", calories: 95, protein: 0, carbs: 25, fat: 0))

        XCTAssertEqual(nutrition.recentFoods.count, 2)
    }

    func testDeleteEntry() {
        let nutrition = NutritionStore(directory: tempDir)
        let entry = FoodEntry(name: "Toast", calories: 120, protein: 4, carbs: 22, fat: 2)
        nutrition.add(entry)
        nutrition.delete(entry)
        XCTAssertTrue(nutrition.entries.isEmpty)
    }

    // MARK: - Cardio sets

    func testCardioFieldsSurviveRoundTrip() throws {
        var set = WorkoutSet(weight: 0, reps: 0, isCompleted: true)
        set.durationSeconds = 1200
        set.distanceMeters = 3200

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WorkoutSet.self, from: encoder.encode(set))

        XCTAssertEqual(decoded.durationSeconds, 1200)
        XCTAssertEqual(decoded.distanceMeters, 3200)
        XCTAssertEqual(decoded.volume, 0, "cardio contributes no lifting volume")
    }
}
