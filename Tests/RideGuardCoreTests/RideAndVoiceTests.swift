import XCTest
@testable import RideGuardCore

final class RideAndVoiceTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testOverdueIsNotCompletionAndOkayExtendsWindow() {
        var ride = RideSession(route: DemoData.routes(at: now)[0], at: now)
        ride.apply(.checkOverdue, at: now.addingTimeInterval(2300))
        XCTAssertEqual(ride.status, .overdue)
        ride.apply(.imOkay, at: now.addingTimeInterval(2301))
        XCTAssertEqual(ride.status, .riding)
        ride.apply(.checkOverdue, at: now.addingTimeInterval(2302))
        XCTAssertEqual(ride.status, .riding)
    }
    func testCompletedRideIsTerminal() {
        var ride = RideSession(route: DemoData.routes(at: now)[0], at: now)
        ride.apply(.end, at: now.addingTimeInterval(100))
        ride.apply(.imOkay, at: now.addingTimeInterval(200))
        ride.apply(.moreTime(900), at: now.addingTimeInterval(300))
        XCTAssertEqual(ride.status, .completed)
        XCTAssertEqual(ride.endedAt, now.addingTimeInterval(100))
    }
    func testArrivalDoesNotEscalateAndInvalidExtensionIsIgnored() {
        var ride = RideSession(route: DemoData.routes(at: now)[0], at: now)
        let eta = ride.expectedArrival
        ride.apply(.moreTime(.nan), at: now)
        XCTAssertEqual(ride.expectedArrival, eta)
        ride.apply(.arrive, at: now)
        ride.apply(.checkOverdue, at: now.addingTimeInterval(99_999))
        XCTAssertEqual(ride.status, .arrived)
    }
    func testNaturalPhrasesAndAmbiguity() {
        let classifier = HazardVoiceClassifier()
        XCTAssertEqual(classifier.classifyHazardSpeech("There's broken glass in the cycle lane.").category, .brokenGlass)
        XCTAssertEqual(classifier.classifyHazardSpeech("Big pothole here.").category, .pothole)
        XCTAssertTrue(classifier.classifyHazardSpeech("Pothole and debris").requiresConfirmation)
        XCTAssertTrue(classifier.classifyHazardSpeech("No pothole here").requiresConfirmation)
        XCTAssertTrue(classifier.classifyHazardSpeech("Pothole is gone").requiresConfirmation)
        XCTAssertTrue(classifier.classifyHazardSpeech("That looks strange").requiresConfirmation)
        XCTAssertTrue(classifier.classifyHazardSpeech("Glasshouse").requiresConfirmation)
    }
    func testCooldownDeduplicationAndBehindRider() {
        var gate = SpokenAlertGate()
        let first = UUID(), second = UUID()
        XCTAssertTrue(gate.shouldAnnounce(id: first, at: now, distanceAhead: 200, relevance: 1))
        XCTAssertFalse(gate.shouldAnnounce(id: second, at: now.addingTimeInterval(10), distanceAhead: 200, relevance: 1))
        XCTAssertFalse(gate.shouldAnnounce(id: first, at: now.addingTimeInterval(100), distanceAhead: 200, relevance: 1))
        XCTAssertFalse(gate.shouldAnnounce(id: second, at: now.addingTimeInterval(100), distanceAhead: -1, relevance: 1))
        XCTAssertTrue(gate.shouldAnnounce(id: second, at: now.addingTimeInterval(100), distanceAhead: 200, relevance: 1))
    }
    func testAlongRouteRejectsNearbyParallelStreetAndBehind() {
        let route = [Coordinate(51.5, -0.1), Coordinate(51.51, -0.1)]
        let rider = Coordinate(51.505, -0.1)
        XCTAssertNotNil(RouteGeometry.distanceAhead(of: rider, hazard: Coordinate(51.508, -0.1), route: route))
        XCTAssertNil(RouteGeometry.distanceAhead(of: rider, hazard: Coordinate(51.502, -0.1), route: route))
        XCTAssertNil(RouteGeometry.distanceAhead(of: rider, hazard: Coordinate(51.508, -0.098), route: route))
    }
    func testReportAgeAndOneVotePerRider() {
        var report = HazardReport(category: .debris, coordinate: Coordinate(51.5, 0), observedAt: now)
        XCTAssertEqual(report.relevance(at: now.addingTimeInterval(12 * 3600)), 0.5, accuracy: 0.001)
        report.votes["rider"] = .stillThere
        report.votes["rider"] = .stillThere
        XCTAssertEqual(report.confirmations, 1)
        report.votes["rider"] = .cleared
        XCTAssertEqual(report.confirmations, 0)
        XCTAssertLessThan(report.relevance(at: now), 0.5)
        XCTAssertEqual(report.relevance(at: now.addingTimeInterval(-1)), 0)
    }
    func testPersistenceRoundTrip() throws {
        var ride = RideSession(route: DemoData.routes(at: now)[0], at: now)
        ride.apply(.end, at: now.addingTimeInterval(20))
        let data = try JSONEncoder().encode(ride)
        XCTAssertEqual(try JSONDecoder().decode(RideSession.self, from: data), ride)
    }
}
