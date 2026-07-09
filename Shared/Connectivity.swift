import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

/// Phone ⇄ watch bridge.
/// - Finished watch workouts ride transferUserInfo (queued, survives unreachability).
/// - Routines + custom exercises ride updateApplicationContext (latest wins,
///   delivered even if the watch app is closed).
/// - Live heart rate / calories ride sendMessage (instant, dropped when unreachable —
///   fine, it's a live ticker).
final class Connectivity: NSObject, WCSessionDelegate {
    static let shared = Connectivity()

    var onWorkoutReceived: ((Workout) -> Void)?
    var onTemplatesReceived: (([WorkoutTemplate], [Exercise]) -> Void)?
    var onLiveMetrics: ((WatchLiveMetrics) -> Void)?
    var onLiveEnded: (() -> Void)?

    private var pendingContext: [String: Any]?

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Finished workouts (watch → phone)

    func send(workout: Workout) {
        guard WCSession.isSupported() else { return }
        guard let data = try? Self.encoder.encode(workout) else { return }
        WCSession.default.transferUserInfo(["workout": data])
    }

    // MARK: - Routine sync (phone → watch)

    func pushTemplates(_ templates: [WorkoutTemplate], customExercises: [Exercise]) {
        guard WCSession.isSupported() else { return }
        guard let templateData = try? Self.encoder.encode(templates),
              let exerciseData = try? Self.encoder.encode(customExercises) else { return }
        let context: [String: Any] = ["templates": templateData, "customExercises": exerciseData]
        let session = WCSession.default
        if session.activationState == .activated {
            try? session.updateApplicationContext(context)
        } else {
            pendingContext = context
        }
    }

    private func handleContext(_ context: [String: Any]) {
        guard let templateData = context["templates"] as? Data,
              let templates = try? Self.decoder.decode([WorkoutTemplate].self, from: templateData) else { return }
        let custom = (context["customExercises"] as? Data)
            .flatMap { try? Self.decoder.decode([Exercise].self, from: $0) } ?? []
        DispatchQueue.main.async {
            self.onTemplatesReceived?(templates, custom)
        }
    }

    // MARK: - Live metrics (watch → phone)

    func sendLiveMetrics(heartRate: Double, activeCalories: Double, elapsed: TimeInterval, title: String) {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["live": true,
                                       "hr": heartRate,
                                       "kcal": activeCalories,
                                       "elapsed": elapsed,
                                       "title": title],
                                      replyHandler: nil,
                                      errorHandler: nil)
    }

    func sendLiveEnded() {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["liveEnd": true], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated, let context = pendingContext {
            pendingContext = nil
            try? session.updateApplicationContext(context)
        }
        #if os(watchOS)
        // Context may have arrived while the watch app was closed.
        if !session.receivedApplicationContext.isEmpty {
            handleContext(session.receivedApplicationContext)
        }
        #endif
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["workout"] as? Data,
              let workout = try? Self.decoder.decode(Workout.self, from: data) else { return }
        DispatchQueue.main.async {
            self.onWorkoutReceived?(workout)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleContext(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["liveEnd"] as? Bool == true {
            DispatchQueue.main.async {
                self.onLiveEnded?()
            }
            return
        }
        guard message["live"] as? Bool == true else { return }
        let metrics = WatchLiveMetrics(heartRate: message["hr"] as? Double ?? 0,
                                       activeCalories: message["kcal"] as? Double ?? 0,
                                       elapsed: message["elapsed"] as? Double ?? 0,
                                       title: message["title"] as? String ?? "Workout",
                                       updatedAt: Date())
        DispatchQueue.main.async {
            self.onLiveMetrics?(metrics)
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
