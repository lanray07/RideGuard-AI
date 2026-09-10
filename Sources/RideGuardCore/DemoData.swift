import Foundation

public enum DemoData {
    public static let origin = Coordinate(51.5273, -0.0875)
    public static func routes(at now: Date = .now) -> [RouteCandidate] {
        let specs: [(String, Double, Double, Double)] = [("Lower risk", 28, 8690, 31), ("Fastest", 24, 7885, 67), ("Quieter", 31, 9334, 24)]
        return specs.enumerated().map { index, spec in
            let descriptions = ["Illustrative infrastructure indicator; no measured lane coverage.", "Illustrative road classification indicator.", "Illustrative junction indicator.", "Illustrative surface indicator.", "Illustrative construction indicator."]
            let kinds: [FactorKind] = [.infrastructure, .roadType, .junctions, .surface, .construction]
            let factors = kinds.enumerated().map { offset, kind in
                RiskFactor(kind: kind, indicator: spec.3, coverage: 1, source: "RideGuard sample fixture",
                           observedAt: now, validFor: 86_400, explanation: descriptions[offset], isDemo: true)
            }
            return RouteCandidate(name: spec.0, destination: "Home · London Fields", duration: spec.1 * 60,
                                  distance: spec.2, coordinates: [origin,
                                    Coordinate(51.532, -0.080 + Double(index) * 0.003),
                                    Coordinate(51.534, -0.072 + Double(index) * 0.004),
                                    Coordinate(51.539, -0.067 + Double(index) * 0.003),
                                    Coordinate(51.5415, -0.060)], factors: factors, isDemo: true)
        }
    }
    public static func reports(at now: Date = .now) -> [HazardReport] {
        [HazardReport(category: .roadworks, coordinate: Coordinate(51.534, -0.072), observedAt: now.addingTimeInterval(-1080), description: "Sample roadworks report. Not a current street observation.", isDemo: true),
         HazardReport(category: .blockedCycleLane, coordinate: Coordinate(51.539, -0.067), observedAt: now.addingTimeInterval(-720), description: "Sample lane obstruction. Not a current street observation.", isDemo: true),
         HazardReport(category: .pothole, coordinate: Coordinate(51.532, -0.080), observedAt: now.addingTimeInterval(-2400), description: "Sample surface report. Not a current street observation.", isDemo: true)]
    }
}
