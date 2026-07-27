import Foundation

/// The in-app calorie scientist: cross-references what you eat, what you weigh
/// and what you burn training, then estimates your real daily burn (TDEE),
/// predicts where your weight is heading, and issues plain-English verdicts.
/// Pure functions over the stores' data — everything is testable.
enum EnergyModel {
    /// Energy in one kilogram of body mass change (the classic 3500 kcal/lb).
    static let kcalPerKg = 7700.0
    /// Rough maintenance multiplier used before enough data exists.
    static let fallbackKcalPerKg = 33.0
    /// Days of history the adaptive estimate looks back over.
    static let windowDays = 28
    /// Minimum days with logged food before the adaptive estimate speaks.
    static let minLoggedDays = 7
    /// Minimum span between first and last weigh-in for a usable slope.
    static let minWeighSpanDays = 7

    // MARK: - Daily intake

    /// Calories logged per calendar day, only days with at least one entry.
    static func dailyIntake(entries: [FoodEntry], calendar: Calendar = .current) -> [Date: Double] {
        var byDay: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            byDay[day, default: 0] += entry.calories
        }
        return byDay
    }

    // MARK: - Weight slope

    /// Least-squares slope through weigh-ins, in kg per day. nil when the data
    /// can't support a line (fewer than 2 points or no time spread).
    static func weightSlopeKgPerDay(_ weights: [BodyWeightEntry]) -> Double? {
        guard weights.count >= 2, let first = weights.first else { return nil }
        let points = weights.map { entry in
            (x: entry.date.timeIntervalSince(first.date) / 86_400, y: entry.weightKg)
        }
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumXX = points.reduce(0) { $0 + $1.x * $1.x }
        let denominator = n * sumXX - sumX * sumX
        guard denominator > 0.0001 else { return nil }
        return (n * sumXY - sumX * sumY) / denominator
    }

    // MARK: - TDEE

    struct TDEEEstimate: Hashable {
        /// Estimated true maintenance calories per day.
        var tdee: Double
        /// Average logged intake per day over the window.
        var avgIntake: Double
        /// Observed weight change rate over the window, kg per week.
        var weightChangeKgPerWeek: Double
        /// Days with food logged inside the window.
        var loggedDays: Int
        /// True once the window had enough food + weigh-in data to trust.
        var isAdaptive: Bool
    }

    /// Adaptive TDEE: avg intake minus the energy the weight trend accounts
    /// for. Eating 2000/day while losing 1 lb/week means you burn ~2500.
    /// Falls back to a bodyweight multiple until enough data accumulates.
    static func estimateTDEE(entries: [FoodEntry],
                             weights: [BodyWeightEntry],
                             asOf now: Date = Date(),
                             calendar: Calendar = .current) -> TDEEEstimate? {
        let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let intake = dailyIntake(entries: entries, calendar: calendar)
            .filter { $0.key >= calendar.startOfDay(for: cutoff) }
        let recentWeights = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }

        let latestKg = (recentWeights.last ?? weights.last)?.weightKg

        if intake.count >= minLoggedDays,
           let slope = weightSlopeKgPerDay(recentWeights),
           let span = spanDays(recentWeights), span >= Double(minWeighSpanDays) {
            let avgIntake = intake.values.reduce(0, +) / Double(intake.count)
            let tdee = avgIntake - slope * kcalPerKg
            return TDEEEstimate(tdee: max(1000, tdee),
                                avgIntake: avgIntake,
                                weightChangeKgPerWeek: slope * 7,
                                loggedDays: intake.count,
                                isAdaptive: true)
        }

        guard let latestKg else { return nil }
        let avgIntake = intake.isEmpty ? 0 : intake.values.reduce(0, +) / Double(intake.count)
        return TDEEEstimate(tdee: latestKg * fallbackKcalPerKg,
                            avgIntake: avgIntake,
                            weightChangeKgPerWeek: 0,
                            loggedDays: intake.count,
                            isAdaptive: false)
    }

    private static func spanDays(_ weights: [BodyWeightEntry]) -> Double? {
        guard let first = weights.first, let last = weights.last else { return nil }
        return last.date.timeIntervalSince(first.date) / 86_400
    }

    // MARK: - Prediction

    struct WeightPoint: Hashable {
        var date: Date
        var weightKg: Double
    }

    /// Where the scale is heading if the current eating pattern holds:
    /// weekly points from today out `weeksAhead`, driven by intake − TDEE.
    static func projectedWeights(from startKg: Double,
                                 avgIntake: Double,
                                 tdee: Double,
                                 weeksAhead: Int = 8,
                                 asOf now: Date = Date(),
                                 calendar: Calendar = .current) -> [WeightPoint] {
        let dailyDelta = (avgIntake - tdee) / kcalPerKg
        return (0...max(1, weeksAhead)).compactMap { week in
            guard let date = calendar.date(byAdding: .day, value: week * 7, to: now) else { return nil }
            return WeightPoint(date: date, weightKg: startKg + dailyDelta * Double(week * 7))
        }
    }

    // MARK: - Training burn

    /// Active calories per day from finished workouts. Uses the watch's real
    /// number when present, otherwise estimates ~6 kcal/min of training.
    static func trainingBurnByDay(history: [Workout], calendar: Calendar = .current) -> [Date: Double] {
        var byDay: [Date: Double] = [:]
        for workout in history where workout.endDate != nil {
            let day = calendar.startOfDay(for: workout.startDate)
            let burn = workout.activeCalories ?? (workout.duration / 60 * 6)
            byDay[day, default: 0] += burn
        }
        return byDay
    }

    // MARK: - Strength index

    struct IndexPoint: Hashable {
        var weekStart: Date
        var value: Double
    }

    /// One number for "am I getting stronger": each week's average best-e1RM
    /// across exercises, expressed relative to that exercise's first recorded
    /// week (100 = where you started). Only weighted movements count.
    static func strengthIndex(history: [Workout],
                              weeks: Int = 12,
                              asOf now: Date = Date(),
                              calendar: Calendar = .current) -> [IndexPoint] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        // exercise id -> week start -> best e1RM that week
        var bestByExerciseWeek: [String: [Date: Double]] = [:]
        for workout in history {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: workout.startDate)?.start else { continue }
            for wex in workout.exercises where wex.exercise.usesWeight {
                for set in wex.sets where set.isCompleted {
                    let score = Stats.epleyOneRepMax(weight: set.weight, reps: set.reps)
                    guard score > 0 else { continue }
                    let current = bestByExerciseWeek[wex.exercise.id]?[week] ?? 0
                    bestByExerciseWeek[wex.exercise.id, default: [:]][week] = max(current, score)
                }
            }
        }

        // Baseline = each exercise's earliest weekly best.
        var baseline: [String: Double] = [:]
        for (exerciseID, byWeek) in bestByExerciseWeek {
            if let firstWeek = byWeek.keys.min(), let value = byWeek[firstWeek], value > 0 {
                baseline[exerciseID] = value
            }
        }
        guard !baseline.isEmpty else { return [] }

        var points: [IndexPoint] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek) else { continue }
            var ratios: [Double] = []
            for (exerciseID, base) in baseline {
                if let value = bestByExerciseWeek[exerciseID]?[week] {
                    ratios.append(value / base * 100)
                }
            }
            if !ratios.isEmpty {
                points.append(IndexPoint(weekStart: week,
                                         value: ratios.reduce(0, +) / Double(ratios.count)))
            }
        }
        return points
    }

    // MARK: - Verdicts

    struct Verdict: Identifiable, Hashable {
        enum Direction: Hashable { case up, down, flat, warning }

        var id: String { title }
        var direction: Direction
        var title: String
        var detail: String
    }

    /// The coach's summary cards: strength, weight, estimated fat trend,
    /// workout momentum and the energy-balance readout.
    static func verdicts(history: [Workout],
                         entries: [FoodEntry],
                         weights: [BodyWeightEntry],
                         unit: WeightUnit,
                         asOf now: Date = Date(),
                         calendar: Calendar = .current) -> [Verdict] {
        var result: [Verdict] = []

        // Strength: recent strength-index pair vs the prior pair.
        let index = strengthIndex(history: history, asOf: now, calendar: calendar)
        var strengthTrend: Double? = nil
        if index.count >= 4 {
            let recent = (index[index.count - 1].value + index[index.count - 2].value) / 2
            let prior = (index[index.count - 3].value + index[index.count - 4].value) / 2
            if prior > 0 {
                strengthTrend = (recent - prior) / prior * 100
            }
        }
        if let strengthTrend {
            if strengthTrend > 1 {
                result.append(Verdict(direction: .up, title: "Strength is going up",
                                      detail: String(format: "Your lifts are up %.0f%% over the last month.", strengthTrend)))
            } else if strengthTrend < -1 {
                result.append(Verdict(direction: .warning, title: "Strength is slipping",
                                      detail: String(format: "Your lifts are down %.0f%% over the last month.", abs(strengthTrend))))
            } else {
                result.append(Verdict(direction: .flat, title: "Strength is holding steady",
                                      detail: "Your lifts have been flat over the last month."))
            }
        }

        // Weight: regression slope over the trailing window.
        let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let recentWeights = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        var weightPerWeek: Double? = nil
        if let slope = weightSlopeKgPerDay(recentWeights),
           let span = spanDays(recentWeights), span >= Double(minWeighSpanDays) {
            weightPerWeek = slope * 7
        }
        if let weightPerWeek {
            let perWeek = unit.fromKg(abs(weightPerWeek))
            let rate = String(format: "%.1f %@/week", perWeek, unit.suffix)
            if weightPerWeek > 0.045 {  // > ~0.1 lb/week
                result.append(Verdict(direction: .up, title: "Weight is going up",
                                      detail: "Gaining about \(rate) over the last 4 weeks."))
            } else if weightPerWeek < -0.045 {
                result.append(Verdict(direction: .down, title: "Weight is going down",
                                      detail: "Losing about \(rate) over the last 4 weeks."))
            } else {
                result.append(Verdict(direction: .flat, title: "Weight is holding steady",
                                      detail: "The scale has been flat over the last 4 weeks."))
            }
        }

        // Fat estimate: weight direction crossed with strength direction.
        if let weightPerWeek, let strengthTrend {
            let gaining = weightPerWeek > 0.045
            let losing = weightPerWeek < -0.045
            let strengthUp = strengthTrend > 1
            let strengthDown = strengthTrend < -1
            if losing && !strengthDown {
                result.append(Verdict(direction: .down, title: "Fat is likely going down",
                                      detail: "Weight is dropping while strength holds — that loss is mostly fat, not muscle."))
            } else if gaining && strengthUp {
                result.append(Verdict(direction: .up, title: "Lean gaining",
                                      detail: "Weight and strength are both climbing — a good share of the gain is muscle."))
            } else if gaining && !strengthUp {
                result.append(Verdict(direction: .warning, title: "Fat is likely going up",
                                      detail: "Weight is climbing but strength isn't — the surplus is probably going to fat."))
            } else if losing && strengthDown {
                result.append(Verdict(direction: .warning, title: "Losing muscle with the weight",
                                      detail: "Weight and strength are both falling — eat more protein and keep the big lifts heavy."))
            }
        }

        // Workout momentum: weekly training volume, recent 4 weeks vs prior 4.
        let momentum = volumeTrendPercent(history: history, asOf: now, calendar: calendar)
        if let momentum {
            if momentum < -10 {
                result.append(Verdict(direction: .warning, title: "Workouts aren't improving",
                                      detail: String(format: "Training volume is down %.0f%% vs the previous month. Add a set or a session.", abs(momentum))))
            } else if momentum > 10 {
                result.append(Verdict(direction: .up, title: "Workouts are ramping up",
                                      detail: String(format: "Training volume is up %.0f%% vs the previous month.", momentum)))
            }
        }

        // Energy balance readout.
        if let estimate = estimateTDEE(entries: entries, weights: weights, asOf: now, calendar: calendar),
           estimate.loggedDays >= 3, estimate.avgIntake > 0 {
            let gap = estimate.avgIntake - estimate.tdee
            let perWeekLb = WeightUnit.lb.fromKg(abs(gap) * 7 / kcalPerKg)
            let label = estimate.isAdaptive ? "your measured burn" : "your estimated burn"
            if abs(gap) < 100 {
                result.append(Verdict(direction: .flat, title: "Eating at maintenance",
                                      detail: String(format: "Averaging %.0f kcal/day, right at %@ of %.0f.", estimate.avgIntake, label, estimate.tdee)))
            } else if gap > 0 {
                result.append(Verdict(direction: .up, title: "Eating in a surplus",
                                      detail: String(format: "Averaging %.0f kcal/day vs %@ of %.0f — on pace to gain %.1f lb/week.", estimate.avgIntake, label, estimate.tdee, perWeekLb)))
            } else {
                result.append(Verdict(direction: .down, title: "Eating in a deficit",
                                      detail: String(format: "Averaging %.0f kcal/day vs %@ of %.0f — on pace to lose %.1f lb/week.", estimate.avgIntake, label, estimate.tdee, perWeekLb)))
            }
        }

        return result
    }

    /// Signed percent change in weekly completed volume, trailing 4 weeks vs
    /// the 4 before that. nil until both windows contain training.
    static func volumeTrendPercent(history: [Workout],
                                   asOf now: Date = Date(),
                                   calendar: Calendar = .current) -> Double? {
        guard let recentStart = calendar.date(byAdding: .day, value: -28, to: now),
              let priorStart = calendar.date(byAdding: .day, value: -56, to: now) else { return nil }
        var recent = 0.0
        var prior = 0.0
        for workout in history {
            if workout.startDate >= recentStart {
                recent += workout.totalVolume
            } else if workout.startDate >= priorStart {
                prior += workout.totalVolume
            }
        }
        guard prior > 0, recent > 0 else { return nil }
        return (recent - prior) / prior * 100
    }
}
