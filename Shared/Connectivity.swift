import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

/// Ships finished watch workouts over to the phone. Uses transferUserInfo so
/// delivery is queued and survives the phone being unreachable mid-workout.
final class Connectivity: NSObject, WCSessionDelegate {
    static let shared = Connectivity()

    var onWorkoutReceived: ((Workout) -> Void)?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(workout: Workout) {
        guard WCSession.isSupported() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(workout) else { return }
        WCSession.default.transferUserInfo(["workout": data])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["workout"] as? Data else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let workout = try? decoder.decode(Workout.self, from: data) else { return }
        DispatchQueue.main.async {
            self.onWorkoutReceived?(workout)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
