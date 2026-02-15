import Foundation
import SwiftData
import MapKit

/// Service responsible for CRUD operations on SwiftData models
class DataService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Collection Operations

    /// Create a new collection
    @discardableResult
    func createCollection(
        name: String,
        description: String? = nil
    ) -> Collection {
        let collection = Collection(
            name: name,
            description: description
        )

        modelContext.insert(collection)
        try? modelContext.save()

        return collection
    }

    /// Fetch all collections, sorted by edit date (most recent first)
    func fetchCollections() throws -> [Collection] {
        let descriptor = FetchDescriptor<Collection>(
            sortBy: [SortDescriptor(\.editDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch a specific collection by ID
    func fetchCollection(id: UUID) throws -> Collection? {
        let descriptor = FetchDescriptor<Collection>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Update a collection (just save the context since SwiftData tracks changes)
    func updateCollection(_ collection: Collection) {
        collection.editDate = Date()
        try? modelContext.save()
    }

    /// Delete a collection (venues and trails remain due to nullify delete rule)
    func deleteCollection(_ collection: Collection) {
        modelContext.delete(collection)
        try? modelContext.save()
    }

    // MARK: - Venue Operations

    /// Create a new venue (optionally add to collections)
    @discardableResult
    func createVenue(
        latitude: Double,
        longitude: Double,
        label: String,
        altitude: Double? = nil,
        address: String? = nil,
        notes: String? = nil,
        collections: [Collection] = []
    ) -> Venue {
        let venue = Venue(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            label: label,
            address: address,
            notes: notes
        )

        // Add to collections if provided
        for collection in collections {
            collection.addVenue(venue)
        }

        modelContext.insert(venue)
        try? modelContext.save()

        return venue
    }

    /// Fetch all venues
    func fetchVenues() throws -> [Venue] {
        let descriptor = FetchDescriptor<Venue>(
            sortBy: [SortDescriptor(\.editDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch venues that don't belong to any collection
    func fetchUnassignedVenues() throws -> [Venue] {
        let descriptor = FetchDescriptor<Venue>(
            predicate: #Predicate { $0.collections.isEmpty }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Update a venue
    func updateVenue(_ venue: Venue) {
        venue.editDate = Date()
        try? modelContext.save()
    }

    /// Delete a venue
    func deleteVenue(_ venue: Venue) {
        modelContext.delete(venue)
        try? modelContext.save()
    }

    // MARK: - Trail Operations

    /// Create a new trail from recorded locations (optionally add to collections)
    @discardableResult
    func createTrail(
        locations: [CLLocation],
        collections: [Collection] = []
    ) -> Trail {
        let trail = Trail()

        // Create trail points from locations
        for location in locations {
            let point = TrailPoint(from: location)
            trail.points.append(point)
            modelContext.insert(point)
        }

        // Update cached values for performance
        trail.updateCache()

        // Add to collections if provided
        for collection in collections {
            collection.addTrail(trail)
        }

        modelContext.insert(trail)
        try? modelContext.save()

        return trail
    }

    /// Fetch all trails
    func fetchTrails() throws -> [Trail] {
        let descriptor = FetchDescriptor<Trail>(
            sortBy: [SortDescriptor(\.editDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch trails that don't belong to any collection
    func fetchUnassignedTrails() throws -> [Trail] {
        let descriptor = FetchDescriptor<Trail>(
            predicate: #Predicate { $0.collections.isEmpty }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Update a trail
    func updateTrail(_ trail: Trail) {
        trail.editDate = Date()
        try? modelContext.save()
    }

    /// Delete a trail
    func deleteTrail(_ trail: Trail) {
        modelContext.delete(trail)
        try? modelContext.save()
    }

    // MARK: - Search and Filter

    /// Search collections by name or description
    func searchCollections(query: String) throws -> [Collection] {
        let descriptor = FetchDescriptor<Collection>(
            predicate: #Predicate { collection in
                collection.name.localizedStandardContains(query) ||
                (collection.collectionDescription?.localizedStandardContains(query) ?? false)
            },
            sortBy: [SortDescriptor(\.editDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Search venues by label or notes
    func searchVenues(query: String) throws -> [Venue] {
        let descriptor = FetchDescriptor<Venue>(
            predicate: #Predicate { venue in
                venue.label.localizedStandardContains(query) ||
                (venue.notes?.localizedStandardContains(query) ?? false)
            },
            sortBy: [SortDescriptor(\.editDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Statistics

    /// Get total number of collections
    func getCollectionCount() throws -> Int {
        let descriptor = FetchDescriptor<Collection>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Get total number of venues
    func getVenueCount() throws -> Int {
        let descriptor = FetchDescriptor<Venue>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Get total number of trails
    func getTrailCount() throws -> Int {
        let descriptor = FetchDescriptor<Trail>()
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Data Migration

    /// Migrate existing collections to populate cached counts
    /// Call this once after updating to the cached counts version
    func migrateCollectionCachedCounts() {
        do {
            let collections = try fetchCollections()
            var migratedCount = 0

            for collection in collections {
                // Only migrate if cached counts are zero but relationships exist
                if collection.cachedVenueCount == 0 || collection.cachedTrailCount == 0 {
                    collection.updateCache()
                    migratedCount += 1
                }
            }

            if migratedCount > 0 {
                try modelContext.save()
                print("✅ Migrated \(migratedCount) collections to use cached counts")
            } else {
                print("ℹ️ No collections needed migration")
            }
        } catch {
            print("❌ Failed to migrate collection cached counts: \(error)")
        }
    }
}
