import CoreLocation
import Observation
import RideGuardCore

@Observable @MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var location: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var error: String?
    var onUpdate: ((CLLocation) -> Void)?
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 10
        authorization = manager.authorizationStatus
    }
    var recentCoordinate: Coordinate? {
        guard let location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65,
              abs(location.timestamp.timeIntervalSinceNow) < 30 else { return nil }
        return Coordinate(location.coordinate.latitude, location.coordinate.longitude)
    }
    func requestForPlanning() {
        error = nil
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { manager.requestLocation() }
        else { error = "Location is off. You can enable it in iPhone Settings, or explore the demo." }
    }
    func startRide() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }
    func stopRide() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways { self.manager.requestLocation() }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in location = latest; error = nil; onUpdate?(latest) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.error = message }
    }
}
