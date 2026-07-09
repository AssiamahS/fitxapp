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
            NutritionView()
                .tabItem { Label("Macros", systemImage: "fork.knife") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .fullScreenCover(item: $store.activeWorkout) { _ in
            ActiveWorkoutView()
        }
        .onChange(of: store.activeWorkout) { _, workout in
            LiveActivityManager.shared.sync(workout: workout, restTimer: store.restTimer)
        }
        .onChange(of: store.restTimer.endDate) { _, _ in
            LiveActivityManager.shared.sync(workout: store.activeWorkout, restTimer: store.restTimer)
        }
    }
}
