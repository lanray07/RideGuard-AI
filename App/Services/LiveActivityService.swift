import ActivityKit
import RideGuardCore

@MainActor
final class LiveActivityService {
    private var activity: Activity<RideActivityAttributes>?
    func start(_ ride: RideSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RideActivityAttributes(destination: ride.route.destination, isDemo: ride.route.isDemo)
        activity = try? Activity.request(attributes: attributes, content: content(ride), pushType: nil)
    }
    func update(_ ride: RideSession) async { await activity?.update(content(ride)) }
    func end(_ ride: RideSession) async {
        // End restored activities too, so a process restart cannot leave an active badge indefinitely.
        for active in Activity<RideActivityAttributes>.activities {
            await active.end(content(ride), dismissalPolicy: .immediate)
        }
        activity = nil
    }
    private func content(_ ride: RideSession) -> ActivityContent<RideActivityAttributes.ContentState> {
        .init(state: .init(arrival: ride.expectedArrival, status: ride.status.rawValue, lastUpdate: ride.lastUpdate), staleDate: .now.addingTimeInterval(120))
    }
}
