import MapKit
import RideGuardCore

enum RoutingError: LocalizedError {
    case unsupported, unavailable
    var errorDescription: String? {
        switch self {
        case .unsupported: "Cycling directions require iOS 26 or later. Explore the labelled demo on this device."
        case .unavailable: "No cycling routes are available for this destination. Try a nearby destination."
        }
    }
}

@MainActor
final class RoutingService {
    func search(_ query: String, near origin: Coordinate?) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let origin { request.region = MKCoordinateRegion(center: origin.cl, latitudinalMeters: 30_000, longitudinalMeters: 30_000) }
        return try await MKLocalSearch(request: request).start().mapItems
    }
    func routes(from origin: Coordinate, to destination: MKMapItem) async throws -> [RouteCandidate] {
        guard #available(iOS 26.0, *) else { throw RoutingError.unsupported }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.cl))
        request.destination = destination
        request.transportType = .cycling
        request.requestsAlternateRoutes = true
        let response = try await MKDirections(request: request).calculate()
        guard !response.routes.isEmpty else { throw RoutingError.unavailable }
        return response.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }.enumerated().map { index, route in
            let points = route.polyline.points()
            let coordinates = (0..<route.polyline.pointCount).map { i in
                let c = points[i].coordinate
                return Coordinate(c.latitude, c.longitude)
            }
            // MapKit route geometry and ETA do not establish the requested risk factors.
            return RouteCandidate(name: index == 0 ? "Fastest available" : "Alternative \(index)",
                                  destination: destination.name ?? "Destination", duration: route.expectedTravelTime,
                                  distance: route.distance, coordinates: coordinates)
        }
    }
}
extension Coordinate {
    var cl: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
