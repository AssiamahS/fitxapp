import SwiftUI

@main
struct FitXWatchApp: App {
    @State private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .onAppear {
                    Connectivity.shared.onTemplatesReceived = { templates, custom in
                        store.replaceTemplates(templates, customExercises: custom)
                    }
                    Connectivity.shared.activate()
                    WorkoutSessionManager.shared.requestAuthorization()
                }
        }
    }
}
