import Foundation

enum AppConfig {
    static let defaultRestSeconds: TimeInterval = 90
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves
    case core, cardio, fullBody = "full body", other

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum SetType: String, Codable, CaseIterable, Identifiable {
    case normal, warmup, failure, drop

    var id: String { rawValue }

    var marker: String? {
        switch self {
        case .normal: return nil
        case .warmup: return "W"
        case .failure: return "F"
        case .drop: return "D"
        }
    }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .warmup: return "Warm-up"
        case .failure: return "Failure"
        case .drop: return "Drop set"
        }
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var muscleGroup: MuscleGroup
    var usesWeight: Bool
    var isCustom: Bool

    init(id: String? = nil,
         name: String,
         muscleGroup: MuscleGroup,
         usesWeight: Bool = true,
         isCustom: Bool = false) {
        self.id = id ?? Exercise.slug(for: name)
        self.name = name
        self.muscleGroup = muscleGroup
        self.usesWeight = usesWeight
        self.isCustom = isCustom
    }

    static func slug(for name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }
}

struct WorkoutSet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: SetType = .normal
    var weight: Double = 0
    var reps: Int = 0
    var isCompleted: Bool = false

    var volume: Double { isCompleted ? weight * Double(reps) : 0 }
}

struct WorkoutExercise: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var exercise: Exercise
    var sets: [WorkoutSet] = []
    var notes: String = ""

    var completedVolume: Double { sets.reduce(0) { $0 + $1.volume } }
    var completedSetCount: Int { sets.filter(\.isCompleted).count }
}

struct Workout: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var startDate: Date = Date()
    var endDate: Date? = nil
    var exercises: [WorkoutExercise] = []
    var notes: String = ""

    var duration: TimeInterval { duration(asOf: Date()) }

    func duration(asOf now: Date) -> TimeInterval {
        max(0, (endDate ?? now).timeIntervalSince(startDate))
    }

    var totalVolume: Double { exercises.reduce(0) { $0 + $1.completedVolume } }
    var completedSetCount: Int { exercises.reduce(0) { $0 + $1.completedSetCount } }
}

struct TemplateExercise: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var exercise: Exercise
    var plannedSets: Int = 3
}

struct WorkoutTemplate: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var exercises: [TemplateExercise] = []

    var summary: String {
        exercises.map(\.exercise.name).joined(separator: ", ")
    }
}

enum Stats {
    /// Epley estimated one-rep max. Returns the weight itself for a single rep.
    static func epleyOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    static func formattedDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm %02ds", minutes, seconds)
    }

    static func formattedWeight(_ kg: Double) -> String {
        if kg == kg.rounded() {
            return String(format: "%.0f kg", kg)
        }
        return String(format: "%.1f kg", kg)
    }

    static func formattedVolume(_ kg: Double) -> String {
        String(format: "%.0f kg", kg)
    }
}
