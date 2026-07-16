import Foundation

/// Per-100 g macro estimates for foods the camera classifier can name.
/// Values are typical-nutrition approximations, flagged as estimates in the UI.
struct GenericFood: Decodable, Identifiable, Hashable {
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let servingGrams: Double
    let synonyms: [String]

    var id: String { name }
}

extension OFFProduct {
    /// Present a generic-table food through the same serving flow as a product hit.
    init(generic food: GenericFood) {
        self.init(code: "generic-\(food.name)",
                  name: food.name,
                  brand: "Typical values",
                  caloriesPer100g: food.caloriesPer100g,
                  proteinPer100g: food.proteinPer100g,
                  carbsPer100g: food.carbsPer100g,
                  fatPer100g: food.fatPer100g,
                  servingSize: "\(Int(food.servingGrams)) g")
    }
}

enum GenericFoods {
    static let all: [GenericFood] = {
        guard let url = Bundle.main.url(forResource: "generic-foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([GenericFood].self, from: data) else {
            return []
        }
        return decoded
    }()

    /// Ranked text search for the food search tab: exact > prefix > contains.
    static func search(_ query: String) -> [GenericFood] {
        let needle = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard needle.count >= 2 else { return [] }
        func rank(_ food: GenericFood) -> Int? {
            let names = [food.name.lowercased()] + food.synonyms
            if names.contains(needle) { return 0 }
            if names.contains(where: { $0.hasPrefix(needle) }) { return 1 }
            if names.contains(where: { $0.contains(needle) }) { return 2 }
            return nil
        }
        return all.compactMap { food in rank(food).map { (food, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// Match a Vision classification identifier (e.g. "cheeseburger", "banana")
    /// against the table.
    static func match(_ identifier: String) -> GenericFood? {
        let needle = identifier.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return all.first { food in
            food.name.lowercased() == needle
                || food.synonyms.contains(where: { $0 == needle })
        } ?? all.first { food in
            needle.contains(food.name.lowercased())
                || food.synonyms.contains(where: { needle.contains($0) })
        }
    }
}
