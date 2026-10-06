import XCTest

/// Foods must log at their real serving, not a flat 100 g.
final class ServingTests: XCTestCase {
    func testParsesLabelServingGrams() {
        XCTAssertEqual(ServingSize.grams(from: "500 g"), 500)
        XCTAssertEqual(ServingSize.grams(from: "30g"), 30)
        XCTAssertEqual(ServingSize.grams(from: "1 bar (40 g)"), 40)
        XCTAssertEqual(ServingSize.grams(from: "12.5 g"), 12.5)
        XCTAssertNil(ServingSize.grams(from: "1 cup"))
        XCTAssertNil(ServingSize.grams(from: nil))
    }

    func testUsualChipotleBowlMatchesChipotleNutrition() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FitX/Resources/generic-foods.json")
        let foods = try JSONDecoder().decode([GenericFood].self, from: Data(contentsOf: url))
        XCTAssertTrue(foods.allSatisfy { $0.servingGrams > 0 })

        let bowl = try XCTUnwrap(foods.first { $0.name == "Chipotle Barbacoa Bowl" })
        let kcal = bowl.caloriesPer100g * bowl.servingGrams / 100
        let protein = bowl.proteinPer100g * bowl.servingGrams / 100
        XCTAssertEqual(kcal, 625, accuracy: 10)
        XCTAssertEqual(protein, 47, accuracy: 2)
    }
}
