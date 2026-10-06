import Foundation

/// Per-100 g macro estimates for foods the camera classifier and the meal
/// text parser can name. Values are typical-nutrition approximations,
/// flagged as estimates in the UI.
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

enum ServingSize {
    /// Grams in a label serving string ("500 g", "1 bar (40 g)"), nil when the
    /// label has no weight. Drinks list ml ("14 fl oz (414 ml)"), taken as ~1 g/ml.
    static func grams(from label: String?) -> Double? {
        guard let label,
              let match = label.firstMatch(of: #/(\d+(?:\.\d+)?)\s*(?:g|ml)\b/#),
              let value = Double(match.1), value > 0 else { return nil }
        return value
    }
}
