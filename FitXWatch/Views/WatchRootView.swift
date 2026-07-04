import SwiftUI

struct WatchRootView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.activeWorkout != nil {
                WatchWorkoutView()
            } else {
                WatchStartView()
            }
        }
    }
}

struct WatchStartView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        List {
            Button {
                store.startEmptyWorkout()
            } label: {
                Label("Quick Start", systemImage: "plus.circle.fill")
                    .font(.headline)
            }

            Section("Templates") {
                ForEach(store.templates) { template in
                    Button {
                        store.startWorkout(from: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                            Text("\(template.exercises.count) exercises")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("FitX")
    }
}
