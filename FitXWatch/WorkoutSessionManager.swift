import Foundation
import HealthKit
import Observation

/// Runs the HealthKit workout session behind a watch workout: keeps the app
/// alive in the background, streams heart rate + active calories from the
/// sensors, and saves the workout to Health on finish.
@Observable
final class WorkoutSessionManager: NSObject {
    static let shared = WorkoutSessionManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var isRunning = false
    private(set) var startDate: Date?
    /// Shown in the phone's live banner. Set by whoever starts the workout.
    var workoutTitle: String = "Workout"
    private(set) var heartRate: Double = 0
    private(set) var averageHeartRate: Double = 0
    private(set) var maxHeartRate: Double = 0
    private(set) var activeCalories: Double = 0

    var elapsed: TimeInterval {
        guard let startDate else { return 0 }
        return Date().timeIntervalSince(startDate)
    }

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let toShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
        ]
        let toRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]
        healthStore.requestAuthorization(toShare: toShare, read: toRead) { _, _ in }
    }

    // MARK: - Session lifecycle

    func start() {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                         workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }

            self.session = session
            self.builder = builder
            self.startDate = start
            self.isRunning = true
            self.heartRate = 0
            self.averageHeartRate = 0
            self.maxHeartRate = 0
            self.activeCalories = 0
        } catch {
            print("FitX: could not start workout session: \(error)")
        }
    }

    /// Ends the session and saves the workout to Health. The completion runs on
    /// the main queue with the final metrics — hook the store update there.
    func end(completion: @escaping (_ avgHR: Double, _ maxHR: Double, _ kcal: Double) -> Void) {
        guard let session, let builder else {
            completion(averageHeartRate, maxHeartRate, activeCalories)
            reset()
            return
        }
        let avg = averageHeartRate
        let max = maxHeartRate
        let kcal = activeCalories

        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.finishWorkout { _, _ in
                DispatchQueue.main.async {
                    completion(avg, max, kcal)
                }
            }
        }
        reset()
    }

    /// Ends the session without saving anything to Health.
    func discard() {
        guard let session, let builder else {
            reset()
            return
        }
        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.discardWorkout()
        }
        reset()
    }

    private func reset() {
        session = nil
        builder = nil
        isRunning = false
        startDate = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("FitX: workout session failed: \(error)")
        DispatchQueue.main.async {
            self.reset()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var newHeartRate: Double?
        var newAverage: Double?
        var newMax: Double?
        var newCalories: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            switch quantityType {
            case HKQuantityType(.heartRate):
                let bpm = HKUnit.count().unitDivided(by: .minute())
                newHeartRate = statistics.mostRecentQuantity()?.doubleValue(for: bpm)
                newAverage = statistics.averageQuantity()?.doubleValue(for: bpm)
                newMax = statistics.maximumQuantity()?.doubleValue(for: bpm)
            case HKQuantityType(.activeEnergyBurned):
                newCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
            default:
                break
            }
        }

        DispatchQueue.main.async {
            if let newHeartRate { self.heartRate = newHeartRate }
            if let newAverage { self.averageHeartRate = newAverage }
            if let newMax { self.maxHeartRate = newMax }
            if let newCalories { self.activeCalories = newCalories }
            Connectivity.shared.sendLiveMetrics(heartRate: self.heartRate,
                                                activeCalories: self.activeCalories,
                                                elapsed: self.elapsed,
                                                title: self.workoutTitle)
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
