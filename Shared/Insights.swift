import Foundation

/// One data point per workout that contained completed sets of an exercise.
/// `score` is the best Epley e1RM for weighted movements, best rep count for
/// bodyweight ones — good enough to compare session against session.
struct ExerciseSession: Hashable {
    var date: Date
    var score: Double
    var bestSetVolume: Double
    var totalVolume: Double
}

struct ExerciseInsight: Hashable {
    enum Trend: Hashable {
        case new          // fewer than 4 sessions — not enough signal
        case improving
        case steady
        case declining
    }

    var exerciseID: String
    var sessions: [ExerciseSession] = []   // oldest first
    var trend: Trend = .new
    var trendPercent: Double = 0           // signed, recent pair vs prior pair
    var decliningStreak: Int = 0           // consecutive session-over-session drops
    var lastPerformed: Date? = nil
    var weeksSinceLast: Int? = nil

    var isStale: Bool {
        guard let weeksSinceLast, sessions.count >= 2 else { return false }
        return weeksSinceLast >= Insights.staleWeeks
    }
}

struct CoachMessage: Identifiable, Hashable {
    enum Kind: Hashable { case stale, declining, improving }

    var id: String { "\(exerciseID)-\(title)" }
    var kind: Kind
    var exerciseID: String
    var title: String
    var detail: String
}

enum Insights {
    static let staleWeeks = 4
    /// Relative change below which two session pairs count as "steady".
    static let steadyBand = 0.025

    // MARK: - Per-exercise

    static func sessions(for exerciseID: String, history: [Workout]) -> [ExerciseSession] {
        history
            .compactMap { workout -> ExerciseSession? in
                let done = workout.exercises
                    .filter { $0.exercise.id == exerciseID }
                    .flatMap { wex in wex.sets.filter(\.isCompleted).map { (wex.exercise, $0) } }
                guard !done.isEmpty else { return nil }
                let scores = done.map { exercise, set in
                    exercise.usesWeight
                        ? Stats.epleyOneRepMax(weight: set.weight, reps: set.reps)
                        : Double(set.reps)
                }
                let volumes = done.map { $0.1.weight * Double($0.1.reps) }
                return ExerciseSession(date: workout.startDate,
                                       score: scores.max() ?? 0,
                                       bestSetVolume: volumes.max() ?? 0,
                                       totalVolume: volumes.reduce(0, +))
            }
            .sorted { $0.date < $1.date }
    }

    static func insight(for exerciseID: String, history: [Workout], asOf now: Date = Date()) -> ExerciseInsight {
        var insight = ExerciseInsight(exerciseID: exerciseID)
        insight.sessions = sessions(for: exerciseID, history: history)
        guard let last = insight.sessions.last else { return insight }

        insight.lastPerformed = last.date
        let days = Calendar.current.dateComponents([.day], from: last.date, to: now).day ?? 0
        insight.weeksSinceLast = max(0, days) / 7

        let scores = insight.sessions.map(\.score)
        insight.decliningStreak = trailingDeclineCount(scores)

        if scores.count >= 4 {
            let recent = (scores[scores.count - 2] + scores[scores.count - 1]) / 2
            let prior = (scores[scores.count - 4] + scores[scores.count - 3]) / 2
            if prior > 0 {
                let change = (recent - prior) / prior
                insight.trendPercent = change * 100
                if change > steadyBand {
                    insight.trend = .improving
                } else if change < -steadyBand {
                    insight.trend = .declining
                } else {
                    insight.trend = .steady
                }
            } else {
                insight.trend = .steady
            }
        }
        return insight
    }

    /// Number of consecutive strictly-decreasing steps at the end of the series.
    static func trailingDeclineCount(_ scores: [Double]) -> Int {
        var count = 0
        var index = scores.count - 1
        while index > 0, scores[index] < scores[index - 1] - 0.001 {
            count += 1
            index -= 1
        }
        return count
    }

    // MARK: - Coach cards

    static func coachMessages(history: [Workout],
                              exercises: [Exercise],
                              asOf now: Date = Date(),
                              limit: Int = 3) -> [CoachMessage] {
        var stale: [CoachMessage] = []
        var declining: [CoachMessage] = []
        var improving: [CoachMessage] = []

        for exercise in exercises {
            let insight = insight(for: exercise.id, history: history, asOf: now)
            guard !insight.sessions.isEmpty else { continue }

            if insight.isStale, let weeks = insight.weeksSinceLast {
                stale.append(CoachMessage(
                    kind: .stale,
                    exerciseID: exercise.id,
                    title: "\(exercise.name): \(weeks) weeks off",
                    detail: "You haven't hit \(exercise.name) in \(weeks) weeks. Time to bring it back."))
            } else if insight.trend == .declining || insight.decliningStreak >= 2 {
                let sessions = max(insight.decliningStreak, 2)
                declining.append(CoachMessage(
                    kind: .declining,
                    exerciseID: exercise.id,
                    title: "\(exercise.name) is slipping",
                    detail: "Down \(String(format: "%.0f", abs(insight.trendPercent)))% — declining for \(sessions) sessions."))
            } else if insight.trend == .improving {
                improving.append(CoachMessage(
                    kind: .improving,
                    exerciseID: exercise.id,
                    title: "\(exercise.name) trending up",
                    detail: "Up \(String(format: "%.0f", insight.trendPercent))% over your last 4 sessions. Keep pushing."))
            }
        }

        // Warnings first — that's what a coach would lead with.
        return Array((stale + declining + improving).prefix(limit))
    }

    // MARK: - Muscle freshness (Fitbod-style recovery)

    /// Days since each muscle group last saw a completed set. nil = never trained.
    static func muscleFreshness(history: [Workout], asOf now: Date = Date()) -> [MuscleGroup: Int?] {
        var result: [MuscleGroup: Int?] = [:]
        for group in MuscleGroup.allCases {
            result[group] = nil as Int?
        }
        for workout in history {
            for wex in workout.exercises where wex.completedSetCount > 0 {
                let days = max(0, Calendar.current.dateComponents([.day], from: workout.startDate, to: now).day ?? 0)
                if let existing = result[wex.exercise.muscleGroup], let current = existing {
                    if days < current { result[wex.exercise.muscleGroup] = days }
                } else {
                    result[wex.exercise.muscleGroup] = days
                }
            }
        }
        return result
    }

    /// Completed working sets (warm-ups excluded) per muscle group over the
    /// trailing `days`. Feeds the body heatmap.
    static func muscleSetCounts(history: [Workout], days: Int = 7, asOf now: Date = Date()) -> [MuscleGroup: Int] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return [:] }
        var counts: [MuscleGroup: Int] = [:]
        for workout in history where workout.startDate >= cutoff {
            for wex in workout.exercises {
                let working = wex.sets.filter { $0.isCompleted && $0.type != .warmup }.count
                if working > 0 {
                    counts[wex.exercise.muscleGroup, default: 0] += working
                }
            }
        }
        return counts
    }

    // MARK: - Streak

    /// Consecutive calendar weeks with at least one workout, counting back from
    /// the current week (a quiet current week doesn't break the streak yet).
    static func currentStreakWeeks(history: [Workout], asOf now: Date = Date()) -> Int {
        guard !history.isEmpty else { return 0 }
        let calendar = Calendar.current
        let weekStarts = Set(history.map {
            calendar.dateInterval(of: .weekOfYear, for: $0.startDate)?.start ?? $0.startDate
        })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        var streak = 0
        if !weekStarts.contains(cursor) {
            // Current week is still in progress — start counting from last week.
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - Personal records

    /// IDs of sets that beat every earlier session's best e1RM for that exercise.
    static func prSets(in workout: Workout, history: [Workout]) -> Set<UUID> {
        var best: [String: Double] = [:]
        let earlier = history
            .filter { $0.id != workout.id && $0.startDate < workout.startDate }
        for past in earlier {
            for wex in past.exercises {
                for set in wex.sets where set.isCompleted {
                    let score = Stats.epleyOneRepMax(weight: set.weight, reps: set.reps)
                    best[wex.exercise.id] = max(best[wex.exercise.id] ?? 0, score)
                }
            }
        }

        var result: Set<UUID> = []
        for wex in workout.exercises where wex.exercise.usesWeight {
            var bar = best[wex.exercise.id] ?? 0
            for set in wex.sets where set.isCompleted {
                let score = Stats.epleyOneRepMax(weight: set.weight, reps: set.reps)
                if score > bar, score > 0 {
                    result.insert(set.id)
                    bar = score
                }
            }
        }
        return result
    }

    /// True while working out: would completing this weight×reps set a new record?
    static func wouldBePR(exerciseID: String, weight: Double, reps: Int, history: [Workout]) -> Bool {
        let score = Stats.epleyOneRepMax(weight: weight, reps: reps)
        guard score > 0 else { return false }
        var best = 0.0
        for workout in history {
            for wex in workout.exercises where wex.exercise.id == exerciseID {
                for set in wex.sets where set.isCompleted {
                    best = max(best, Stats.epleyOneRepMax(weight: set.weight, reps: set.reps))
                }
            }
        }
        return score > best
    }
}
