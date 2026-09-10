import Foundation

public struct Coordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    public func distance(to other: Coordinate) -> Double {
        let radians = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * radians / 2), 2)
            + cos(latitude * radians) * cos(other.latitude * radians)
            * pow(sin((other.longitude - longitude) * radians / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, min(1, a))), sqrt(max(0, 1 - a)))
    }
}

public enum HazardCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case pothole, roadworks, debris, blockedCycleLane, brokenGlass, poorSurface
    case flooding, poorLighting, dangerousJunction, closure, vehicleObstruction, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .pothole: "Pothole"
        case .roadworks: "Roadworks"
        case .debris: "Debris"
        case .blockedCycleLane: "Blocked cycle lane"
        case .brokenGlass: "Broken glass"
        case .poorSurface: "Poor road surface"
        case .flooding: "Flooding"
        case .poorLighting: "Poor lighting"
        case .dangerousJunction: "Junction concern"
        case .closure: "Temporary closure"
        case .vehicleObstruction: "Vehicle obstruction"
        case .other: "Other"
        }
    }
    public var symbol: String {
        switch self {
        case .pothole, .poorSurface: "circle.dashed"
        case .roadworks: "cone.fill"
        case .debris, .brokenGlass: "sparkles"
        case .blockedCycleLane, .vehicleObstruction: "car.side.fill"
        case .flooding: "water.waves"
        case .poorLighting: "lightbulb.slash"
        case .dangerousJunction: "arrow.triangle.branch"
        case .closure: "hand.raised.fill"
        case .other: "mappin.and.ellipse"
        }
    }
}

public enum Confirmation: String, Codable, Sendable, CaseIterable { case stillThere, cleared, incorrect }
public struct HazardReport: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var category: HazardCategory
    public var coordinate: Coordinate
    public var observedAt: Date
    public var description: String
    public var severity: Int
    public var heading: Double?
    public var isDemo: Bool
    public var votes: [String: Confirmation]
    public init(id: UUID = UUID(), category: HazardCategory, coordinate: Coordinate,
                observedAt: Date = .now, description: String = "", severity: Int = 1,
                heading: Double? = nil, isDemo: Bool = false, votes: [String: Confirmation] = [:]) {
        self.id = id; self.category = category; self.coordinate = coordinate
        self.observedAt = observedAt; self.description = description
        self.severity = max(1, min(3, severity)); self.heading = heading
        self.isDemo = isDemo; self.votes = votes
    }
    public var confirmations: Int { votes.values.filter { $0 == .stillThere }.count }
    public func relevance(at now: Date) -> Double {
        guard observedAt <= now, coordinate.isValid else { return 0 }
        let ageHours = now.timeIntervalSince(observedAt) / 3600
        let halfLife: Double = category == .roadworks || category == .pothole ? 72 : 12
        let negative = votes.values.filter { $0 != .stillThere }.count
        let agreement = Double(1 + confirmations) / Double(1 + confirmations + negative * 2)
        return pow(0.5, ageHours / halfLife) * agreement
    }
}

public enum FactorKind: String, Codable, CaseIterable, Sendable {
    case infrastructure, roadType, junctions, collisions, community, construction, lighting, traffic, surface, timeContext
    public var title: String {
        switch self {
        case .infrastructure: "Cycling infrastructure"
        case .roadType: "Road classification"
        case .junctions: "Junction complexity"
        case .collisions: "Verified collision history"
        case .community: "Community reports"
        case .construction: "Construction and closures"
        case .lighting: "Lighting information"
        case .traffic: "Current traffic"
        case .surface: "Road surface"
        case .timeContext: "Time-of-day context"
        }
    }
}

public struct RiskFactor: Codable, Identifiable, Sendable, Equatable {
    public var id: FactorKind { kind }
    public var kind: FactorKind
    public var indicator: Double
    public var coverage: Double
    public var source: String
    public var observedAt: Date
    public var validFor: TimeInterval
    public var explanation: String
    public var isDemo: Bool
    public init(kind: FactorKind, indicator: Double, coverage: Double, source: String,
                observedAt: Date, validFor: TimeInterval, explanation: String, isDemo: Bool = false) {
        self.kind = kind; self.indicator = indicator; self.coverage = coverage
        self.source = source; self.observedAt = observedAt; self.validFor = validFor
        self.explanation = explanation; self.isDemo = isDemo
    }
}

public struct RouteCandidate: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var destination: String
    public var duration: TimeInterval
    public var distance: Double
    public var coordinates: [Coordinate]
    public var factors: [RiskFactor]
    public var isDemo: Bool
    public init(id: UUID = UUID(), name: String, destination: String, duration: TimeInterval,
                distance: Double, coordinates: [Coordinate], factors: [RiskFactor] = [], isDemo: Bool = false) {
        self.id = id; self.name = name; self.destination = destination; self.duration = duration
        self.distance = distance; self.coordinates = coordinates; self.factors = factors; self.isDemo = isDemo
    }
}
