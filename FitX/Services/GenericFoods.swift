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

enum GenericFoods {
    static let all: [GenericFood] = {
        guard let url = Bundle.main.url(forResource: "generic-foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([GenericFood].self, from: data) else {
            return []
        }
        return decoded
    }()

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
