import SwiftUI
import WatchConnectivity
import WatchKit
import AppIntents

@main
struct RideGuardWatchApp: App {
    @State private var bridge = WatchBridge.shared
    var body: some Scene { WindowGroup { WatchRideView().environment(bridge).task { bridge.activate() } } }
}

@Observable @MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    var destination = "Open RideGuard on iPhone"
    var status = "idle"
    var eta: Date?
    var updated: Date?
    var isDemo = false
    var response = ""
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self; WCSession.default.activate()
    }
    func send(_ action: String) async -> String {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            response = "iPhone is unavailable. Nothing was sent."
            return response
        }
        let result: String = await withCheckedContinuation { continuation in
            WCSession.default.sendMessage(["action": action], replyHandler: { reply in
                continuation.resume(returning: reply["message"] as? String ?? "No confirmation received.")
            }, errorHandler: { _ in continuation.resume(returning: "No confirmation received. Check iPhone before retrying.") })
        }
        response = result; WKInterfaceDevice.current().play(.notification)
        return result
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in receive(context) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in receive(applicationContext) }
    }
    private func receive(_ context: [String: Any]) {
        destination = context["destination"] as? String ?? destination
        status = context["status"] as? String ?? "idle"
        isDemo = context["isDemo"] as? Bool ?? false
        if let timestamp = context["eta"] as? Double, timestamp > 0 { eta = Date(timeIntervalSince1970: timestamp) } else { eta = nil }
        if let timestamp = context["updated"] as? Double { updated = Date(timeIntervalSince1970: timestamp) }
    }
}

struct WatchRideView: View {
    @Environment(WatchBridge.self) private var bridge
    @State private var ending = false
    @State private var busy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label(LocalizedStringKey(bridge.isDemo ? "DEMO RIDE" : "RIDEGUARD"), systemImage: "bicycle").font(.caption2).foregroundStyle(.mint)
                    Text(bridge.status == "idle" ? L10n.text(bridge.destination) : bridge.destination).font(.title3.bold())
                    if let eta = bridge.eta { Text(eta, style: .time).font(.system(.largeTitle, design: .rounded, weight: .bold)) }
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        Text(bridge.updated.map { timeline.date.timeIntervalSince($0) > 120 ? L10n.text("Update stale · check iPhone") : L10n.format("Status: %@", L10n.text(bridge.status)) } ?? L10n.text("Waiting for iPhone")).font(.caption2).foregroundStyle(.secondary)
                    }
                    Button("What’s ahead?", systemImage: "waveform") { send("ahead") }
                    Button("I’m OK", systemImage: "checkmark.circle") { send("okay") }
                    NavigationLink("Quick report") {
                        VStack {
                            Button("Pothole") { send("pothole") }
                            Button("Blocked lane") { send("blockedCycleLane") }
                            Button("Debris") { send("debris") }
                            Button("Roadworks") { send("roadworks") }
                            Text(L10n.text(bridge.response)).font(.caption2)
                        }.disabled(busy)
                    }
                    Button("End ride") { ending = true }
                    Text(L10n.text(bridge.response)).font(.caption2)
                    Text("For urgent help, use Apple Watch Emergency SOS. RideGuard does not dispatch help.").font(.caption2).foregroundStyle(.secondary)
                }.disabled(busy)
            }.confirmationDialog("End ride on iPhone?", isPresented: $ending) { Button("End ride") { send("end") } }
        }.tint(.mint)
    }
    private func send(_ action: String) { busy = true; Task { _ = await bridge.send(action); busy = false } }
}

struct WatchAheadIntent: AppIntent {
    static var title: LocalizedStringResource = "What’s ahead on my ride?"
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = await WatchBridge.shared.send("ahead")
        return .result(dialog: "\(response)")
    }
}
struct WatchOkayIntent: AppIntent {
    static var title: LocalizedStringResource = "I’m okay on my ride"
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = await WatchBridge.shared.send("okay")
        return .result(dialog: "\(response)")
    }
}
struct WatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WatchAheadIntent(), phrases: ["What’s ahead in \(.applicationName)"], shortTitle: "What’s ahead?", systemImageName: "waveform")
        AppShortcut(intent: WatchOkayIntent(), phrases: ["I’m okay in \(.applicationName)"], shortTitle: "I’m okay", systemImageName: "checkmark.circle")
    }
}
