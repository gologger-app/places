import Foundation
import SwiftData

/// Model representing a collection of venues and trails
/// Collections are flexible groupings (like tags) that can represent trips, themes, or any other organization
@Model
final class Collection {
    var id: UUID
    var name: String
    var collectionDescription: String?  // Using collectionDescription to avoid conflict with Model's description
    var editDate: Date

    // Cached computed values for performance (avoid loading relationship arrays)
    var cachedVenueCount: Int = 0
    var cachedTrailCount: Int = 0

    // Relationships - many-to-many with venues and trails
    @Relationship(deleteRule: .nullify, inverse: \Venue.collections)
    var venues: [Venue] = []

    @Relationship(deleteRule: .nullify, inverse: \Trail.collections)
    var trails: [Trail] = []

    init(
        name: String,
        description: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.collectionDescription = description
        self.editDate = Date()
    }

    /// Computed property for venue count (uses cached value for performance)
    var venueCount: Int {
        cachedVenueCount
    }

    /// Computed property for trail count (uses cached value for performance)
    var trailCount: Int {
        cachedTrailCount
    }

    /// Computed property for total trail distance across all trails
    var totalTrailDistance: Double {
        trails.compactMap { $0.totalDistance }.reduce(0, +)
    }

    /// Formatted total trail distance string
    var trailDistanceFormatted: String {
        let distance = totalTrailDistance

        if trails.isEmpty {
            return "No trails"
        }

        return MeasurementFormatter.formatDistance(distance)
    }

    /// Recompute and update cached counts from relationships
    /// Call this after adding/removing venues or trails
    func updateCache() {
        cachedVenueCount = venues.count
        cachedTrailCount = trails.count
    }

    /// Add a venue to this collection
    func addVenue(_ venue: Venue) {
        if !venues.contains(where: { $0.id == venue.id }) {
            venues.append(venue)
            cachedVenueCount += 1
            editDate = Date()
        }
    }

    /// Remove a venue from this collection
    func removeVenue(_ venue: Venue) {
        if let index = venues.firstIndex(where: { $0.id == venue.id }) {
            venues.remove(at: index)
            cachedVenueCount -= 1
            editDate = Date()
        }
    }

    /// Add a trail to this collection
    func addTrail(_ trail: Trail) {
        if !trails.contains(where: { $0.id == trail.id }) {
            trails.append(trail)
            cachedTrailCount += 1
            editDate = Date()
        }
    }

    /// Remove a trail from this collection
    func removeTrail(_ trail: Trail) {
        if let index = trails.firstIndex(where: { $0.id == trail.id }) {
            trails.remove(at: index)
            cachedTrailCount -= 1
            editDate = Date()
        }
    }
}
