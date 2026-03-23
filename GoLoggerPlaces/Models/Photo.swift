import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID
    var filename: String
    var createdAt: Date
    /// The date and time the photo was originally captured, read from EXIF metadata.
    var capturedAt: Date?

    var venue: Venue?
    var waypoint: WayPoint?

    init(filename: String, capturedAt: Date? = nil) {
        self.id = UUID()
        self.filename = filename
        self.createdAt = Date()
        self.capturedAt = capturedAt
    }
}
