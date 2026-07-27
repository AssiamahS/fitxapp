import XCTest

final class EnergyModelTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: offset, to: reference)!
    }

    // MARK: - Weight slope

    func testWeightSlopeDetectsLoss() {
        // Losing exactly 0.1 kg/day over two weeks.
        let weights = (0...14).map { offset in
            BodyWeightEntry(date: day(-14 + offset), weightKg: 91.4 - Double(offset) * 0.1)
        }
        let slope = EnergyModel.weightSlopeKgPerDay(weights)
        XCTAssertNotNil(slope)
        XCTAssertEqual(slope!, -0.1, accuracy: 0.001)
    }

    func testWeightSlopeNeedsTwoPoints() {
        XCTAssertNil(EnergyModel.weightSlopeKgPerDay([]))
        XCTAssertNil(EnergyModel.weightSlopeKgPerDay([BodyWeightEntry(weightKg: 90)]))
    }

    // MARK: - Adaptive TDEE

    func testAdaptiveTDEEFromIntakeAndWeightLoss() {
        // Eating 2000/day while losing ~0.45 kg/week -> burning ~2495.
        var entries: [FoodEntry] = []
        var weights: [BodyWeightEntry] = []
        for offset in 0...20 {
            let date = day(-20 + offset)
            entries.append(FoodEntry(date: date, name: "Meal", calories: 2000))
            weights.append(BodyWeightEntry(date: date, weightKg: 91.0 - Double(offset) * 0.065))
        }
        let estimate = EnergyModel.estimateTDEE(entries: entries, weights: weights)
        XCTAssertNotNil(estimate)
        XCTAssertTrue(estimate!.isAdaptive)
        XCTAssertEqual(estimate!.avgIntake, 2000, accuracy: 1)
        XCTAssertEqual(estimate!.tdee, 2000 + 0.065 * EnergyModel.kcalPerKg, accuracy: 25)
        XCTAssertLessThan(estimate!.weightChangeKgPerWeek, 0)
    }

    func testFallbackTDEEWithoutFoodLog() {
        let weights = [BodyWeightEntry(date: day(-1), weightKg: 90)]
        let estimate = EnergyModel.estimateTDEE(entries: [], weights: weights)
        XCTAssertNotNil(estimate)
        XCTAssertFalse(estimate!.isAdaptive)
        XCTAssertEqual(estimate!.tdee, 90 * EnergyModel.fallbackKcalPerKg, accuracy: 1)
    }

    func testNoTDEEWithoutAnyWeight() {
        XCTAssertNil(EnergyModel.estimateTDEE(entries: [], weights: []))
    }

    // MARK: - Projection

    func testProjectionGainsInSurplus() {
        // 500 kcal/day surplus ≈ +0.45 kg/week.
        let points = EnergyModel.projectedWeights(from: 80, avgIntake: 3000, tdee: 2500, weeksAhead: 4)
        XCTAssertEqual(points.count, 5)
        XCTAssertEqual(points.first!.weightKg, 80, accuracy: 0.001)
        XCTAssertEqual(points.last!.weightKg, 80 + 500.0 * 28 / EnergyModel.kcalPerKg, accuracy: 0.01)
    }

    // MARK: - Verdicts

    func testDeficitVerdictAppears() {
        var entries: [FoodEntry] = []
        var weights: [BodyWeightEntry] = []
        for offset in 0...20 {
            let date = day(-20 + offset)
            entries.append(FoodEntry(date: date, name: "Meal", calories: 1800))
            weights.append(BodyWeightEntry(date: date, weightKg: 95.0 - Double(offset) * 0.08))
        }
        let verdicts = EnergyModel.verdicts(history: [], entries: entries, weights: weights, unit: .lb)
        XCTAssertTrue(verdicts.contains { $0.title == "Weight is going down" })
        XCTAssertTrue(verdicts.contains { $0.title == "Eating in a deficit" })
    }

    func testVolumeTrendFlagsDropoff() {
        // Prior month heavy, recent month light -> negative trend.
        func workout(daysAgo: Int, volumeKg: Double) -> Workout {
            var workout = Workout(title: "Session", startDate: day(-daysAgo))
            workout.endDate = day(-daysAgo).addingTimeInterval(3600)
            workout.exercises = [WorkoutExercise(
                exercise: Exercise(name: "Bench Press", muscleGroup: .chest),
                sets: [WorkoutSet(weight: volumeKg / 5, reps: 5, isCompleted: true)])]
            return workout
        }
        let history = [workout(daysAgo: 40, volumeKg: 4000),
                       workout(daysAgo: 35, volumeKg: 4000),
                       workout(daysAgo: 10, volumeKg: 2000)]
        let trend = EnergyModel.volumeTrendPercent(history: history)
        XCTAssertNotNil(trend)
        XCTAssertLessThan(trend!, -10)
    }

    // MARK: - Strength index

    func testStrengthIndexRisesWithHeavierLifts() {
        func session(weeksAgo: Int, benchKg: Double) -> Workout {
            var workout = Workout(title: "Push", startDate: day(-weeksAgo * 7))
            workout.endDate = workout.startDate.addingTimeInterval(3600)
            workout.exercises = [WorkoutExercise(
                exercise: Exercise(name: "Bench Press", muscleGroup: .chest),
                sets: [WorkoutSet(weight: benchKg, reps: 5, isCompleted: true)])]
            return workout
        }
        let history = [session(weeksAgo: 3, benchKg: 80),
                       session(weeksAgo: 2, benchKg: 85),
                       session(weeksAgo: 1, benchKg: 90)]
        let index = EnergyModel.strengthIndex(history: history)
        XCTAssertGreaterThanOrEqual(index.count, 2)
        XCTAssertEqual(index.first!.value, 100, accuracy: 0.5)
        XCTAssertGreaterThan(index.last!.value, index.first!.value)
    }

    // MARK: - Default unit

    func testDefaultWeightUnitIsPounds() {
        XCTAssertEqual(WeightUnit.defaultForLocale, .lb)
        XCTAssertEqual(UserSettings().weightUnit, .lb)
    }
}

final class MealTextParserTests: XCTestCase {
    private let foods: [GenericFood] = [
        GenericFood(name: "Sausage Egg and Cheese Sandwich", caloriesPer100g: 290,
                    proteinPer100g: 12, carbsPer100g: 21, fatPer100g: 17.5,
                    servingGrams: 160, synonyms: ["sausage egg and cheese"]),
        GenericFood(name: "Eggs", caloriesPer100g: 155,
                    proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11,
                    servingGrams: 50, synonyms: ["egg", "scrambled eggs"]),
        GenericFood(name: "Bacon", caloriesPer100g: 540,
                    proteinPer100g: 37, carbsPer100g: 1.4, fatPer100g: 42,
                    servingGrams: 12, synonyms: ["bacon strips"]),
        GenericFood(name: "Toast", caloriesPer100g: 290,
                    proteinPer100g: 9, carbsPer100g: 50, fatPer100g: 4.5,
                    servingGrams: 35, synonyms: ["buttered toast"]),
    ]

    func testCompoundBeatsIngredients() {
        let result = MealTextParser.parse("we did sausage egg and cheese", foods: foods)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.food.name, "Sausage Egg and Cheese Sandwich")
        XCTAssertTrue(result.unmatched.isEmpty)
    }

    func testSplitsOnCommaAndAnd() {
        let result = MealTextParser.parse("2 eggs, bacon and toast", foods: foods)
        XCTAssertEqual(result.items.map(\.food.name).sorted(), ["Bacon", "Eggs", "Toast"])
        let eggs = result.items.first { $0.food.name == "Eggs" }
        XCTAssertEqual(eggs?.quantity, 2)
        XCTAssertEqual(eggs?.calories ?? 0, 155.0 * 100 / 100, accuracy: 0.5) // 2 × 50 g at 155/100 g
    }

    func testUnknownFoodReported() {
        let result = MealTextParser.parse("fufu", foods: foods)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.unmatched, ["fufu"])
    }

    func testQuantityParsing() {
        let (quantity, phrase) = MealTextParser.leadingQuantity("3 bacon strips")
        XCTAssertEqual(quantity, 3)
        XCTAssertEqual(phrase, "bacon strips")
    }
}
