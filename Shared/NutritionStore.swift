import Foundation
import Observation

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snacks: return "carrot.fill"
        }
    }
}

struct MacroTargets: Codable, Hashable {
    var calories: Double = 2200
    var protein: Double = 160
    var carbs: Double = 220
    var fat: Double = 70
}

/// One logged food. Macro values are totals for the logged amount, not per-100 g.
struct FoodEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var meal: Meal = .snacks
    var name: String
    var brand: String = ""
    var servingDescription: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
}

struct DayTotals: Hashable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    mutating func add(_ entry: FoodEntry) {
        calories += entry.calories
        protein += entry.protein
        carbs += entry.carbs
        fat += entry.fat
    }
}

@Observable
final class NutritionStore {
    private struct State: Codable {
        var entries: [FoodEntry] = []
        var targets: MacroTargets = MacroTargets()
    }

    private(set) var entries: [FoodEntry] = []
    private(set) var targets = MacroTargets()

    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("fitx-nutrition.json")
        load()
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FitX", isDirectory: true)
    }

    // MARK: - Entries

    func add(_ entry: FoodEntry) {
        entries.append(entry)
        save()
    }

    func delete(_ entry: FoodEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func entries(on day: Date) -> [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func entries(on day: Date, meal: Meal) -> [FoodEntry] {
        entries(on: day).filter { $0.meal == meal }
    }

    func totals(on day: Date) -> DayTotals {
        var totals = DayTotals()
        for entry in entries(on: day) {
            totals.add(entry)
        }
        return totals
    }

    /// Most recently logged foods, unique by name — the "log it again" list.
    var recentFoods: [FoodEntry] {
        var seen: Set<String> = []
        var result: [FoodEntry] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let key = entry.name.lowercased()
            if seen.insert(key).inserted {
                result.append(entry)
            }
            if result.count >= 25 { break }
        }
        return result
    }

    // MARK: - Targets

    func updateTargets(_ targets: MacroTargets) {
        self.targets = targets
        save()
    }

    // MARK: - Persistence

    func save() {
        let state = State(entries: entries, targets: targets)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("FitX: failed to save nutrition store: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(State.self, from: data) else { return }
        entries = state.entries
        targets = state.targets
    }
}
