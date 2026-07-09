import SwiftUI

/// What goes on each side of the bar for a target weight — Strong-style.
struct PlateCalculatorView: View {
    @State var targetKg: Double
    let unit: WeightUnit
    @State private var barKg: Double = 20

    private static let kgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    private static let lbPlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField(unit.suffix, value: targetBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(unit.suffix)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Bar", selection: $barKg) {
                        ForEach(bars, id: \.self) { bar in
                            Text(Stats.formattedWeight(bar, unit: unit)).tag(bar)
                        }
                    }
                }

                Section("Per side") {
                    if perSide.isEmpty {
                        Text(targetKg <= barKg ? "Empty bar covers it." : "Can't build that weight exactly.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 6) {
                            ForEach(Array(perSide.enumerated()), id: \.offset) { _, plate in
                                Text(plateLabel(plate))
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                                    .background(plateColor(plate).opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(plateColor(plate))
                            }
                        }
                        LabeledContent("Loaded", value: Stats.formattedWeight(loadedKg, unit: unit))
                        if abs(loadedKg - targetKg) > 0.01 {
                            LabeledContent("Off by", value: Stats.formattedWeight(targetKg - loadedKg, unit: unit))
                        }
                    }
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var bars: [Double] {
        unit == .kg ? [20, 15, 10] : [WeightUnit.lb.toKg(45), WeightUnit.lb.toKg(35), WeightUnit.lb.toKg(15)]
    }

    /// Greedy fill, in display units per plate but computed in kg.
    private var perSide: [Double] {
        let plates = unit == .kg ? Self.kgPlates : Self.lbPlates.map { WeightUnit.lb.toKg($0) }
        var remaining = (targetKg - barKg) / 2
        var result: [Double] = []
        for plate in plates {
            while remaining >= plate - 0.001 {
                result.append(plate)
                remaining -= plate
            }
        }
        return result
    }

    private var loadedKg: Double {
        barKg + perSide.reduce(0, +) * 2
    }

    private var targetBinding: Binding<Double> {
        Binding(
            get: { (unit.fromKg(targetKg) * 10).rounded() / 10 },
            set: { targetKg = unit.toKg($0) }
        )
    }

    private func plateLabel(_ kg: Double) -> String {
        let value = unit.fromKg(kg)
        return value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }

    private func plateColor(_ kg: Double) -> Color {
        switch unit.fromKg(kg) {
        case 45...: return .red
        case 20...: return .blue
        case 10...: return .green
        case 5...: return .orange
        default: return .gray
        }
    }
}
