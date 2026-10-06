import Foundation

struct OFFProduct: Identifiable, Hashable {
    var id: String { code }
    var code: String
    var name: String
    var brand: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var servingSize: String?
}

/// Thin client for the OpenFoodFacts public API. Parsed with JSONSerialization
/// because the nutriments payload mixes numbers and strings per product.
enum OpenFoodFactsClient {
    enum ClientError: Error {
        case badResponse
    }

    private static let fields = "code,product_name,brands,nutriments,serving_size,quantity"

    // OpenFoodFacts blocks/throttles default CFNetwork agents; they require
    // an identifying User-Agent from API consumers.
    private static let userAgent = "FitX/2.0 (https://github.com/AssiamahS/fitxapp)"

    // Country subdomain scopes text search to locally sold products, which
    // keeps generic terms ("pizza") from returning far-market results.
    private static var searchHost: String {
        Locale.current.region?.identifier == "US" ? "us.openfoodfacts.org" : "world.openfoodfacts.org"
    }

    /// Classic search first (country-scoped); the classic servers 503 under
    /// load, so fall back to the search-a-licious engine over the same data.
    static func search(_ query: String) async throws -> [OFFProduct] {
        do {
            return try await classicSearch(query)
        } catch {
            return try await searchalicious(query)
        }
    }

    private static func classicSearch(_ query: String) async throws -> [OFFProduct] {
        var components = URLComponents(string: "https://\(searchHost)/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "fields", value: fields),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]] else {
            throw ClientError.badResponse
        }
        return products.compactMap(product(from:))
    }

    private static func searchalicious(_ query: String) async throws -> [OFFProduct] {
        var components = URLComponents(string: "https://search.openfoodfacts.org/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: fields),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = json["hits"] as? [[String: Any]] else {
            throw ClientError.badResponse
        }
        return hits.compactMap(product(from:))
    }

    static func product(barcode: String) async throws -> OFFProduct? {
        let sanitized = barcode.filter(\.isNumber)
        guard !sanitized.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(sanitized).json?fields=\(fields)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["product"] as? [String: Any] else {
            return nil
        }
        return product(from: raw)
    }

    private static func product(from raw: [String: Any]) -> OFFProduct? {
        guard let code = raw["code"] as? String else { return nil }
        let name = (raw["product_name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { return nil }
        let nutriments = raw["nutriments"] as? [String: Any] ?? [:]
        let kcal = number(nutriments["energy-kcal_100g"])
        // Products with no calorie data are useless for macro logging.
        guard kcal > 0 else { return nil }
        // Classic API sends brands as "A,B"; search-a-licious as ["A", "B"].
        let brand = (raw["brands"] as? String)
            ?? (raw["brands"] as? [String])?.joined(separator: ", ")
            ?? ""
        return OFFProduct(code: code,
                          name: name,
                          brand: brand,
                          caloriesPer100g: kcal,
                          proteinPer100g: number(nutriments["proteins_100g"]),
                          carbsPer100g: number(nutriments["carbohydrates_100g"]),
                          fatPer100g: number(nutriments["fat_100g"]),
                          servingSize: servingSize(from: raw))
    }

    /// Label serving, else the package size for single-bottle drinks
    /// ("414 ml") — many entries skip serving_size, and logging a 14 oz
    /// shake as 100 g undercounts it 4x.
    private static func servingSize(from raw: [String: Any]) -> String? {
        if let serving = raw["serving_size"] as? String, !serving.isEmpty { return serving }
        guard let quantity = raw["quantity"] as? String,
              quantity.lowercased().contains("ml"),
              let ml = ServingSize.grams(from: quantity), ml <= 750 else { return nil }
        return "\(Int(ml)) ml"
    }

    private static func number(_ value: Any?) -> Double {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) ?? 0 }
        return 0
    }
}
