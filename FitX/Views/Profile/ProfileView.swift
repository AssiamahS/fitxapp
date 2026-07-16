import SwiftUI
import Charts

struct ProfileView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var showingWeightEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        StatCard(title: "Workouts",
                                 value: "\(store.history.count)",
                                 icon: "figure.strengthtraining.traditional", tint: .blue)
                        StatCard(title: "Streak",
                                 value: "\(Insights.currentStreakWeeks(history: store.history))w",
                                 icon: "flame.fill", tint: .orange)
                        StatCard(title: "Lifetime volume",
                                 value: Stats.formattedVolume(store.history.reduce(0) { $0 + $1.totalVolume },
                                                              unit: store.settings.weightUnit),
                                 icon: "scalemass.fill", tint: .purple)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                }

                Section("Muscle heat — last 7 days") {
                    MuscleHeatmapView(counts: Insights.muscleSetCounts(history: store.history))
                        .padding(.vertical, 4)
                }

                if weeklyBuckets.contains(where: { $0.count > 0 }) {
                    Section("Workouts per week") {
                        Chart(weeklyBuckets, id: \.weekStart) { bucket in
                            BarMark(x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                                    y: .value("Workouts", bucket.count))
                                .foregroundStyle(.blue)
                        }
                        .frame(height: 140)
                        .padding(.vertical, 4)
                    }

                    Section("Volume per week (\(store.settings.weightUnit.suffix))") {
                        Chart(weeklyBuckets, id: \.weekStart) { bucket in
                            LineMark(x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                                     y: .value("Volume", store.settings.weightUnit.fromKg(bucket.volume)))
                                .foregroundStyle(.purple)
                            AreaMark(x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                                     y: .value("Volume", store.settings.weightUnit.fromKg(bucket.volume)))
                                .foregroundStyle(.purple.opacity(0.15))
                        }
                        .frame(height: 140)
                        .padding(.vertical, 4)
                    }
                }

                if !muscleSplit.isEmpty {
                    Section("Muscle split — last 30 days (sets)") {
                        Chart(muscleSplit, id: \.group) { item in
                            SectorMark(angle: .value("Sets", item.sets),
                                       innerRadius: .ratio(0.6),
                                       angularInset: 1.5)
                                .foregroundStyle(by: .value("Muscle", item.group.displayName))
                        }
                        .frame(height: 220)
                        .padding(.vertical, 4)
                    }
                }

                Section("Body weight") {
                    if let latest = store.latestBodyWeight {
                        LabeledContent("Current") {
                            Text(Stats.formattedWeight(latest.weightKg, unit: store.settings.weightUnit))
                                .bold()
                        }
                    }
                    if store.bodyWeights.count >= 2 {
                        Chart(store.bodyWeights) { entry in
                            LineMark(x: .value("Date", entry.date),
                                     y: .value("Weight", store.settings.weightUnit.fromKg(entry.weightKg)))
                                .foregroundStyle(.green)
                            PointMark(x: .value("Date", entry.date),
                                      y: .value("Weight", store.settings.weightUnit.fromKg(entry.weightKg)))
                                .foregroundStyle(.green)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 140)
                        .padding(.vertical, 4)
                    }
                    Button {
                        showingWeightEntry = true
                    } label: {
                        Label("Log Body Weight", systemImage: "plus")
                    }
                }

                settingsSection

                Section {
                    LabeledContent("Version",
                                   value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .font(.caption)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingWeightEntry) {
                BodyWeightEntrySheet()
                    .presentationDetents([.height(220)])
            }
        }
    }

    private var settingsSection: some View {
        @Bindable var storeBindable = store
        return Section("Settings") {
            Picker("Weight unit", selection: unitBinding) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.suffix).tag(unit)
                }
            }
            Picker("Default rest timer", selection: restBinding) {
                ForEach([30.0, 60, 90, 120, 150, 180, 240], id: \.self) { seconds in
                    Text(Stats.formattedDuration(seconds)).tag(seconds)
                }
            }
            LabeledContent("Heart rate") {
                Text("Tracked on Apple Watch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unitBinding: Binding<WeightUnit> {
        Binding(
            get: { store.settings.weightUnit },
            set: { newValue in
                var settings = store.settings
                settings.weightUnit = newValue
                store.updateSettings(settings)
            }
        )
    }

    private var restBinding: Binding<Double> {
        Binding(
            get: { store.settings.restSeconds },
            set: { newValue in
                var settings = store.settings
                settings.restSeconds = newValue
                store.updateSettings(settings)
            }
        )
    }

    // MARK: - Aggregations

    private struct WeekBucket {
        var weekStart: Date
        var count: Int
        var volume: Double
    }

    private var weeklyBuckets: [WeekBucket] {
        let calendar = Calendar.current
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        var buckets: [Date: WeekBucket] = [:]
        for offset in 0..<12 {
            if let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek) {
                buckets[start] = WeekBucket(weekStart: start, count: 0, volume: 0)
            }
        }
        for workout in store.history {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: workout.startDate)?.start,
                  buckets[week] != nil else { continue }
            buckets[week]?.count += 1
            buckets[week]?.volume += workout.totalVolume
        }
        return buckets.values.sorted { $0.weekStart < $1.weekStart }
    }

    private var muscleSplit: [(group: MuscleGroup, sets: Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var counts: [MuscleGroup: Int] = [:]
        for workout in store.history where workout.startDate >= cutoff {
            for wex in workout.exercises {
                counts[wex.exercise.muscleGroup, default: 0] += wex.completedSetCount
            }
        }
        return counts
            .filter { $0.value > 0 }
            .map { (group: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }
}

struct BodyWeightEntrySheet: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField(store.settings.weightUnit.suffix, value: $value, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(store.settings.weightUnit.suffix)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.logBodyWeight(store.settings.weightUnit.toKg(value))
                        dismiss()
                    }
                    .disabled(value <= 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let latest = store.latestBodyWeight {
                    value = store.settings.weightUnit.fromKg(latest.weightKg)
                }
            }
        }
    }
}
