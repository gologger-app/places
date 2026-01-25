import Foundation
import SwiftData
import CoreLocation

/// Model representing a single location/venue that can belong to zero or more collections
@Model
final class Venue {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var label: String
    var address: String?
    var notes: String?
    var createdOn: Date
    var editDate: Date

    // Many-to-many relationship with Collections
    // Note: inverse relationship is defined on Collection.venues
    var collections: [Collection] = []

    // One-to-many relationship with Visits
    @Relationship(deleteRule: .cascade, inverse: \Visit.venue)
    var visits: [Visit] = []

    // One-to-many relationship with Links
    @Relationship(deleteRule: .cascade, inverse: \Link.venue)
    var links: [Link] = []

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        label: String,
        address: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.label = label
        self.address = address
        self.notes = notes
        self.createdOn = Date()
        self.editDate = Date()
    }

    /// Convenience initializer with CLLocationCoordinate2D
    convenience init(
        coordinate: CLLocationCoordinate2D,
        label: String,
        altitude: Double? = nil
    ) {
        self.init(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            altitude: altitude,
            label: label
        )
    }

    /// Convert to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Convert to CLLocation (includes altitude if available)
    var location: CLLocation {
        if let altitude = altitude {
            return CLLocation(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: 0,
                verticalAccuracy: 0,
                timestamp: createdOn
            )
        } else {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
    }

    /// Formatted coordinates string
    var coordinatesFormatted: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    /// Add a visit to this venue
    func addVisit(_ visit: Visit) {
        visits.append(visit)
        visit.venue = self
        editDate = Date()
    }

    /// Add a link to this venue
    func addLink(_ link: Link) {
        links.append(link)
        link.venue = self
        editDate = Date()
    }

    /// Remove a link from this venue
    func removeLink(_ link: Link) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links.remove(at: index)
            editDate = Date()
        }
    }

    /// Remove a visit from this venue
    func removeVisit(_ visit: Visit) {
        if let index = visits.firstIndex(where: { $0.id == visit.id }) {
            visits.remove(at: index)
            editDate = Date()
        }
    }
}
