import SwiftUI

struct WatchRootView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.activeWorkout != nil {
                WatchSessionPager()
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
                start { store.startEmptyWorkout() }
            } label: {
                Label("Quick Start", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .listItemTint(.green)

            Section("Routines") {
                if store.templates.isEmpty {
                    Text("Routines you build on your iPhone show up here.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.templates) { template in
                    Button {
                        start { store.startWorkout(from: template) }
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

            if let last = store.history.first {
                Section("Last workout") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.title)
                            .font(.caption)
                        HStack(spacing: 8) {
                            Text(Stats.formattedDuration(last.duration))
                            if let hr = last.avgHeartRate {
                                Label("\(Int(hr))", systemImage: "heart.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("FitX")
    }

    private func start(_ begin: () -> Void) {
        begin()
        let manager = WorkoutSessionManager.shared
        manager.workoutTitle = store.activeWorkout?.title ?? "Workout"
        manager.requestAuthorization()
        manager.start()
    }
}
