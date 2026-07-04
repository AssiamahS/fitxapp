import Foundation
import Observation

@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var totalSeconds: TimeInterval = 0

    var isRunning: Bool { remaining() > 0 }

    func remaining(at now: Date = Date()) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    /// Fraction elapsed, 0...1. Used to drive the progress bar.
    func progress(at now: Date = Date()) -> Double {
        guard totalSeconds > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: now) / totalSeconds))
    }

    func start(seconds: TimeInterval, from now: Date = Date()) {
        totalSeconds = seconds
        endDate = now.addingTimeInterval(seconds)
    }

    func add(seconds: TimeInterval) {
        guard let current = endDate else { return }
        totalSeconds += seconds
        endDate = current.addingTimeInterval(seconds)
    }

    func stop() {
        endDate = nil
        totalSeconds = 0
    }
}
