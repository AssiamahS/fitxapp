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
