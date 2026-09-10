import Foundation

public enum RideStatus: String, Codable, Sendable { case riding, overdue, arrived, completed }
public enum RideAction: Sendable { case checkOverdue, imOkay, moreTime(TimeInterval), arrive, end }
public struct RideSession: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID = UUID()
    public var route: RouteCandidate
    public var startedAt: Date
    public var expectedArrival: Date
    public var gracePeriod: TimeInterval
    public private(set) var status: RideStatus = .riding
    public private(set) var endedAt: Date?
    public var lastUpdate: Date
    public var travelledMetres: Double = 0
    public var reportCount: Int = 0
    public init(route: RouteCandidate, at now: Date = .now, gracePeriod: TimeInterval = 600) {
        self.route = route; self.startedAt = now; self.lastUpdate = now
        self.expectedArrival = now.addingTimeInterval(max(60, route.duration))
        self.gracePeriod = max(60, gracePeriod)
    }
    public mutating func apply(_ action: RideAction, at now: Date = .now) {
        guard status != .completed else { return }
        switch action {
        case .checkOverdue:
            if status == .riding && now > expectedArrival.addingTimeInterval(gracePeriod) { status = .overdue }
        case .imOkay:
            guard status == .riding || status == .overdue else { return }
            expectedArrival = max(expectedArrival, now); status = .riding
        case .moreTime(let seconds):
            guard seconds.isFinite, seconds > 0, status != .arrived else { return }
            expectedArrival = max(expectedArrival, now).addingTimeInterval(min(seconds, 86_400)); status = .riding
        case .arrive: status = .arrived
        case .end: status = .completed; endedAt = now
        }
        lastUpdate = now
    }
}
