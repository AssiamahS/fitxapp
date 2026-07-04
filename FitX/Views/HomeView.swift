import SwiftUI

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.startEmptyWorkout()
                    } label: {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                Section("Templates") {
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
                        Label("New Template", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("FitX")
        }
    }
}
