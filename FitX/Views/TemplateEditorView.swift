import SwiftUI

struct TemplateEditorView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var exercises: [TemplateExercise]
    @State private var showingPicker = false
    private let existingID: UUID?

    init(template: WorkoutTemplate? = nil) {
        _name = State(initialValue: template?.name ?? "")
        _exercises = State(initialValue: template?.exercises ?? [])
        existingID = template?.id
    }

    var body: some View {
        Form {
            Section {
                TextField("Template name", text: $name)
            }
            Section("Exercises") {
                ForEach($exercises) { $planned in
                    Stepper(value: $planned.plannedSets, in: 1...10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(planned.exercise.name)
                            Text("\(planned.plannedSets) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { exercises.remove(atOffsets: $0) }

                Button {
                    showingPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
        }
        .navigationTitle(existingID == nil ? "New Template" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var template = WorkoutTemplate(name: name.isEmpty ? "Untitled" : name,
                                                   exercises: exercises)
                    if let existingID {
                        template.id = existingID
                        store.updateTemplate(template)
                    } else {
                        store.addTemplate(template)
                    }
                    dismiss()
                }
                .disabled(exercises.isEmpty)
            }
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { exercise in
                exercises.append(TemplateExercise(exercise: exercise))
            }
        }
    }
}
