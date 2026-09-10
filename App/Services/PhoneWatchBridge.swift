import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchBridge: NSObject, WCSessionDelegate {
    var onAction: ((String) -> String)?
    private var latest: [String: Any] = [:]
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func publish(destination: String, status: String, eta: Date?, isDemo: Bool) {
        latest = ["destination": destination, "status": status, "eta": eta?.timeIntervalSince1970 ?? 0,
                  "isDemo": isDemo, "updated": Date.now.timeIntervalSince1970]
        guard WCSession.default.activationState == .activated, WCSession.default.isPaired else { return }
        try? WCSession.default.updateApplicationContext(latest)
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in if activationState == .activated { try? session.updateApplicationContext(latest) } }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let action = message["action"] as? String ?? ""
        Task { @MainActor in replyHandler(["message": onAction?(action) ?? "Open RideGuard on iPhone."]) }
    }
}
