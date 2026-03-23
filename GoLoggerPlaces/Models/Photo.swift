import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID
    var filename: String
    var createdAt: Date

    var venue: Venue?
    var waypoint: WayPoint?

    init(filename: String) {
        self.id = UUID()
        self.filename = filename
        self.createdAt = Date()
    }
}
