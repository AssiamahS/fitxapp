import SwiftUI

@main
struct FitXApp: App {
    @State private var store = WorkoutStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onAppear {
                    Connectivity.shared.onWorkoutReceived = { workout in
                        store.importWorkout(workout)
                    }
                    Connectivity.shared.activate()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { store.save() }
        }
    }
}
