import SwiftUI

struct MacroTargetsView: View {
    @Environment(NutritionStore.self) private var nutrition
    @Environment(\.dismiss) private var dismiss
    @State private var targets = MacroTargets()

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily targets") {
                    targetField("Calories (kcal)", value: $targets.calories)
                    targetField("Protein (g)", value: $targets.protein)
                    targetField("Carbs (g)", value: $targets.carbs)
                    targetField("Fat (g)", value: $targets.fat)
                }
                Section {
                    LabeledContent("From macros",
                                   value: "\(Int(targets.protein * 4 + targets.carbs * 4 + targets.fat * 9)) kcal")
                        .font(.caption)
                }
            }
            .navigationTitle("Macro Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        nutrition.updateTargets(targets)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                targets = nutrition.targets
            }
        }
    }

    private func targetField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }
}
