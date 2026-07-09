#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// State for the lock-screen / Dynamic Island live activity during a workout.
/// Compiled into both the app and the widget extension.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var startDate: Date
        var completedSets: Int
        var currentExercise: String?
        /// Rest countdown, when one is running.
        var restEndDate: Date?
        var restTotalSeconds: TimeInterval?
    }
}
#endif
