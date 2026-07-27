import SwiftUI

@main
struct FitXApp: App {
    @State private var profiles = ProfileManager()
    @State private var session: ProfileSession?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let session {
                SignedInRoot(session: session, onSwitchProfile: {
                    session.save()
                    self.session = nil
                })
                .environment(session.store)
                .environment(session.nutrition)
                .id(session.profile.id)
            } else {
                LoginView(manager: profiles) { profile in
                    session = ProfileSession(profile: profile)
                }
                .preferredColorScheme(.dark)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                session?.save()
            }
        }
    }
}

/// Everything owned by the signed-in profile — stores built against the
/// profile's own directory. Dropping the session logs out.
final class ProfileSession {
    let profile: Profile
    let store: WorkoutStore
    let nutrition: NutritionStore

    init(profile: Profile) {
        let dir = ProfileManager.directory(for: profile)
        self.profile = profile
        self.store = WorkoutStore(directory: dir)
        self.nutrition = NutritionStore(directory: dir)
    }

    func save() {
        store.save()
        nutrition.save()
    }
}

private struct SignedInRoot: View {
    let session: ProfileSession
    var onSwitchProfile: () -> Void

    var body: some View {
        RootView(onSwitchProfile: onSwitchProfile)
            .onAppear {
                Connectivity.shared.onWorkoutReceived = { [weak session] workout in
                    session?.store.importWorkout(workout)
                }
                Connectivity.shared.onLiveMetrics = { [weak session] metrics in
                    session?.store.watchMetrics = metrics
                }
                Connectivity.shared.onLiveEnded = { [weak session] in
                    session?.store.watchMetrics = nil
                }
                Connectivity.shared.activate()
                session.store.syncTemplatesToWatch()
            }
    }
}
