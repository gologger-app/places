import Foundation
import SwiftData

@Model
final class TravelMode {
    var id: UUID
    var name: String
    var icon: String
    var isBuiltIn: Bool
    var sortOrder: Int

    init(name: String, icon: String, isBuiltIn: Bool = false, sortOrder: Int = 999) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}
