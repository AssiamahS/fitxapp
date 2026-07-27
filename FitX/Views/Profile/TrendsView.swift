import SwiftUI
import Charts

/// The "so what" screen: verdict cards plus the graphs behind them — weight
/// actual vs predicted, calories eaten vs estimated burn, strength index.
struct TrendsView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(NutritionStore.self) private var nutrition

    var body: some View {
        List {
            verdictSection
            burnSection
            weightSection
            calorieSection
            strengthSection
        }
        .navigationTitle("Trends")
    }

    // MARK: - Verdicts

    private var verdicts: [EnergyModel.Verdict] {
        EnergyModel.verdicts(history: store.history,
                             entries: nutrition.entries,
                             weights: store.bodyWeights,
                             unit: store.settings.weightUnit)
    }

    @ViewBuilder
    private var verdictSection: some View {
        let cards = verdicts
        if cards.isEmpty {
            Section {
                Text("Log workouts, food and body weight for a couple of weeks and FitX starts calling your trends — strength, weight, fat and burn.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("The verdicts") {
                ForEach(cards) { verdict in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: verdict.direction))
                            .foregroundStyle(color(for: verdict.direction))
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verdict.title)
                                .font(.subheadline.bold())
                            Text(verdict.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func icon(for direction: EnergyModel.Verdict.Direction) -> String {
        switch direction {
        case .up: return "arrow.up.right.circle.fill"
        case .down: return "arrow.down.right.circle.fill"
        case .flat: return "equal.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for direction: EnergyModel.Verdict.Direction) -> Color {
        switch direction {
        case .up: return .green
        case .down: return .teal
        case .flat: return .secondary
        case .warning: return .orange
        }
    }

    // MARK: - Burn

    @ViewBuilder
    private var burnSection: some View {
        if let estimate = EnergyModel.estimateTDEE(entries: nutrition.entries,
                                                   weights: store.bodyWeights) {
            Section("Your daily burn") {
                LabeledContent(estimate.isAdaptive ? "Measured burn (TDEE)" : "Estimated burn (TDEE)") {
                    Text("\(Int(estimate.tdee)) kcal")
                        .bold()
                        .monospacedDigit()
                }
                if estimate.avgIntake > 0 {
                    LabeledContent("Average eaten") {
                        Text("\(Int(estimate.avgIntake)) kcal")
                            .monospacedDigit()
                    }
                }
                Text(estimate.isAdaptive
                     ? "Computed from \(estimate.loggedDays) logged days against your actual weight change — this is what your body really burns."
                     : "Rough estimate from body weight. Log food daily and weigh in weekly to get your measured number.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Weight: actual vs predicted

    @ViewBuilder
    private var weightSection: some View {
        let unit = store.settings.weightUnit
        let actual = store.bodyWeights
        if actual.count >= 2 {
            Section("Weight — actual vs predicted (\(unit.suffix))") {
                Chart {
                    ForEach(actual) { entry in
                        LineMark(x: .value("Date", entry.date),
                                 y: .value("Weight", unit.fromKg(entry.weightKg)),
                                 series: .value("Series", "Actual"))
                            .foregroundStyle(.green)
                        PointMark(x: .value("Date", entry.date),
                                  y: .value("Weight", unit.fromKg(entry.weightKg)))
                            .foregroundStyle(.green)
                    }
                    ForEach(projection, id: \.date) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value("Weight", unit.fromKg(point.weightKg)),
                                 series: .value("Series", "Predicted"))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                .padding(.vertical, 4)
                if let last = projection.last {
                    Text("Keep eating like the last month and you'll weigh about \(Stats.formattedWeight(last.weightKg, unit: unit)) in 8 weeks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var projection: [EnergyModel.WeightPoint] {
        guard let latest = store.latestBodyWeight,
              let estimate = EnergyModel.estimateTDEE(entries: nutrition.entries,
                                                      weights: store.bodyWeights),
              estimate.isAdaptive else { return [] }
        return EnergyModel.projectedWeights(from: latest.weightKg,
                                            avgIntake: estimate.avgIntake,
                                            tdee: estimate.tdee)
    }

    // MARK: - Calories in vs burn

    @ViewBuilder
    private var calorieSection: some View {
        let days = intakeDays
        if !days.isEmpty {
            Section("Calories — last 14 days") {
                Chart {
                    ForEach(days, id: \.day) { item in
                        BarMark(x: .value("Day", item.day, unit: .day),
                                y: .value("Calories", item.calories))
                            .foregroundStyle(.blue.opacity(0.75))
                    }
                    if let estimate = EnergyModel.estimateTDEE(entries: nutrition.entries,
                                                               weights: store.bodyWeights) {
                        RuleMark(y: .value("Burn", estimate.tdee))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("burn \(Int(estimate.tdee))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                }
                .frame(height: 160)
                .padding(.vertical, 4)
            }
        }
    }

    private var intakeDays: [(day: Date, calories: Double)] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) else { return [] }
        return EnergyModel.dailyIntake(entries: nutrition.entries)
            .filter { $0.key >= calendar.startOfDay(for: cutoff) }
            .map { (day: $0.key, calories: $0.value) }
            .sorted { $0.day < $1.day }
    }

    // MARK: - Strength index

    @ViewBuilder
    private var strengthSection: some View {
        let index = EnergyModel.strengthIndex(history: store.history)
        if index.count >= 2 {
            Section("Strength index (start = 100)") {
                Chart(index, id: \.weekStart) { point in
                    LineMark(x: .value("Week", point.weekStart, unit: .weekOfYear),
                             y: .value("Index", point.value))
                        .foregroundStyle(.purple)
                    PointMark(x: .value("Week", point.weekStart, unit: .weekOfYear),
                              y: .value("Index", point.value))
                        .foregroundStyle(.purple)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                .padding(.vertical, 4)
                Text("Average of your best set (estimated 1RM) across every lift, relative to where each one started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
