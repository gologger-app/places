import Foundation
import SwiftData
import CoreLocation

/// Model representing a continuous trail/route that can belong to zero or more collections
@Model
final class Trail {
    var id: UUID
    var name: String?  // Optional custom name for the trail
    var notes: String?  // Optional notes about the trail
    var startAddress: String?  // Reverse-geocoded address of the starting point
    var endAddress: String?  // Reverse-geocoded address of the ending point
    var createdOn: Date
    var editDate: Date
    var hexColor: String = "#007AFF"  // Hex color for trail visualization (default: system blue for existing trails)

    // Cached computed values for performance (avoid loading points relationship)
    var cachedTotalDistance: Double?  // In meters
    var cachedStartTime: Date?
    var cachedEndTime: Date?
    var cachedDuration: TimeInterval?  // In seconds
    var cachedPointCount: Int = 0

    // Relationship to TrailPoints (one-to-many)
    @Relationship(deleteRule: .cascade, inverse: \TrailPoint.trail)
    var points: [TrailPoint] = []

    // Relationship to WayPoints (one-to-many)
    @Relationship(deleteRule: .cascade, inverse: \WayPoint.trail)
    var waypoints: [WayPoint] = []

    // Many-to-many relationship with Collections
    // Note: inverse relationship is defined on Collection.trails
    var collections: [Collection] = []

    // One-to-many relationship with Links
    @Relationship(deleteRule: .cascade, inverse: \Link.trail)
    var links: [Link] = []

    // Optional travel mode — nullified if the TravelMode is deleted
    var travelMode: TravelMode?

    init(
        hexColor: String? = nil
    ) {
        self.id = UUID()
        self.createdOn = Date()
        self.editDate = Date()
        // Use provided color, or generate a random one for new trails
        self.hexColor = hexColor ?? Trail.generateRandomHexColor()
    }

    /// Start time from first trail point (uses cached value for performance)
    var startTime: Date? {
        cachedStartTime
    }

    /// End time from last trail point (uses cached value for performance)
    var endTime: Date? {
        cachedEndTime
    }

    /// Total distance from trail points in meters (uses cached value for performance)
    var totalDistance: Double? {
        cachedTotalDistance
    }

    /// Actual duration from trail points in seconds (uses cached value for performance)
    var actualDuration: TimeInterval? {
        cachedDuration
    }

    /// Number of trail points (uses cached value for performance)
    var pointCount: Int {
        cachedPointCount
    }

    /// Recompute and update all cached values from points
    /// Call this after adding/removing/modifying trail points
    func updateCache() {
        guard !points.isEmpty else {
            cachedTotalDistance = nil
            cachedStartTime = nil
            cachedEndTime = nil
            cachedDuration = nil
            cachedPointCount = 0
            return
        }

        cachedPointCount = points.count

        let timestamps = points.map { $0.timestamp }
        cachedStartTime = timestamps.min()
        cachedEndTime = timestamps.max()

        if let start = cachedStartTime, let end = cachedEndTime {
            cachedDuration = end.timeIntervalSince(start)
        } else {
            cachedDuration = nil
        }

        guard points.count > 1 else {
            cachedTotalDistance = nil
            return
        }

        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        var distance: Double = 0

        for i in 1..<sortedPoints.count {
            let previousLocation = CLLocation(
                latitude: sortedPoints[i-1].latitude,
                longitude: sortedPoints[i-1].longitude
            )
            let currentLocation = CLLocation(
                latitude: sortedPoints[i].latitude,
                longitude: sortedPoints[i].longitude
            )
            distance += currentLocation.distance(from: previousLocation)
        }

        cachedTotalDistance = distance
    }

    /// Display name for the trail (custom name or default based on date)
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }

        if let startTime = startTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Trail - \(formatter.string(from: startTime))"
        }

        return "Unnamed Trail"
    }

    /// Formatted distance string
    var distanceFormatted: String {
        guard let distance = totalDistance else {
            return "N/A"
        }
        return MeasurementFormatter.formatDistance(distance)
    }

    /// Formatted duration string (HH:MM:SS)
    var durationFormatted: String {
        guard let duration = actualDuration else {
            return "N/A"
        }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Generate a random vibrant hex color for trail visualization
    static func generateRandomHexColor() -> String {
        // Generate vibrant colors by ensuring saturation and brightness are high
        let hue = Double.random(in: 0...360)
        let saturation = Double.random(in: 0.6...1.0)  // High saturation for vibrant colors
        let brightness = Double.random(in: 0.6...0.9)  // High brightness, but not too light

        // Convert HSB to RGB
        let c = brightness * saturation
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c

        var r = 0.0, g = 0.0, b = 0.0

        switch hue {
        case 0..<60:
            r = c; g = x; b = 0
        case 60..<120:
            r = x; g = c; b = 0
        case 120..<180:
            r = 0; g = c; b = x
        case 180..<240:
            r = 0; g = x; b = c
        case 240..<300:
            r = x; g = 0; b = c
        default:
            r = c; g = 0; b = x
        }

        let red = Int((r + m) * 255)
        let green = Int((g + m) * 255)
        let blue = Int((b + m) * 255)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Estimate the size in bytes of this trail when exported as JSON
    /// Returns a formatted string (e.g., "2.5 MB" or "125 KB")
    var estimatedJSONExportSize: String {
        do {
            // Create export structure for this trail
            let trailExport = self.toExport()
            let pointsExport = self.points.map { $0.toExport() }
            let waypointsExport = self.waypoints.map { $0.toExport() }

            // Create a simplified export data structure for just this trail
            struct SingleTrailExport: Codable {
                let trail: TrailExport
                let points: [TrailPointExport]
                let waypoints: [WayPointExport]
            }

            let singleTrailData = SingleTrailExport(
                trail: trailExport,
                points: pointsExport,
                waypoints: waypointsExport
            )

            // Encode to JSON with same formatting as export
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(singleTrailData)

            // Get size in bytes
            let sizeInBytes = jsonData.count

            // Format the size
            return ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file)
        } catch {
            return "Unknown"
        }
    }

    /// Add a link to this trail
    func addLink(_ link: Link) {
        links.append(link)
        link.trail = self
        editDate = Date()
    }

    /// Remove a link from this trail
    func removeLink(_ link: Link) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links.remove(at: index)
            editDate = Date()
        }
    }
}


