import ActivityKit
import Foundation

struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var arrival: Date
        var status: String
        var lastUpdate: Date
    }
    var destination: String
    var isDemo: Bool
}
