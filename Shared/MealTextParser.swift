import Foundation

/// Turns a plain-English meal description — "sausage egg and cheese",
/// "2 eggs, bacon and toast" — into loggable foods from the generic table.
/// Longest match wins, so a compound like "sausage egg and cheese" resolves
/// to the sandwich before falling apart into sausage + eggs + cheese.
enum MealTextParser {
    struct ParsedItem: Identifiable, Hashable {
        var id: String { food.name }
        var food: GenericFood
        var quantity: Double

        var grams: Double { food.servingGrams * quantity }
        var calories: Double { food.caloriesPer100g * grams / 100 }
        var protein: Double { food.proteinPer100g * grams / 100 }
        var carbs: Double { food.carbsPer100g * grams / 100 }
        var fat: Double { food.fatPer100g * grams / 100 }
    }

    struct ParseResult: Hashable {
        var items: [ParsedItem] = []
        var unmatched: [String] = []
    }

    static func parse(_ text: String, foods: [GenericFood]) -> ParseResult {
        var result = ParseResult()
        for segment in segments(of: text) {
            let (quantity, phrase) = leadingQuantity(segment)
            if let food = bestMatch(phrase, foods: foods) {
                append(food, quantity: quantity, to: &result)
            } else {
                // The whole phrase didn't name one food — try each "and" part.
                let parts = phrase.components(separatedBy: " and ")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                guard parts.count > 1 else {
                    result.unmatched.append(phrase)
                    continue
                }
                for part in parts {
                    let (partQuantity, partPhrase) = leadingQuantity(part)
                    if let food = bestMatch(partPhrase, foods: foods) {
                        append(food, quantity: partQuantity * quantity, to: &result)
                    } else {
                        result.unmatched.append(partPhrase)
                    }
                }
            }
        }
        return result
    }

    private static func append(_ food: GenericFood, quantity: Double, to result: inout ParseResult) {
        if let index = result.items.firstIndex(where: { $0.food.name == food.name }) {
            result.items[index].quantity += quantity
        } else {
            result.items.append(ParsedItem(food: food, quantity: quantity))
        }
    }

    /// Comma/plus/"with" separated chunks, lowercased and cleaned of filler
    /// like "we did" / "I had" / "a" / "some".
    static func segments(of text: String) -> [String] {
        var normalized = text.lowercased()
        for separator in [" with ", " plus ", "+", ";"] {
            normalized = normalized.replacingOccurrences(of: separator, with: ",")
        }
        let filler = ["we did", "we had", "i had", "i ate", "just ate", "had a", "had",
                      "a ", "an ", "some ", "the "]
        return normalized.components(separatedBy: ",")
            .map { segment in
                var cleaned = segment.trimmingCharacters(in: .whitespaces)
                for phrase in filler where cleaned.hasPrefix(phrase) {
                    cleaned = String(cleaned.dropFirst(phrase.count))
                        .trimmingCharacters(in: .whitespaces)
                }
                return cleaned
            }
            .filter { !$0.isEmpty }
    }

    /// "2 eggs" -> (2, "eggs"); "eggs" -> (1, "eggs").
    static func leadingQuantity(_ phrase: String) -> (Double, String) {
        let parts = phrase.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, let number = Double(parts[0]), number > 0, number <= 20 else {
            return (1, phrase)
        }
        return (number, String(parts[1]).trimmingCharacters(in: .whitespaces))
    }

    /// Exact name/synonym match first, then prefix, then containment — and the
    /// longest matched name wins so compounds beat their ingredients.
    static func bestMatch(_ phrase: String, foods: [GenericFood]) -> GenericFood? {
        let needle = phrase.trimmingCharacters(in: .whitespaces)
        guard needle.count >= 2 else { return nil }

        func candidates(_ tier: (String) -> Bool) -> GenericFood? {
            foods
                .compactMap { food -> (GenericFood, Int)? in
                    let names = [food.name.lowercased()] + food.synonyms
                    let hits = names.filter(tier)
                    guard let longest = hits.map(\.count).max() else { return nil }
                    return (food, longest)
                }
                .max { $0.1 < $1.1 }?.0
        }

        if let exact = candidates({ $0 == needle }) { return exact }
        // A name buried in the phrase only counts when it covers most of it —
        // otherwise "bacon and toast" would collapse to just bacon instead of
        // being split apart by the caller.
        let coverage = needle.count * 2 / 3
        if let contained = candidates({ needle.contains($0) && $0.count >= max(4, coverage) }) {
            return contained
        }
        if let prefix = candidates({ $0.hasPrefix(needle) }) { return prefix }
        return candidates({ $0.contains(needle) })
    }
}
