import SwiftUI

/// Type what you ate in plain English — "sausage egg and cheese", "2 eggs,
/// bacon and toast" — and log the whole meal in one tap.
struct DescribeMealView: View {
    let day: Date
    let meal: Meal
    var onLogged: () -> Void

    @Environment(NutritionStore.self) private var nutrition
    @State private var text = ""
    @State private var result = MealTextParser.ParseResult()
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                TextField("What did you eat? e.g. sausage egg and cheese",
                          text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .onChange(of: text) { _, newValue in
                        result = MealTextParser.parse(newValue, foods: GenericFoods.all)
                    }
            } footer: {
                Text("Separate foods with commas or “and”. Start with a number for quantity — “2 eggs”.")
            }

            if !result.items.isEmpty {
                Section("Found") {
                    ForEach(result.items) { item in
                        itemRow(item)
                    }
                }

                Section {
                    Button {
                        logAll()
                    } label: {
                        HStack {
                            Label("Log \(result.items.count) food\(result.items.count == 1 ? "" : "s")",
                                  systemImage: "checkmark.circle.fill")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(totalCalories)) kcal")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !result.unmatched.isEmpty {
                Section("Not recognized") {
                    ForEach(result.unmatched, id: \.self) { phrase in
                        Text("“\(phrase)” — try the Search tab for this one")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .onAppear { focused = true }
    }

    private var totalCalories: Double {
        result.items.reduce(0) { $0 + $1.calories }
    }

    private func itemRow(_ item: MealTextParser.ParsedItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.food.name)
                Spacer()
                Stepper(value: quantityBinding(for: item), in: 0.5...20, step: 0.5) {
                    Text(quantityLabel(item.quantity))
                        .monospacedDigit()
                        .font(.subheadline)
                }
                .fixedSize()
            }
            Text(macroSummary(item))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func macroSummary(_ item: MealTextParser.ParsedItem) -> String {
        String(format: "%.0f kcal · P %.0f · C %.0f · F %.0f · %.0f g",
               item.calories, item.protein, item.carbs, item.fat, item.grams)
    }

    private func quantityLabel(_ quantity: Double) -> String {
        quantity == quantity.rounded()
            ? "×\(Int(quantity))"
            : String(format: "×%.1f", quantity)
    }

    private func quantityBinding(for item: MealTextParser.ParsedItem) -> Binding<Double> {
        Binding(
            get: {
                result.items.first(where: { $0.id == item.id })?.quantity ?? item.quantity
            },
            set: { newValue in
                if let index = result.items.firstIndex(where: { $0.id == item.id }) {
                    result.items[index].quantity = newValue
                }
            }
        )
    }

    private func logAll() {
        for item in result.items {
            nutrition.add(FoodEntry(date: day,
                                    meal: meal,
                                    name: item.food.name,
                                    brand: "Typical values",
                                    servingDescription: "\(Int(item.grams)) g",
                                    calories: item.calories,
                                    protein: item.protein,
                                    carbs: item.carbs,
                                    fat: item.fat))
        }
        onLogged()
    }
}
