import Foundation
import SwiftData
import CoreLocation

/// Model representing a user-defined point of interest along a trail
@Model
final class WayPoint {
    var id: UUID
    var label: String
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var visitTime: Date

    // Back reference to parent Trail (set via inverse relationship)
    var trail: Trail?

    // One-to-many relationship with Photos
    @Relationship(deleteRule: .cascade, inverse: \Photo.waypoint)
    var photos: [Photo] = []

    init(
        label: String,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        visitTime: Date = Date()
    ) {
        self.id = UUID()
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.visitTime = visitTime
    }

    /// Convenience initializer from CLLocation
    convenience init(label: String, from location: CLLocation, visitTime: Date = Date()) {
        self.init(
            label: label,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            visitTime: visitTime
        )
    }

    /// Convert to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
