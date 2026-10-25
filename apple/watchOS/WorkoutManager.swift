import Foundation
import HealthKit

/// Runs an HKWorkoutSession (traditional strength training) while a workout is being logged:
/// live heart rate and active energy on the wrist, and the finished workout saved to Health.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeKcal: Double = 0
    @Published private(set) var running = false
    @Published var lastError: String?

    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var hrSamples: [Double] = []

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKObjectType.workoutType()]
        do {
            try await health.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func start(at date: Date = Date()) async {
        guard Self.isAvailable, session == nil else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: health, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            hrSamples = []
            session.startActivity(with: date)
            try await builder.beginCollection(at: date)
            running = true
        } catch {
            lastError = error.localizedDescription
            session = nil
            builder = nil
        }
    }

    /// Ends the session. When `save` is true the workout is written to Health.
    func end(save: Bool) async -> HealthSummary? {
        guard let session, let builder else { return nil }
        let summary = HealthSummary(
            activeKcal: activeKcal > 0 ? activeKcal : nil,
            avgHeartRate: hrSamples.isEmpty ? nil : hrSamples.reduce(0, +) / Double(hrSamples.count),
            maxHeartRate: hrSamples.max()
        )
        session.end()
        do {
            try await builder.endCollection(at: Date())
            if save {
                try await builder.addMetadata([HKMetadataKeyIndoorWorkout: true])
                _ = try await builder.finishWorkout()
            } else {
                builder.discardWorkout()
            }
        } catch {
            lastError = error.localizedDescription
        }
        self.session = nil
        self.builder = nil
        running = false
        heartRate = 0
        activeKcal = 0
        return save ? summary : nil
    }

    /// Re-attaches to a session that was running when the app was relaunched by the system.
    func recover() async {
        guard Self.isAvailable, session == nil else { return }
        do {
            guard let recovered = try await health.recoverActiveWorkoutSession() else { return }
            session = recovered
            builder = recovered.associatedWorkoutBuilder()
            recovered.delegate = self
            builder?.delegate = self
            running = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    fileprivate func update(from builder: HKLiveWorkoutBuilder, types: Set<HKSampleType>) {
        if types.contains(HKQuantityType(.heartRate)),
           let bpm = builder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
            heartRate = bpm
            hrSamples.append(bpm)
        }
        if types.contains(HKQuantityType(.activeEnergyBurned)),
           let kcal = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            activeKcal = kcal
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.lastError = message }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in self.update(from: workoutBuilder, types: collectedTypes) }
    }
}
