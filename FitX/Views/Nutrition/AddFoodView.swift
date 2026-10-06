import SwiftUI

struct AddFoodView: View {
    let day: Date
    let meal: Meal

    enum Tab: String, CaseIterable, Identifiable {
        case search = "Search"
        case describe = "Describe"
        case quick = "Quick Add"
        case recent = "Recent"
        var id: String { rawValue }
    }

    @Environment(NutritionStore.self) private var nutrition
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .search
    @State private var query = ""
    @State private var results: [OFFProduct] = []
    @State private var genericHits: [GenericFood] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var servingProduct: OFFProduct?
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 6)

                switch tab {
                case .search: searchTab
                case .describe: DescribeMealView(day: day, meal: meal) { dismiss() }
                case .quick: QuickAddForm(day: day, meal: meal)
                case .recent: recentTab
                }
            }
            .navigationTitle("Add to \(meal.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                }
            }
            .sheet(item: $servingProduct) { product in
                ServingSheet(product: product, day: day, meal: meal) {
                    dismiss()
                }
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showingScanner) {
                CameraScanView(day: day, meal: meal) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Search (OpenFoodFacts)

    private var searchTab: some View {
        List {
            Section {
                HStack {
                    TextField("Search foods (OpenFoodFacts)", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onSubmit { runSearch() }
                    Button("Go") { runSearch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }

            if searching {
                HStack {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()
                }
            } else if let searchError {
                Text(searchError)
                    .foregroundStyle(.secondary)
            }

            if !genericHits.isEmpty {
                Section("Common foods") {
                    ForEach(genericHits) { food in
                        productRow(OFFProduct(generic: food))
                    }
                }
            }

            if !results.isEmpty {
                Section(genericHits.isEmpty ? "" : "Products") {
                    ForEach(results) { product in
                        productRow(product)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func productRow(_ product: OFFProduct) -> some View {
        Button {
            servingProduct = product
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack {
                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(caloriesLabel(product))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// What one serving logs ("625 kcal · 46 g protein"), falling back to the
    /// per-100 g rate when the label has no gram weight.
    private func caloriesLabel(_ product: OFFProduct) -> String {
        guard let grams = ServingSize.grams(from: product.servingSize) else {
            return "\(Int(product.caloriesPer100g)) kcal · \(Int(product.proteinPer100g)) g protein / 100 g"
        }
        let protein = Int((product.proteinPer100g * grams / 100).rounded())
        return "\(Int((product.caloriesPer100g * grams / 100).rounded())) kcal · \(protein) g protein"
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        searchTask?.cancel()
        searching = true
        searchError = nil
        results = []
        // The curated table answers instantly and offline; products fill in below.
        genericHits = GenericFoods.search(term)
        searchTask = Task {
            do {
                let found = try await OpenFoodFactsClient.search(term)
                guard !Task.isCancelled else { return }
                results = found
                if found.isEmpty && genericHits.isEmpty {
                    searchError = "Nothing found — try the Quick Add tab."
                }
            } catch {
                guard !Task.isCancelled else { return }
                if genericHits.isEmpty {
                    searchError = "Search failed. Check your connection and try again."
                }
            }
            searching = false
        }
    }

    // MARK: - Recent

    private var recentTab: some View {
        List {
            if nutrition.recentFoods.isEmpty {
                Text("Foods you log show up here for quick re-adding.")
                    .foregroundStyle(.secondary)
            }
            ForEach(nutrition.recentFoods) { food in
                Button {
                    var entry = food
                    entry.id = UUID()
                    entry.date = day
                    entry.meal = meal
                    nutrition.add(entry)
                    dismiss()
                } label: {
                    FoodEntryRow(entry: food)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Serving picker for an OpenFoodFacts hit

struct ServingSheet: View {
    let product: OFFProduct
    let day: Date
    let meal: Meal
    var onAdded: () -> Void

    @Environment(NutritionStore.self) private var nutrition
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double
    /// Gram weight of one label serving (a bottle, a bowl), nil when the
    /// label has none and the amount is entered in grams only.
    private let servingGrams: Double?

    init(product: OFFProduct, day: Date, meal: Meal, onAdded: @escaping () -> Void) {
        self.product = product
        self.day = day
        self.meal = meal
        self.onAdded = onAdded
        servingGrams = ServingSize.grams(from: product.servingSize)
        // Start at one label serving instead of a flat 100 g.
        _grams = State(initialValue: servingGrams ?? 100)
    }

    private var servings: Binding<Double> {
        Binding(
            get: { grams / (servingGrams ?? 100) },
            set: { grams = max(0, $0) * (servingGrams ?? 100) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        if !product.brand.isEmpty {
                            Text(product.brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(scaled(product.caloriesPer100g).rounded()))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("kcal")
                            .foregroundStyle(.secondary)
                        Spacer()
                        macroColumn("Protein", product.proteinPer100g, .red)
                        macroColumn("Carbs", product.carbsPer100g, .orange)
                        macroColumn("Fat", product.fatPer100g, .yellow)
                    }
                }

                Section {
                    if let servingGrams {
                        Stepper(value: servings, in: 0.25...20, step: 0.5) {
                            HStack {
                                Text("Servings")
                                Spacer()
                                Text(servings.wrappedValue, format: .number.precision(.fractionLength(0...2)))
                                    .monospacedDigit()
                            }
                        }
                        LabeledContent("1 serving", value: product.servingSize ?? "\(Int(servingGrams)) g")
                    }
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("g", value: $grams, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Serving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        nutrition.add(FoodEntry(date: day,
                                                meal: meal,
                                                name: product.name,
                                                brand: product.brand,
                                                servingDescription: servingDescription,
                                                calories: scaled(product.caloriesPer100g),
                                                protein: scaled(product.proteinPer100g),
                                                carbs: scaled(product.carbsPer100g),
                                                fat: scaled(product.fatPer100g)))
                        dismiss()
                        onAdded()
                    }
                    .disabled(grams <= 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }

    private func macroColumn(_ label: String, _ per100: Double, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(scaled(per100).rounded())) g")
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(tint)
        }
        .frame(minWidth: 52)
    }

    /// "1 serving" / "2 servings" when a label serving exists, grams otherwise.
    private var servingDescription: String {
        guard servingGrams != nil else { return "\(Int(grams)) g" }
        let count = servings.wrappedValue
        let number = count.formatted(.number.precision(.fractionLength(0...2)))
        return "\(number) serving\(count == 1 ? "" : "s") · \(Int(grams)) g"
    }

    private func scaled(_ per100: Double) -> Double {
        per100 * grams / 100
    }
}

// MARK: - Manual entry

struct QuickAddForm: View {
    let day: Date
    let meal: Meal

    @Environment(NutritionStore.self) private var nutrition
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0

    var body: some View {
        Form {
            TextField("Food name", text: $name)
            macroField("Calories (kcal)", value: $calories)
            macroField("Protein (g)", value: $protein)
            macroField("Carbs (g)", value: $carbs)
            macroField("Fat (g)", value: $fat)

            Button {
                nutrition.add(FoodEntry(date: day,
                                        meal: meal,
                                        name: name.trimmingCharacters(in: .whitespaces),
                                        calories: calories,
                                        protein: protein,
                                        carbs: carbs,
                                        fat: fat))
                dismiss()
            } label: {
                Label("Add Food", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || calories <= 0)
        }
    }

    private func macroField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}
