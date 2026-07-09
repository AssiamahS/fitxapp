import SwiftUI

@main
struct FitXApp: App {
    @State private var store = WorkoutStore()
    @State private var nutrition = NutritionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(nutrition)
                .onAppear {
                    Connectivity.shared.onWorkoutReceived = { workout in
                        store.importWorkout(workout)
                    }
                    Connectivity.shared.onLiveMetrics = { metrics in
                        store.watchMetrics = metrics
                    }
                    Connectivity.shared.onLiveEnded = {
                        store.watchMetrics = nil
                    }
                    Connectivity.shared.activate()
                    store.syncTemplatesToWatch()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                store.save()
                nutrition.save()
            }
        }
    }
}
