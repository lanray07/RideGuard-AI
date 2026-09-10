import XCTest
@testable import RideGuardCore

final class RiskEngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func factors(count: Int = 10) -> [RiskFactor] {
        FactorKind.allCases.prefix(count).map { RiskFactor(kind: $0, indicator: 30, coverage: 1, source: "Verified test provider", observedAt: now, validFor: 3600, explanation: "Measured test input") }
    }
    func testNoDataIsUnknownNeverZero() {
        let result = RouteRiskEngine().assess([], at: now)
        XCTAssertNil(result.overallRiskScore)
        XCTAssertEqual(result.confidence, .unavailable)
        XCTAssertEqual(result.missingData.count, 10)
    }
    func testMinimumIndependentEvidence() {
        XCTAssertNil(RouteRiskEngine().assess(factors(count: 2), at: now).overallRiskScore)
        XCTAssertEqual(RouteRiskEngine().assess(factors(count: 3), at: now).overallRiskScore, 30)
        XCTAssertEqual(RouteRiskEngine().assess(factors(count: 3), at: now).confidence, .low)
    }
    func testRejectsStaleFutureInvalidAndMissingSources() {
        var input = factors()
        input[0].observedAt = now.addingTimeInterval(-3601)
        input[1].observedAt = now.addingTimeInterval(1)
        input[2].indicator = .nan
        input[3].coverage = 2
        input[4].source = " "
        input[5].indicator = -1
        input[6].validFor = 0
        let result = RouteRiskEngine().assess(input, at: now)
        XCTAssertEqual(result.factors.count, 3)
        XCTAssertEqual(result.missingData.count, 7)
        XCTAssertEqual(result.overallRiskScore, 30)
    }
    func testDuplicateFactorCannotInflateConfidence() {
        let result = RouteRiskEngine().assess(Array(repeating: factors()[0], count: 20), at: now)
        XCTAssertNil(result.overallRiskScore)
        XCTAssertEqual(result.factors.count, 1)
    }
    func testDemoNeverLeaksIntoProductionScore() {
        let fixture = DemoData.routes(at: now)[0]
        XCTAssertNil(RouteRiskEngine().assess(fixture.factors, at: now).overallRiskScore)
        let demo = RouteRiskEngine().assess(fixture.factors, at: now, allowDemo: true)
        XCTAssertEqual(demo.overallRiskScore, 31)
        XCTAssertTrue(demo.isDemo)
        XCTAssertTrue(CyclingSafetyAIService().explainRouteRisk(demo).contains("Illustrative demo"))
    }
    func testCoverageWeightsWithoutFalsePrecision() {
        var input = factors(count: 4)
        input[0].indicator = 100; input[0].coverage = 0.5
        let result = RouteRiskEngine().assess(input, at: now)
        XCTAssertEqual(result.overallRiskScore, 40)
        XCTAssertEqual(result.coverage, 0.35, accuracy: 0.0001)
    }
    func testCoordinatesAndDistance() {
        XCTAssertFalse(Coordinate(.nan, 0).isValid)
        XCTAssertFalse(Coordinate(91, 0).isValid)
        XCTAssertEqual(Coordinate(0, 0).distance(to: Coordinate(0, 1)), 111_195, accuracy: 5)
    }
}
