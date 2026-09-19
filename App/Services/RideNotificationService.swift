import UserNotifications
import RideGuardCore

@MainActor
final class RideNotificationService {
    private var generation = UUID()
    private var currentIdentifier: String?
    func schedule(_ ride: RideSession) async throws {
        let token = UUID()
        generation = token
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
        guard generation == token else { return }
        let old = await center.pendingNotificationRequests()
        guard generation == token else { return }
        center.removePendingNotificationRequests(withIdentifiers: old.map(\.identifier).filter { $0.hasPrefix("ride-overdue") })
        let identifier = "ride-overdue-\(token.uuidString)"
        currentIdentifier = identifier
        let content = UNMutableNotificationContent()
        content.title = L10n.text(ride.route.isDemo ? "Demo ride check-in" : "Everything okay?")
        content.body = L10n.text("Your expected arrival has passed. Open RideGuard to check in or add more time.")
        content.sound = .default
        let interval = max(1, ride.expectedArrival.addingTimeInterval(ride.gracePeriod).timeIntervalSinceNow)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                 trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
        if generation != token { center.removePendingNotificationRequests(withIdentifiers: [identifier]) }
    }
    func cancel() {
        let token = UUID(); generation = token
        let center = UNUserNotificationCenter.current()
        if let currentIdentifier { center.removePendingNotificationRequests(withIdentifiers: [currentIdentifier]) }
        currentIdentifier = nil
        Task {
            let pending = await center.pendingNotificationRequests()
            guard generation == token else { return }
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("ride-overdue") })
            let delivered = await center.deliveredNotifications()
            guard generation == token else { return }
            center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix("ride-overdue") })
        }
    }
}
