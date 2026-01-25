import Foundation
import SwiftData

/// Model representing a visit to a venue
@Model
final class Visit {
    var id: UUID
    var date: Date
    var note: String?

    // Relationship to Venue (many-to-one)
    var venue: Venue?

    init(
        date: Date,
        note: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.note = note
    }
}
