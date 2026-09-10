import Foundation

public struct RiskAssessment: Codable, Sendable {
    public enum Confidence: String, Codable, Sendable { case unavailable, low, moderate, high }
    public var overallRiskScore: Int?
    public var confidence: Confidence
    public var factors: [RiskFactor]
    public var missingData: [FactorKind]
    public var dataFreshness: Date?
    public var coverage: Double
    public var isDemo: Bool
    public var label: String {
        guard let score = overallRiskScore else { return "Insufficient data" }
        switch score {
        case 0...20: return "Lower observed risk"
        case 21...40: return "Relatively lower risk"
        case 41...60: return "Moderate indicators"
        case 61...80: return "Elevated indicators"
        default: return "Higher observed risk"
        }
    }
}

/// Versioned heuristic, NOT a collision probability or a validated predictive model.
/// Rejects stale, invalid and duplicate inputs, rather than converting absence to zero.
public struct RouteRiskEngine: Sendable {
    public static let version = "0.1-experimental"
    public init() {}
    public func assess(_ input: [RiskFactor], at now: Date = .now, allowDemo: Bool = false) -> RiskAssessment {
        var unique: [FactorKind: RiskFactor] = [:]
        for factor in input {
            guard (!factor.isDemo || allowDemo), factor.indicator.isFinite,
                  (0...100).contains(factor.indicator), factor.coverage.isFinite,
                  (0.01...1).contains(factor.coverage), !factor.source.trimmingCharacters(in: .whitespaces).isEmpty,
                  factor.validFor.isFinite, factor.validFor > 0,
                  factor.observedAt <= now,
                  now.timeIntervalSince(factor.observedAt) <= factor.validFor else { continue }
            if let old = unique[factor.kind], old.observedAt >= factor.observedAt { continue }
            unique[factor.kind] = factor
        }
        let valid = FactorKind.allCases.compactMap { unique[$0] }
        let coverage = valid.reduce(0) { $0 + $1.coverage } / Double(FactorKind.allCases.count)
        // At least three independent factors and 25% of total factor coverage.
        let sufficient = valid.count >= 3 && coverage >= 0.25
        let weight = valid.reduce(0) { $0 + $1.coverage }
        let score = sufficient ? Int((valid.reduce(0) { $0 + $1.indicator * $1.coverage } / weight).rounded()) : nil
        let confidence: RiskAssessment.Confidence = !sufficient ? .unavailable : coverage < 0.5 ? .low : coverage < 0.8 ? .moderate : .high
        return RiskAssessment(overallRiskScore: score, confidence: confidence, factors: valid,
                              missingData: FactorKind.allCases.filter { unique[$0] == nil },
                              dataFreshness: valid.map(\.observedAt).min(), coverage: coverage,
                              isDemo: valid.contains { $0.isDemo })
    }
}

/// Template-based explanation consumes only validated structured values. No remote LLM.
public struct CyclingSafetyAIService: Sendable {
    public init() {}
    public func explainRouteRisk(_ assessment: RiskAssessment) -> String {
        guard let score = assessment.overallRiskScore else {
            return "There is not enough current, verified information to calculate a risk score. Missing information does not mean low risk."
        }
        return "\(assessment.isDemo ? "Illustrative demo. " : "")Risk indicator \(score) of 100. \(assessment.confidence.rawValue.capitalized) data confidence. "
            + assessment.factors.map(\.explanation).joined(separator: " ")
            + " A lower score cannot guarantee safety."
    }
    public func compareRoutes(_ route: RouteCandidate, with other: RouteCandidate) -> String {
        let delta = Int((route.duration - other.duration) / 60)
        return "\(route.name) is estimated at \(Int(route.duration / 60)) minutes, "
            + (delta == 0 ? "the same time as \(other.name)." : "\(abs(delta)) minutes \(delta > 0 ? "longer" : "shorter") than \(other.name).")
    }
    public func summariseIncidents(_ reports: [HazardReport], at now: Date = .now) -> String {
        let current = reports.filter { $0.relevance(at: now) > 0.2 }
        return current.isEmpty ? "No current reports in the available data. Conditions may be unreported." : "\(current.count) current reports in the available data. Reports may be incomplete."
    }
}
