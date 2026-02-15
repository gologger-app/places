import Foundation
import SwiftData

@MainActor
class ImportExportManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export

    /// Exports all data to a JSON file and returns the file URL
    func exportData() throws -> URL {
        // Fetch top-level data only (children are accessed via relationships)
        let collections = try modelContext.fetch(FetchDescriptor<Collection>())
        let venues = try modelContext.fetch(FetchDescriptor<Venue>())
        let trails = try modelContext.fetch(FetchDescriptor<Trail>())

        // Create export data structure
        // Children (visits, links, points, waypoints) are now nested within their parents
        let exportData = ExportData(
            collections: collections.map { $0.toExport() },
            venues: venues.map { $0.toExport() },
            trails: trails.map { $0.toExport() },
            exportDate: Date(),
            version: "3.0"  // Updated version for nested structure
        )

        // Write JSON file
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportData)

        // Create JSON file in temporary directory
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gologger-places-export-\(dateFormatter.string(from: Date())).json")

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            try FileManager.default.removeItem(at: jsonURL)
        }

        try jsonData.write(to: jsonURL)
        print("✅ JSON export created successfully at: \(jsonURL.path)")

        return jsonURL
    }

    // MARK: - Import

    /// Imports data from a JSON file
    func importData(from jsonURL: URL) throws {
        // Store original filename for better error messages
        let originalFilename = jsonURL.lastPathComponent
        print("📄 ImportExportManager: Starting import of '\(originalFilename)'")

        // Read JSON file
        let jsonData: Data
        do {
            jsonData = try Data(contentsOf: jsonURL)
            print("✅ Successfully read JSON file")
        } catch {
            throw NSError(
                domain: "ImportExportManager",
                code: 102,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to read data from '\(originalFilename)'",
                    NSLocalizedFailureReasonErrorKey: error.localizedDescription,
                    NSUnderlyingErrorKey: error
                ]
            )
        }

        // Decode JSON data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData: ExportData
        do {
            exportData = try decoder.decode(ExportData.self, from: jsonData)
            print("✅ Successfully decoded JSON data")
        } catch {
            throw NSError(
                domain: "ImportExportManager",
                code: 103,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid data format in '\(originalFilename)'",
                    NSLocalizedFailureReasonErrorKey: "The file format is not compatible with this version of GoLogger Places.",
                    NSUnderlyingErrorKey: error
                ]
            )
        }

        // Import all data
        // First create all objects without relationships
        var collectionMap: [UUID: Collection] = [:]

        // Import Collections
        for collectionExport in exportData.collections {
            let collection = Collection(
                name: collectionExport.name,
                description: collectionExport.collectionDescription
            )

            collection.editDate = collectionExport.editDate

            modelContext.insert(collection)
            collectionMap[collectionExport.id] = collection
        }

        // Import Venues with nested visits and links
        for venueExport in exportData.venues {
            let venue = Venue(
                latitude: venueExport.latitude,
                longitude: venueExport.longitude,
                altitude: venueExport.altitude,
                label: venueExport.label,
                address: venueExport.address,
                notes: venueExport.notes
            )
            venue.createdOn = venueExport.createdOn
            venue.editDate = venueExport.editDate

            modelContext.insert(venue)

            // Import nested visits
            for visitExport in venueExport.visits {
                let visit = Visit(
                    date: visitExport.date,
                    note: visitExport.note
                )
                modelContext.insert(visit)
                venue.addVisit(visit)
            }

            // Import nested links
            for linkExport in venueExport.links {
                let link = Link(
                    name: linkExport.name,
                    url: linkExport.url
                )
                modelContext.insert(link)
                venue.addLink(link)
            }

            // Link to collections
            for collectionID in venueExport.collectionIDs {
                if let collection = collectionMap[collectionID] {
                    collection.addVenue(venue)
                }
            }
        }

        // Import Trails with nested points, waypoints, and links
        for trailExport in exportData.trails {
            // Read travelModeRaw for backward compatibility but don't use it
            let trail = Trail(
                hexColor: trailExport.hexColor
            )
            trail.name = trailExport.name
            trail.createdOn = trailExport.createdOn
            trail.editDate = trailExport.editDate

            modelContext.insert(trail)

            // Import nested trail points
            for pointExport in trailExport.points {
                let point = TrailPoint(
                    latitude: pointExport.latitude,
                    longitude: pointExport.longitude,
                    altitude: pointExport.altitude,
                    timestamp: pointExport.timestamp,
                    speed: pointExport.speed,
                    course: pointExport.course,
                    horizontalAccuracy: pointExport.horizontalAccuracy
                )
                modelContext.insert(point)
                trail.points.append(point)
            }

            // Update cached values after importing points
            trail.updateCache()

            // Import nested waypoints
            for wayPointExport in trailExport.waypoints {
                let wayPoint = WayPoint(
                    label: wayPointExport.label,
                    latitude: wayPointExport.latitude,
                    longitude: wayPointExport.longitude,
                    altitude: wayPointExport.altitude,
                    visitTime: wayPointExport.visitTime
                )
                modelContext.insert(wayPoint)
                trail.waypoints.append(wayPoint)
            }

            // Import nested links
            for linkExport in trailExport.links {
                let link = Link(
                    name: linkExport.name,
                    url: linkExport.url
                )
                modelContext.insert(link)
                trail.addLink(link)
            }

            // Link to collections
            for collectionID in trailExport.collectionIDs {
                if let collection = collectionMap[collectionID] {
                    collection.addTrail(trail)
                }
            }
        }

        // Save all changes
        try modelContext.save()
    }

    // MARK: - Helpers

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
//        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }
}
