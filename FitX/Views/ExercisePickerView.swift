import SwiftUI

struct ExercisePickerView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        let all = store.allExercises
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                        Text(exercise.muscleGroup.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
