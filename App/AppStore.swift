import SwiftUI
import SwiftData
import CoreLocation
import RideGuardCore

struct TrustedContact: Codable, Identifiable {
    var id = UUID()
    var name: String
    var phone: String
}
struct SavedDestination: Codable, Identifiable {
    var id = UUID()
    var label: String
    var query: String
}
struct AppSnapshot: Codable {
    var reports: [HazardReport] = []
    var history: [RideSession] = []
    var activeRide: RideSession?
    var contacts: [TrustedContact] = []
    var destinations: [SavedDestination] = []
    var voice = VoicePreferences()
    var graceMinutes = 10
    var feedback: [String: String] = [:]
    var reportPhotos: [String: Data] = [:]
}

@Observable @MainActor
final class RideStore {
    static let shared = RideStore()
    var snapshot = AppSnapshot()
    var demoMode = true
    var routes: [RouteCandidate] = DemoData.routes()
    var selectedRouteID: UUID?
    var selectedTab = 0
    var error: String?
    var notice: String?
    var lastCompleted: RideSession?
    private(set) var repository: LocalRepository?
    let location = LocationService()
    let routing = RoutingService()
    let voice = RideVoiceService()
    let alerts = SpokenAlertManager()
    let subscriptions = SubscriptionService()
    let activities = LiveActivityService()
    let notifications = RideNotificationService()
    let watch = PhoneWatchBridge()
    private var previousLocation: CLLocation?
    private let demoReports = DemoData.reports()

    var reports: [HazardReport] {
        if !demoMode { return snapshot.reports.filter { !$0.isDemo } }
        let local = snapshot.reports.filter(\.isDemo)
        let overridden = Set(local.map(\.id))
        return demoReports.filter { !overridden.contains($0.id) } + local
    }
    var selectedRoute: RouteCandidate? { routes.first { $0.id == selectedRouteID } ?? routes.first }
    var activeRide: RideSession? { snapshot.activeRide }
    var isMoving: Bool { !demoMode && (location.location?.speed ?? 0) > 1.5 && activeRide != nil }
    var voiceEnabled: Bool { snapshot.voice.enabled }
    func configure(context: ModelContext) {
        guard repository == nil else { return }
        let repo = LocalRepository(context: context)
        repository = repo
        do { snapshot = try repo.load(AppSnapshot.self, key: "snapshot") ?? AppSnapshot() }
        catch { self.error = L10n.format("Local data could not be read. Nothing has been overwritten. %@", error.localizedDescription); repository = nil }
        if let ride = activeRide {
            demoMode = ride.route.isDemo
            routes = [ride.route]
            selectedTab = 2
            // Restore requires a rider action before restarting location collection.
            notice = "Your ride was restored. Tap Resume updates to continue location tracking."
        }
        location.onUpdate = { [weak self] location in self?.updateLocation(location) }
        watch.onAction = { [weak self] action in self?.handleWatchAction(action) ?? "Open RideGuard on iPhone." }
        watch.activate()
        publishWatch()
    }
    @discardableResult func persist() -> Bool {
        guard let repository else { error = "Local storage is unavailable. Changes cannot be saved."; return false }
        do { try repository.save(snapshot, key: "snapshot"); return true }
        catch { self.error = L10n.format("Changes could not be saved: %@", error.localizedDescription); return false }
    }
    func changeMode(_ demo: Bool) {
        guard activeRide == nil else { return }
        demoMode = demo
        routes = demo ? DemoData.routes() : []
        selectedRouteID = nil
    }
    func startRide() {
        guard activeRide == nil, let route = selectedRoute else { return }
        guard route.isDemo || location.recentCoordinate != nil else { error = "A recent location is required. Tap Use my location and try again."; return }
        let ride = RideSession(route: route, gracePeriod: Double(snapshot.graceMinutes * 60))
        snapshot.activeRide = ride
        guard persist() else { snapshot.activeRide = nil; return }
        previousLocation = nil; alerts.reset()
        if !route.isDemo { location.startRide() }
        activities.start(ride)
        selectedTab = 2
        persist(); publishWatch()
        Task { do { try await notifications.schedule(ride) } catch { self.error = "Ride started. The check-in reminder could not be scheduled." } }
    }
    func resumeRide() {
        guard let ride = activeRide else { return }
        if !ride.route.isDemo { location.startRide() }
        notice = "Ride updates resumed."
        tick()
    }
    func apply(_ action: RideAction) {
        guard var ride = activeRide else { return }
        ride.apply(action)
        if ride.status == .completed {
            snapshot.history.insert(ride, at: 0)
            snapshot.activeRide = nil; lastCompleted = ride
            location.stopRide(); previousLocation = nil; voice.stop(); notifications.cancel()
            Task { await activities.end(ride) }
        } else {
            snapshot.activeRide = ride
            Task {
                await activities.update(ride)
                if ride.status == .arrived { notifications.cancel() }
                else { do { try await notifications.schedule(ride) } catch { self.error = "The check-in reminder could not be updated." } }
            }
        }
        persist(); publishWatch()
    }
    func tick() {
        guard var ride = activeRide else { return }
        let before = ride.status
        ride.apply(.checkOverdue)
        if before != ride.status {
            snapshot.activeRide = ride; persist(); publishWatch()
            if snapshot.voice.checkIns { voice.say("Your ride is taking longer than expected. Are you okay?", enabled: voiceEnabled) }
        }
    }
    func report(_ category: HazardCategory, description: String = "", severity: Int = 1, photo: Data? = nil) throws {
        let coordinate: Coordinate
        if demoMode { coordinate = DemoData.origin }
        else if let recent = location.recentCoordinate { coordinate = recent }
        else { throw RideCommandError.locationUnavailable }
        let report = HazardReport(category: category, coordinate: coordinate, description: description, severity: severity,
                                  heading: location.location.flatMap { $0.course >= 0 ? $0.course : nil }, isDemo: demoMode)
        let before = snapshot
        snapshot.reports.insert(report, at: 0)
        if let photo { snapshot.reportPhotos[report.id.uuidString] = photo }
        if snapshot.activeRide != nil { snapshot.activeRide?.reportCount += 1 }
        guard persist() else { snapshot = before; throw RideCommandError.storageUnavailable }
        notice = L10n.format(demoMode ? "Demo: %@ saved on this device." : "%@ saved on this device.", L10n.text(category.title))
        if snapshot.voice.confirmations { voice.say(notice!, enabled: voiceEnabled) }
    }
    func confirm(_ report: HazardReport, as vote: Confirmation) {
        if let index = snapshot.reports.firstIndex(where: { $0.id == report.id }) {
            snapshot.reports[index].votes["local-rider"] = vote
        } else {
            var copy = report; copy.votes["local-rider"] = vote
            snapshot.reports.append(copy)
        }
        if persist() { notice = "Your observation was saved locally." }
    }
    func whatsAhead() -> String {
        guard let ride = activeRide else { return "Start a ride to check reports on your route." }
        let coordinate = ride.route.isDemo ? ride.route.coordinates.first : location.recentCoordinate
        guard let coordinate else { return "Your current location is unavailable." }
        let nearby = reports.compactMap { report -> (HazardReport, Double)? in
            guard report.relevance(at: .now) > 0.2,
                  let metres = RouteGeometry.distanceAhead(of: coordinate, hazard: report.coordinate, route: ride.route.coordinates), metres <= 1000 else { return nil }
            return (report, metres)
        }.sorted { $0.1 < $1.1 }
        guard let first = nearby.first else { return "No current reports in the next kilometre of available route data. Conditions may be unreported." }
        return L10n.format(ride.route.isDemo ? "Demo. Reported %@ approximately %lld metres ahead." : "Reported %@ approximately %lld metres ahead.", L10n.text(first.0.category.title), max(50, Int(first.1 / 50) * 50))
    }
    func deleteAll() {
        if activeRide != nil { apply(.end) }
        do {
            guard let repository else { throw RideCommandError.storageUnavailable }
            try repository.deleteAll()
            snapshot = AppSnapshot(); lastCompleted = nil; notice = "Local history, reports, contacts and preferences deleted."
            publishWatch()
        } catch { self.error = L10n.format("Deletion failed: %@", error.localizedDescription) }
    }
    func exportData() throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RideGuardExport", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("rideguard-export.json")
        try encoder.encode(snapshot).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    private func updateLocation(_ point: CLLocation) {
        guard var ride = activeRide, !ride.route.isDemo, location.recentCoordinate != nil else { return }
        if let previousLocation {
            let elapsed = point.timestamp.timeIntervalSince(previousLocation.timestamp)
            let distance = point.distance(from: previousLocation)
            if elapsed > 0, elapsed < 60, distance / elapsed < 25 { ride.travelledMetres += distance }
        }
        previousLocation = point; ride.lastUpdate = point.timestamp
        let coordinate = Coordinate(point.coordinate.latitude, point.coordinate.longitude)
        if let destination = ride.route.coordinates.last, coordinate.distance(to: destination) < 60,
           point.speed >= 0, point.speed < 1, ride.status != .arrived {
            ride.apply(.arrive)
            notifications.cancel()
            if snapshot.voice.checkIns { voice.say("Looks like you've arrived. Check in when you're ready.", enabled: voiceEnabled) }
        }
        snapshot.activeRide = ride; persist(); publishWatch()
        if snapshot.voice.hazards, let alert = alerts.nextAlert(at: coordinate, route: ride.route, reports: reports) {
            voice.say(alert, enabled: voiceEnabled)
        }
        Task { await activities.update(ride) }
        tick()
    }
    private func handleWatchAction(_ action: String) -> String {
        switch action {
        case "ahead": return whatsAhead()
        case "okay": guard activeRide != nil else { return "No active ride." }; apply(.imOkay); return "Okay. Your check-in window has been updated."
        case "end": guard activeRide != nil else { return "No active ride." }; apply(.end); return "Ride ended. No contact message was sent."
        default:
            guard let category = HazardCategory(rawValue: action), activeRide != nil else { return "Open a ride on iPhone first." }
            do { try report(category); return L10n.text(demoMode ? "Demo report saved on iPhone." : "Report saved on iPhone.") }
            catch { return error.localizedDescription }
        }
    }
    private func publishWatch() {
        watch.publish(destination: activeRide?.route.destination ?? "No active ride", status: activeRide?.status.rawValue ?? "idle",
                      eta: activeRide?.expectedArrival, isDemo: activeRide?.route.isDemo ?? demoMode)
    }
}
enum RideCommandError: LocalizedError {
    case locationUnavailable, noRide, storageUnavailable
    var errorDescription: String? {
        switch self {
        case .locationUnavailable: L10n.text("No recent location is available. Open RideGuard and enable location before reporting.")
        case .noRide: L10n.text("There is no active RideGuard ride.")
        case .storageUnavailable: L10n.text("The report could not be saved to this device. Please try again when local storage is available.")
        }
    }
}
