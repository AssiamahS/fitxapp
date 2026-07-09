import SwiftUI

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store

    private var coachMessages: [CoachMessage] {
        Insights.coachMessages(history: store.history, exercises: store.allExercises)
    }

    private var thisWeek: [Workout] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return store.history.filter { week.contains($0.startDate) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let metrics = store.watchMetrics {
                    WatchLiveBanner(metrics: metrics)
                }

                Section {
                    HStack(spacing: 8) {
                        StatCard(title: "Streak",
                                 value: "\(Insights.currentStreakWeeks(history: store.history))w",
                                 icon: "flame.fill", tint: .orange)
                        StatCard(title: "This week",
                                 value: "\(thisWeek.count)",
                                 icon: "calendar", tint: .blue)
                        StatCard(title: "Volume",
                                 value: Stats.formattedVolume(thisWeek.reduce(0) { $0 + $1.totalVolume },
                                                              unit: store.settings.weightUnit),
                                 icon: "scalemass.fill", tint: .purple)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                }

                if !coachMessages.isEmpty {
                    Section("Coach") {
                        ForEach(coachMessages) { message in
                            if let exercise = store.allExercises.first(where: { $0.id == message.exerciseID }) {
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    CoachCard(message: message)
                                }
                            } else {
                                CoachCard(message: message)
                            }
                        }
                    }
                }

                Section("Muscle recovery") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            let freshness = Insights.muscleFreshness(history: store.history)
                            ForEach(MuscleGroup.allCases.filter { $0 != .cardio && $0 != .other && $0 != .fullBody }) { group in
                                FreshnessChip(group: group, daysSince: freshness[group] ?? nil)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }

                Section {
                    Button {
                        store.startEmptyWorkout()
                    } label: {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                Section("Routines") {
                    ForEach(store.templates) { template in
                        NavigationLink {
                            TemplateEditorView(template: template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.headline)
                                    Text(template.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button("Start") {
                                    store.startWorkout(from: template)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                    .onDelete { store.deleteTemplates(at: $0) }

                    NavigationLink {
                        TemplateEditorView()
                    } label: {
                        Label("New Routine", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("FitX")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Label("Library", systemImage: "books.vertical")
                    }
                }
            }
        }
    }
}

/// "There's a workout running on your wrist" — live HR mirrored from the watch.
struct WatchLiveBanner: View {
    let metrics: WatchLiveMetrics

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if metrics.isFresh(asOf: context.date) {
                HStack(spacing: 12) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metrics.title)
                            .font(.subheadline.bold())
                        Text(Stats.formattedDuration(metrics.elapsed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    if metrics.heartRate > 0 {
                        Label("\(Int(metrics.heartRate))", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.headline)
                            .monospacedDigit()
                    }
                    if metrics.activeCalories > 0 {
                        Label("\(Int(metrics.activeCalories))", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
