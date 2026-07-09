import SwiftUI

/// Exercise library. Pushed from the Workout tab ("Library") — not a tab itself.
struct ExerciseLibraryView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var search = ""
    @State private var muscleFilter: MuscleGroup?

    private var filtered: [Exercise] {
        var all = store.allExercises
        if let muscleFilter {
            all = all.filter { $0.muscleGroup == muscleFilter }
        }
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isOn: muscleFilter == nil) { muscleFilter = nil }
                        ForEach(MuscleGroup.allCases) { group in
                            FilterChip(title: group.displayName, isOn: muscleFilter == group) {
                                muscleFilter = muscleFilter == group ? nil : group
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }

            ForEach(filtered) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    HStack(spacing: 12) {
                        ExerciseThumbnail(exerciseID: exercise.id)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(exercise.name)
                                if exercise.isCustom {
                                    Text("Custom")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(exercise.muscleGroup.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TrendBadge(insight: Insights.insight(for: exercise.id, history: store.history))
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search exercises")
        .navigationTitle("Exercise Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    NewExerciseView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
