import AVFoundation
import RideGuardCore

struct VoicePreferences: Codable {
    var enabled = true
    var hazards = true
    var navigation = true
    var checkIns = true
    var confirmations = true
    var detail = "Standard"
}

@MainActor
final class RideAudioSessionManager {
    func activate() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
    }
    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
final class RideVoiceService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let audio = RideAudioSessionManager()
    private(set) var lastMessage: String?
    override init() { super.init(); synthesizer.delegate = self }
    func say(_ message: String, enabled: Bool = true) {
        guard enabled else { return }
        do { try audio.activate() } catch { return }
        lastMessage = message
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
    func repeatLast() { if let lastMessage { say(lastMessage) } }
    func stop() { synthesizer.stopSpeaking(at: .immediate); audio.deactivate() }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in audio.deactivate() }
    }
}

@MainActor
final class SpokenAlertManager {
    private var gate = SpokenAlertGate()
    func reset() { gate = SpokenAlertGate() }
    func nextAlert(at coordinate: Coordinate, route: RouteCandidate, reports: [HazardReport], now: Date = .now) -> String? {
        let candidates = reports.compactMap { report -> (HazardReport, Double)? in
            guard report.isDemo == route.isDemo,
                  let distance = RouteGeometry.distanceAhead(of: coordinate, hazard: report.coordinate, route: route.coordinates) else { return nil }
            return (report, distance)
        }.sorted { lhs, rhs in lhs.0.severity == rhs.0.severity ? lhs.1 < rhs.1 : lhs.0.severity > rhs.0.severity }
        for (report, distance) in candidates {
            if gate.shouldAnnounce(id: report.id, at: now, distanceAhead: distance, relevance: report.relevance(at: now)) {
                return "\(report.isDemo ? "Demo. " : "")Reported \(report.category.title.lowercased()) ahead in approximately \(Int(distance / 50) * 50) metres."
            }
        }
        return nil
    }
}
