import SwiftUI

struct ExercisePickerView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var muscleFilter: MuscleGroup?
    var onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        var all = store.allExercises
        if let muscleFilter {
            all = all.filter { $0.muscleGroup == muscleFilter }
        }
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isOn: muscleFilter == nil) { muscleFilter = nil }
                        ForEach(MuscleGroup.allCases) { group in
                            FilterChip(title: group.displayName, isOn: muscleFilter == group) {
                                muscleFilter = muscleFilter == group ? nil : group
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }

                List(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ExerciseThumbnail(exerciseID: exercise.id)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                                Text(exercise.muscleGroup.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink("New") {
                        NewExerciseView { exercise in
                            onSelect(exercise)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? Color.blue : Color.blue.opacity(0.12), in: Capsule())
                .foregroundStyle(isOn ? .white : .blue)
        }
        .buttonStyle(.plain)
    }
}

struct NewExerciseView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .other
    @State private var usesWeight = true
    var onCreate: ((Exercise) -> Void)? = nil

    var body: some View {
        Form {
            TextField("Exercise name", text: $name)
            Picker("Muscle group", selection: $muscleGroup) {
                ForEach(MuscleGroup.allCases) { group in
                    Text(group.displayName).tag(group)
                }
            }
            Toggle("Uses weight", isOn: $usesWeight)
        }
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let exercise = store.addCustomExercise(name: name,
                                                           muscleGroup: muscleGroup,
                                                           usesWeight: usesWeight)
                    onCreate?(exercise)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
