import SwiftUI

struct RootView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView {
            HomeView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            ExercisesTabView()
                .tabItem { Label("Exercises", systemImage: "figure.strengthtraining.traditional") }
        }
        .fullScreenCover(item: $store.activeWorkout) { _ in
            ActiveWorkoutView()
        }
    }
}
