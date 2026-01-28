import Foundation
import HealthKit
import Combine

/// HealthKit manager for heart rate monitoring and workout writing
/// Per CLAUDE.md: Privacy compliance required for HR data
@MainActor
final class HealthKitManager: ObservableObject, @preconcurrency HealthKitManaging {
    // MARK: - Singleton
    static let shared = HealthKitManager()

    // MARK: - Published State
    @Published private(set) var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    @Published private(set) var isMonitoring: Bool = false

    // MARK: - Private Properties
    private let healthStore: HKHealthStore
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var workoutBuilder: HKWorkoutBuilder?
    private var workoutSession: HKWorkoutSession?

    // MARK: - Subjects
    private let heartRateSubject = PassthroughSubject<Int, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Types
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let workoutType = HKWorkoutType.workoutType()
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

    private var typesToRead: Set<HKObjectType> {
        [heartRateType, workoutType, activeEnergyType, distanceType]
    }

    private var typesToWrite: Set<HKSampleType> {
        [heartRateType, workoutType, activeEnergyType, distanceType]
    }

    // MARK: - Protocol Conformance
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var heartRatePublisher: AnyPublisher<Int, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    // MARK: - Init
    private init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.error("HealthKit not available on this device")
            self.healthStore = HKHealthStore()
            return
        }
        self.healthStore = HKHealthStore()
        checkAuthorizationStatus()
    }

    // For testing with dependency injection
    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
        checkAuthorizationStatus()
    }

    // MARK: - Authorization
    private func checkAuthorizationStatus() {
        let status = healthStore.authorizationStatus(for: heartRateType)

        switch status {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .sharingDenied:
            authorizationStatus = .denied
        case .sharingAuthorized:
            authorizationStatus = .authorized
        @unknown default:
            authorizationStatus = .notDetermined
        }

        Log.health.debug("HealthKit authorization status: \(self.authorizationStatus.displayText)")
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: typesToWrite,
                read: typesToRead
            )

            // Check status after request
            checkAuthorizationStatus()

            if authorizationStatus == .denied {
                throw HealthKitError.authorizationDenied
            }

            Log.health.info("HealthKit authorization granted")
        } catch {
            Log.health.error("HealthKit authorization failed: \(error)")
            throw HealthKitError.authorizationFailed
        }
    }

    // MARK: - Heart Rate Monitoring
    func startHeartRateMonitoring() async throws {
        guard isAuthorized else {
            throw HealthKitError.authorizationDenied
        }

        guard !isMonitoring else {
            Log.health.warning("Heart rate monitoring already active")
            return
        }

        // Stop any existing queries
        stopHeartRateMonitoring()

        // Create observer query for real-time updates
        let observerQuery = HKObserverQuery(
            sampleType: heartRateType,
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            if let error = error {
                Log.health.error("Observer query error: \(error)")
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                await self?.fetchLatestHeartRate()
            }
            completionHandler()
        }

        healthStore.execute(observerQuery)
        self.observerQuery = observerQuery

        // Enable background delivery
        do {
            try await healthStore.enableBackgroundDelivery(
                for: heartRateType,
                frequency: .immediate
            )
            Log.health.debug("Background delivery enabled for heart rate")
        } catch {
            Log.health.warning("Failed to enable background delivery: \(error)")
            // Continue without background delivery
        }

        // Create anchored query for streaming updates
        let anchor = HKQueryAnchor.init(fromValue: 0)
        let anchoredQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: createRecentPredicate(),
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            Task { @MainActor in
                    self?.processHeartRateSamples(samples)
                }
        }

        anchoredQuery.updateHandler = { [weak self] _, samples, _, _, error in
            Task { @MainActor in
                    self?.processHeartRateSamples(samples)
                }
        }

        healthStore.execute(anchoredQuery)
        self.anchoredQuery = anchoredQuery

        isMonitoring = true
        Log.health.info("Heart rate monitoring started")
    }

    func stopHeartRateMonitoring() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }

        if let query = anchoredQuery {
            healthStore.stop(query)
            anchoredQuery = nil
        }

        isMonitoring = false
        Log.health.info("Heart rate monitoring stopped")
    }

    private func fetchLatestHeartRate() async {
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: createRecentPredicate(),
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                return
            }

            let bpm = Int(sample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            ))

            Task { @MainActor [weak self] in
                self?.publishHeartRate(bpm)
            }
        }

        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latestSample = quantitySamples.last else {
            return
        }

        let bpm = Int(latestSample.quantity.doubleValue(
            for: HKUnit.count().unitDivided(by: .minute())
        ))

        Task { @MainActor [weak self] in
            self?.publishHeartRate(bpm)
        }
    }

    private func publishHeartRate(_ bpm: Int) {
        // Validate HR is within reasonable range
        guard bpm >= 30 && bpm <= 250 else {
            Log.health.warning("Invalid HR value filtered: \(bpm)")
            return
        }

        Log.logHeartRate(bpm, context: "HealthKit")
        heartRateSubject.send(bpm)
    }

    private func createRecentPredicate() -> NSPredicate {
        let startDate = Date().addingTimeInterval(-60) // Last minute
        return HKQuery.predicateForSamples(
            withStart: startDate,
            end: nil,
            options: .strictStartDate
        )
    }

    // MARK: - Workout Session
    func startWorkout(activityType: HKWorkoutActivityType) async throws {
        guard isAuthorized else {
            throw HealthKitError.authorizationDenied
        }

        guard workoutBuilder == nil else {
            throw HealthKitError.workoutAlreadyStarted
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor

        workoutBuilder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        do {
            try await workoutBuilder?.beginCollection(at: Date())
            Log.health.info("Workout session started")
        } catch {
            workoutBuilder = nil
            Log.health.error("Failed to start workout: \(error)")
            throw error
        }
    }

    func pauseWorkout() async throws {
        guard workoutBuilder != nil else {
            throw HealthKitError.workoutNotStarted
        }

        // Note: HKWorkoutBuilder doesn't have pause - this is tracked locally
        Log.health.debug("Workout paused (local tracking)")
    }

    func resumeWorkout() async throws {
        guard workoutBuilder != nil else {
            throw HealthKitError.workoutNotStarted
        }

        Log.health.debug("Workout resumed (local tracking)")
    }

    func endWorkout() async throws -> HKWorkout? {
        guard let builder = workoutBuilder else {
            throw HealthKitError.workoutNotStarted
        }

        do {
            try await builder.endCollection(at: Date())
            let workout = try await builder.finishWorkout()

            workoutBuilder = nil
            Log.health.info("Workout ended successfully")

            return workout
        } catch {
            workoutBuilder = nil
            Log.health.error("Failed to end workout: \(error)")
            throw error
        }
    }

    /// Add heart rate samples to current workout
    func addHeartRateSamples(_ samples: [HRSample]) async throws {
        guard let builder = workoutBuilder else {
            throw HealthKitError.workoutNotStarted
        }

        let hkSamples = samples.map { sample in
            HKQuantitySample(
                type: heartRateType,
                quantity: HKQuantity(
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    doubleValue: Double(sample.bpm)
                ),
                start: sample.timestamp,
                end: sample.timestamp
            )
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(hkSamples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Add workout event (for laps)
    func addLapEvent(at date: Date) async throws {
        guard let builder = workoutBuilder else {
            throw HealthKitError.workoutNotStarted
        }

        let lapEvent = HKWorkoutEvent(
            type: .lap,
            dateInterval: DateInterval(start: date, duration: 0),
            metadata: nil
        )

        try await builder.addWorkoutEvents([lapEvent])
        Log.health.debug("Lap event added at \(date)")
    }

    // MARK: - Queries
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [HRSample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed)
                    return
                }

                let hrSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HRSample(
                        timestamp: sample.startDate,
                        bpm: Int(sample.quantity.doubleValue(
                            for: HKUnit.count().unitDivided(by: .minute())
                        )),
                        source: DataSource.healthKit
                    )
                } ?? []

                continuation.resume(returning: hrSamples)
            }

            healthStore.execute(query)
        }
    }

    func fetchRecentWorkouts(limit: Int) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForWorkouts(
            with: .running
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }
}
