import SwiftUI

struct NutritionView: View {
    @Environment(NutritionStore.self) private var nutrition
    @State private var day = Date()
    @State private var addingTo: Meal?
    @State private var showingTargets = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dayNavigator
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                }

                Section {
                    MacroSummaryView(totals: nutrition.totals(on: day), targets: nutrition.targets)
                }

                if isToday {
                    Section {
                        StepsCard()
                    }
                }

                ForEach(Meal.allCases) { meal in
                    Section {
                        let entries = nutrition.entries(on: day, meal: meal)
                        ForEach(entries) { entry in
                            FoodEntryRow(entry: entry)
                        }
                        .onDelete { offsets in
                            for index in offsets where entries.indices.contains(index) {
                                nutrition.delete(entries[index])
                            }
                        }
                        Button {
                            addingTo = meal
                        } label: {
                            Label("Add Food", systemImage: "plus")
                                .font(.subheadline)
                        }
                    } header: {
                        HStack {
                            Label(meal.displayName, systemImage: meal.icon)
                            Spacer()
                            let kcal = nutrition.entries(on: day, meal: meal).reduce(0.0) { $0 + $1.calories }
                            if kcal > 0 {
                                Text("\(Int(kcal)) kcal")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Macros")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingTargets = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(item: $addingTo) { meal in
                AddFoodView(day: day, meal: meal)
            }
            .sheet(isPresented: $showingTargets) {
                MacroTargetsView()
                    .presentationDetents([.medium])
            }
            .onAppear {
                StepsProvider.shared.requestAndRefresh()
            }
        }
    }

    private var dayNavigator: some View {
        HStack {
            Button {
                day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            Spacer()
            VStack(spacing: 0) {
                Text(isToday ? "Today" : day.formatted(.dateTime.weekday(.wide)))
                    .font(.headline)
                Text(day, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
            .disabled(isToday)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
}

struct MacroSummaryView: View {
    let totals: DayTotals
    let targets: MacroTargets

    var body: some View {
        HStack(spacing: 16) {
            CalorieRing(consumed: totals.calories, target: targets.calories)
                .frame(width: 110, height: 110)
            VStack(spacing: 10) {
                MacroBar(label: "Protein", value: totals.protein, target: targets.protein, tint: .red)
                MacroBar(label: "Carbs", value: totals.carbs, target: targets.carbs, tint: .orange)
                MacroBar(label: "Fat", value: totals.fat, target: targets.fat, tint: .yellow)
            }
        }
        .padding(.vertical, 6)
    }
}

struct CalorieRing: View {
    let consumed: Double
    let target: Double

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, consumed / target)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(consumed > target ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(max(0, target - consumed)))")
                    .font(.title3.bold())
                    .monospacedDigit()
                Text("kcal left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                Spacer()
                Text("\(Int(value)) / \(Int(target)) g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: target > 0 ? min(1, value / target) : 0)
                .tint(tint)
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(entry.calories)) kcal")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                if !entry.brand.isEmpty {
                    Text(entry.brand)
                        .lineLimit(1)
                }
                if !entry.servingDescription.isEmpty {
                    Text(entry.servingDescription)
                }
                Spacer()
                Text("P \(Int(entry.protein)) · C \(Int(entry.carbs)) · F \(Int(entry.fat))")
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct StepsCard: View {
    private let steps = StepsProvider.shared

    var body: some View {
        HStack(spacing: 8) {
            StatCard(title: "Steps today",
                     value: steps.todaySteps.map { "\($0)" } ?? "—",
                     icon: "figure.walk", tint: .green)
            StatCard(title: "Active energy",
                     value: steps.todayActiveCalories.map { "\(Int($0)) kcal" } ?? "—",
                     icon: "flame.fill", tint: .orange)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
    }
}
