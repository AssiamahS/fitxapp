import ActivityKit
import Foundation

/// Drives the lock-screen banner + Dynamic Island while a workout is running.
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?

    private init() {}

    func sync(workout: Workout?, restTimer: RestTimer) {
        guard let workout else {
            end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let currentExercise = workout.exercises.last {
            $0.sets.contains(where: \.isCompleted)
        }?.exercise.name ?? workout.exercises.first?.exercise.name

        let state = WorkoutActivityAttributes.ContentState(
            title: workout.title,
            startDate: workout.startDate,
            completedSets: workout.completedSetCount,
            currentExercise: currentExercise,
            restEndDate: restTimer.isRunning ? restTimer.endDate : nil,
            restTotalSeconds: restTimer.isRunning ? restTimer.totalSeconds : nil)
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity {
            Task {
                await activity.update(content)
            }
        } else {
            activity = try? Activity.request(attributes: WorkoutActivityAttributes(),
                                             content: content)
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
