import Foundation
import SwiftData

@MainActor
class ImportExportManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export

    /// Exports all data as a folder containing data.json and a photos/ subfolder.
    /// Returns the folder URL for sharing.
    func exportData() throws -> URL {
        let collections = try modelContext.fetch(FetchDescriptor<Collection>())
        let venues = try modelContext.fetch(FetchDescriptor<Venue>())
        let trails = try modelContext.fetch(FetchDescriptor<Trail>())

        let exportData = ExportData(
            collections: collections.map { $0.toExport() },
            venues: venues.map { $0.toExport() },
            trails: trails.map { $0.toExport() },
            exportDate: Date(),
            version: "4.0"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportData)

        // Create export folder in temp directory
        let folderName = "GoLoggerPlaces-\(dateFormatter.string(from: Date()))"
        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)

        // Remove any previous export at the same path
        if FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.removeItem(at: folderURL)
        }
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        // Write data.json
        try jsonData.write(to: folderURL.appendingPathComponent("data.json"))

        // Collect all photo filenames and copy to photos/ subfolder
        let venuePhotoFilenames = exportData.venues.flatMap { $0.photoFilenames }
        let waypointPhotoFilenames = exportData.trails.flatMap { $0.waypoints }.flatMap { $0.photoFilenames }
        let allFilenames = venuePhotoFilenames + waypointPhotoFilenames

        if !allFilenames.isEmpty {
            let photosDir = folderURL.appendingPathComponent("photos", isDirectory: true)
            try PhotoStorage.copyPhotos(filenames: allFilenames, to: photosDir)
        }

        print("✅ Export folder created at: \(folderURL.path)")
        return folderURL
    }

    // MARK: - Import

    /// Imports data from either a folder (new format) or a JSON file (legacy format).
    func importData(from url: URL) throws {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            try importFolder(from: url)
        } else {
            try importJSON(from: url)
        }
    }

    // MARK: - Private Import Helpers

    private func importFolder(from folderURL: URL) throws {
        print("📁 ImportExportManager: Importing folder '\(folderURL.lastPathComponent)'")

        let jsonURL = folderURL.appendingPathComponent("data.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw importError(code: 101, description: "No data.json found in '\(folderURL.lastPathComponent)'")
        }

        // Import photos first so they're available when creating Photo records
        let photosDir = folderURL.appendingPathComponent("photos", isDirectory: true)
        if FileManager.default.fileExists(atPath: photosDir.path) {
            try PhotoStorage.importPhotos(from: photosDir)
        }

        try importJSON(from: jsonURL, sourceFolder: folderURL)
    }

    private func importJSON(from jsonURL: URL, sourceFolder: URL? = nil) throws {
        let originalFilename = jsonURL.lastPathComponent
        print("📄 ImportExportManager: Parsing '\(originalFilename)'")

        let jsonData: Data
        do {
            jsonData = try Data(contentsOf: jsonURL)
        } catch {
            throw importError(
                code: 102,
                description: "Failed to read data from '\(originalFilename)'",
                reason: error.localizedDescription,
                underlying: error
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData: ExportData
        do {
            exportData = try decoder.decode(ExportData.self, from: jsonData)
        } catch {
            throw importError(
                code: 103,
                description: "Invalid data format in '\(originalFilename)'",
                reason: "The file format is not compatible with this version of GoLogger Places.",
                underlying: error
            )
        }

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

        // Import Venues
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

            for visitExport in venueExport.visits {
                let visit = Visit(date: visitExport.date, note: visitExport.note)
                modelContext.insert(visit)
                venue.addVisit(visit)
            }

            for linkExport in venueExport.links {
                let link = Link(name: linkExport.name, url: linkExport.url)
                modelContext.insert(link)
                venue.addLink(link)
            }

            for filename in venueExport.photoFilenames {
                let photo = Photo(filename: filename)
                modelContext.insert(photo)
                venue.photos.append(photo)
                photo.venue = venue
            }

            for collectionID in venueExport.collectionIDs {
                if let collection = collectionMap[collectionID] {
                    collection.addVenue(venue)
                }
            }
        }

        // Import Trails
        for trailExport in exportData.trails {
            let trail = Trail(hexColor: trailExport.hexColor)
            trail.name = trailExport.name
            trail.notes = trailExport.notes
            trail.startAddress = trailExport.startAddress
            trail.endAddress = trailExport.endAddress
            trail.createdOn = trailExport.createdOn
            trail.editDate = trailExport.editDate
            modelContext.insert(trail)

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

            trail.updateCache()

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

                for filename in wayPointExport.photoFilenames {
                    let photo = Photo(filename: filename)
                    modelContext.insert(photo)
                    wayPoint.photos.append(photo)
                    photo.waypoint = wayPoint
                }
            }

            for linkExport in trailExport.links {
                let link = Link(name: linkExport.name, url: linkExport.url)
                modelContext.insert(link)
                trail.addLink(link)
            }

            for collectionID in trailExport.collectionIDs {
                if let collection = collectionMap[collectionID] {
                    collection.addTrail(trail)
                }
            }
        }

        try modelContext.save()
        print("✅ Import completed successfully")
    }

    // MARK: - Helpers

    private func importError(code: Int, description: String, reason: String? = nil, underlying: Error? = nil) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: description]
        if let reason { userInfo[NSLocalizedFailureReasonErrorKey] = reason }
        if let underlying { userInfo[NSUnderlyingErrorKey] = underlying }
        return NSError(domain: "ImportExportManager", code: code, userInfo: userInfo)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
