import AppIntents
import RideGuardCore

enum VoiceHazard: String, AppEnum {
    case pothole, roadworks, debris, blockedCycleLane, brokenGlass, flooding, poorLighting, dangerousJunction
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Hazard"
    static var caseDisplayRepresentations: [VoiceHazard: DisplayRepresentation] = [
        .pothole: "Pothole", .roadworks: "Roadworks", .debris: "Debris", .blockedCycleLane: "Blocked cycle lane",
        .brokenGlass: "Broken glass", .flooding: "Flooding", .poorLighting: "Poor lighting", .dangerousJunction: "Junction concern"
    ]
}

struct ReportHazardIntent: AppIntent {
    static var title: LocalizedStringResource = "Report a hazard"
    static var description = IntentDescription("Save a brief hazard observation during an active RideGuard ride. Reports stay on your device.")
    @Parameter(title: "Hazard") var hazard: VoiceHazard
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = RideStore.shared
        guard store.activeRide != nil, store.repository != nil else { throw RideCommandError.noRide }
        guard let category = HazardCategory(rawValue: hazard.rawValue) else { throw RideCommandError.noRide }
        try store.report(category)
        let text = "\(store.demoMode ? "Demo: " : "")\(category.title) saved on this device."
        return .result(dialog: "\(text)")
    }
}
struct WhatsAheadIntent: AppIntent {
    static var title: LocalizedStringResource = "What’s ahead?"
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = RideStore.shared.whatsAhead()
        return .result(dialog: "\(text)")
    }
}
struct RideETAIntent: AppIntent {
    static var title: LocalizedStringResource = "What’s my ride ETA?"
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let ride = RideStore.shared.activeRide else { throw RideCommandError.noRide }
        let text = "\(ride.route.isDemo ? "Demo. " : "")Estimated arrival: \(ride.expectedArrival.formatted(date: .omitted, time: .shortened))."
        return .result(dialog: "\(text)")
    }
}
struct ImOkayIntent: AppIntent {
    static var title: LocalizedStringResource = "I’m okay"
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard RideStore.shared.activeRide != nil else { throw RideCommandError.noRide }
        RideStore.shared.apply(.imOkay)
        return .result(dialog: "Your check-in window has been updated. No contact message was sent.")
    }
}
struct EndRideIntent: AppIntent {
    static var title: LocalizedStringResource = "End my ride"
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard RideStore.shared.activeRide != nil else { throw RideCommandError.noRide }
        try await requestConfirmation(result: .result(dialog: "End this ride and stop its location updates?"))
        RideStore.shared.apply(.end)
        return .result(dialog: "Ride ended. No contact message was sent.")
    }
}
struct RideGuardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ReportHazardIntent(), phrases: ["Report a hazard with \(.applicationName)"], shortTitle: "Report a hazard", systemImageName: "mappin.and.ellipse")
        AppShortcut(intent: WhatsAheadIntent(), phrases: ["What’s ahead in \(.applicationName)"], shortTitle: "What’s ahead?", systemImageName: "waveform")
        AppShortcut(intent: RideETAIntent(), phrases: ["What’s my ETA in \(.applicationName)"], shortTitle: "Ride ETA", systemImageName: "clock")
        AppShortcut(intent: ImOkayIntent(), phrases: ["I’m okay in \(.applicationName)"], shortTitle: "I’m okay", systemImageName: "checkmark.circle")
        AppShortcut(intent: EndRideIntent(), phrases: ["End my ride in \(.applicationName)"], shortTitle: "End ride", systemImageName: "stop.circle")
    }
}
