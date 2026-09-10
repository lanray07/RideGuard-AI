import Foundation

public struct HazardClassification: Sendable {
    public var category: HazardCategory?
    public var requiresConfirmation: Bool
}
/// Conservative keyword classification. Does not invent numerical confidence.
public struct HazardVoiceClassifier: Sendable {
    public init() {}
    public func classifyHazardSpeech(_ text: String) -> HazardClassification {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        let phrase = " " + words.joined(separator: " ") + " "
        if words.contains(where: { ["no", "not", "isn", "wasn", "cleared", "gone"].contains($0) }) {
            return .init(category: nil, requiresConfirmation: true)
        }
        let rules: [(HazardCategory, [String])] = [
            (.pothole, ["pothole", "pot hole"]), (.roadworks, ["roadworks", "road works"]),
            (.debris, ["debris"]), (.blockedCycleLane, ["blocked cycle lane", "blocking the bike lane", "blocked lane"]),
            (.brokenGlass, ["broken glass", "glass"]), (.flooding, ["flooding", "flooded"]),
            (.poorLighting, ["poor lighting"]), (.dangerousJunction, ["dangerous junction", "junction concern"])
        ]
        let matches = rules.filter { rule in rule.1.contains { phrase.contains(" " + $0 + " ") } }.map(\.0)
        return .init(category: matches.count == 1 ? matches[0] : nil, requiresConfirmation: matches.count != 1)
    }
}

public struct SpokenAlertGate: Sendable {
    private var lastSpoken: Date?
    private var seen: Set<UUID> = []
    public var cooldown: TimeInterval
    public init(cooldown: TimeInterval = 45) { self.cooldown = cooldown }
    public mutating func shouldAnnounce(id: UUID, at now: Date, distanceAhead: Double, relevance: Double) -> Bool {
        guard distanceAhead.isFinite, distanceAhead > 0, distanceAhead <= 600, relevance > 0.2,
              !seen.contains(id), lastSpoken.map({ now.timeIntervalSince($0) >= cooldown }) ?? true else { return false }
        seen.insert(id); lastSpoken = now; return true
    }
}

public enum RouteGeometry {
    /// Along-polyline distance only when both locations match the selected route corridor.
    public static func distanceAhead(of rider: Coordinate, hazard: Coordinate, route: [Coordinate], corridor: Double = 40) -> Double? {
        guard route.count > 1 else { return nil }
        func project(_ point: Coordinate) -> (offset: Double, gap: Double) {
            var best = (offset: 0.0, gap: Double.infinity)
            var total = 0.0
            for index in 1..<route.count {
                let a = route[index - 1], b = route[index]
                let scale = cos(a.latitude * .pi / 180)
                let dx = (b.longitude - a.longitude) * scale, dy = b.latitude - a.latitude
                let px = (point.longitude - a.longitude) * scale, py = point.latitude - a.latitude
                let denominator = dx * dx + dy * dy
                let t = denominator > 0 ? max(0, min(1, (px * dx + py * dy) / denominator)) : 0
                let projected = Coordinate(a.latitude + t * (b.latitude - a.latitude), a.longitude + t * (b.longitude - a.longitude))
                let length = a.distance(to: b), gap = point.distance(to: projected)
                if gap < best.gap { best = (total + length * t, gap) }
                total += length
            }
            return best
        }
        let r = project(rider), h = project(hazard)
        guard r.gap <= corridor, h.gap <= corridor, h.offset > r.offset else { return nil }
        return h.offset - r.offset
    }
}
