import XCTest
@testable import IntervalPro

/// Tests for SessionRepository using MockSessionRepository
final class SessionRepositoryTests: XCTestCase {

    var sut: MockSessionRepository!

    override func setUp() {
        super.setUp()
        sut = MockSessionRepository()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Save
    func test_save_addsNewSession() async throws {
        let session = createTestSession()

        try await sut.save(session)

        let sessions = try await sut.fetchRecent(limit: 10)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id)
    }

    func test_save_updatesExistingSession() async throws {
        var session = createTestSession()
        try await sut.save(session)

        session.score = 95.0
        try await sut.save(session)

        let fetched = try await sut.fetch(id: session.id)
        XCTAssertEqual(fetched?.score, 95.0)

        let all = try await sut.fetchRecent(limit: 10)
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - Fetch
    func test_fetchById_returnsCorrectSession() async throws {
        let session1 = createTestSession()
        let session2 = createTestSession()
        try await sut.save(session1)
        try await sut.save(session2)

        let fetched = try await sut.fetch(id: session1.id)

        XCTAssertEqual(fetched?.id, session1.id)
    }

    func test_fetchById_returnsNilForNonexistent() async throws {
        let fetched = try await sut.fetch(id: UUID())

        XCTAssertNil(fetched)
    }

    func test_fetchRecent_returnsSessionsSortedByDate() async throws {
        let oldSession = createTestSession(startDate: Date().addingTimeInterval(-3600))
        let newSession = createTestSession(startDate: Date())

        try await sut.save(oldSession)
        try await sut.save(newSession)

        let sessions = try await sut.fetchRecent(limit: 10)

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.first?.id, newSession.id)
    }

    func test_fetchRecent_respectsLimit() async throws {
        for i in 0..<5 {
            let session = createTestSession(startDate: Date().addingTimeInterval(TimeInterval(-i * 3600)))
            try await sut.save(session)
        }

        let sessions = try await sut.fetchRecent(limit: 3)

        XCTAssertEqual(sessions.count, 3)
    }

    // MARK: - Fetch by Plan
    func test_fetchByPlan_filtersCorrectly() async throws {
        let planId1 = UUID()
        let planId2 = UUID()

        try await sut.save(createTestSession(planId: planId1))
        try await sut.save(createTestSession(planId: planId1))
        try await sut.save(createTestSession(planId: planId2))

        let sessions = try await sut.fetchByPlan(planId: planId1)

        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.allSatisfy { $0.planId == planId1 })
    }

    // MARK: - Fetch Best
    func test_fetchBest_returnsHighestScoredSession() async throws {
        let planId = UUID()

        var session1 = createTestSession(planId: planId)
        session1.score = 80

        var session2 = createTestSession(planId: planId)
        session2.score = 95

        var session3 = createTestSession(planId: planId)
        session3.score = 85

        try await sut.save(session1)
        try await sut.save(session2)
        try await sut.save(session3)

        let best = try await sut.fetchBest(forPlanId: planId)

        XCTAssertEqual(best?.id, session2.id)
        XCTAssertEqual(best?.score, 95)
    }

    func test_fetchBest_returnsNilForEmptyPlan() async throws {
        let best = try await sut.fetchBest(forPlanId: UUID())

        XCTAssertNil(best)
    }

    // MARK: - Date Range
    func test_fetchInDateRange_filtersCorrectly() async throws {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)

        try await sut.save(createTestSession(startDate: now))
        try await sut.save(createTestSession(startDate: yesterday))
        try await sut.save(createTestSession(startDate: twoDaysAgo))

        let sessions = try await sut.fetchInDateRange(
            from: yesterday.addingTimeInterval(-1),
            to: now.addingTimeInterval(1)
        )

        XCTAssertEqual(sessions.count, 2)
    }

    // MARK: - Delete
    func test_delete_removesSession() async throws {
        let session = createTestSession()
        try await sut.save(session)

        try await sut.delete(id: session.id)

        let fetched = try await sut.fetch(id: session.id)
        XCTAssertNil(fetched)
    }

    func test_deleteAll_removesAllSessions() async throws {
        try await sut.save(createTestSession())
        try await sut.save(createTestSession())
        try await sut.save(createTestSession())

        try await sut.deleteAll()

        let sessions = try await sut.fetchRecent(limit: 10)
        XCTAssertTrue(sessions.isEmpty)
    }

    // MARK: - Helpers
    private func createTestSession(
        planId: UUID = UUID(),
        startDate: Date = Date()
    ) -> TrainingSession {
        TrainingSession(
            planId: planId,
            planName: "Test Plan",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(1800),
            isCompleted: true,
            totalDistance: 5000,
            avgHeartRate: 165,
            maxHeartRate: 180,
            minHeartRate: 140,
            timeInZone: 1200,
            score: 85
        )
    }
}
