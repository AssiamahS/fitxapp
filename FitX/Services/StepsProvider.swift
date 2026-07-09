import Foundation
import HealthKit
import Observation

/// Today's steps + active energy for the Macros tab, read from Health.
@Observable
final class StepsProvider {
    static let shared = StepsProvider()

    private let healthStore = HKHealthStore()
    private(set) var todaySteps: Int?
    private(set) var todayActiveCalories: Double?

    private init() {}

    func requestAndRefresh() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
        ]
        healthStore.requestAuthorization(toShare: [], read: types) { [weak self] granted, _ in
            if granted {
                self?.refresh()
            }
        }
    }

    func refresh() {
        sumToday(.stepCount, unit: .count()) { [weak self] value in
            self?.todaySteps = value.map { Int($0) }
        }
        sumToday(.activeEnergyBurned, unit: .kilocalorie()) { [weak self] value in
            self?.todayActiveCalories = value
        }
    }

    private func sumToday(_ identifier: HKQuantityTypeIdentifier,
                          unit: HKUnit,
                          completion: @escaping (Double?) -> Void) {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: HKQuantityType(identifier),
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, statistics, _ in
            let value = statistics?.sumQuantity()?.doubleValue(for: unit)
            DispatchQueue.main.async {
                completion(value)
            }
        }
        healthStore.execute(query)
    }
}
