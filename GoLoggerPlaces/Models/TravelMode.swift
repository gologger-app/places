import Foundation

/// Enum representing different modes of travel for trail recording
enum TravelMode: String, Codable, CaseIterable {
    case walking
    case biking
    case driving

    /// Display name for the travel mode
    var displayName: String {
        switch self {
        case .walking:
            return "Walking"
        case .biking:
            return "Biking"
        case .driving:
            return "Driving"
        }
    }

    /// Sampling interval in seconds for location updates
    /// Used to determine how frequently to collect location points
    var samplingInterval: TimeInterval {
        switch self {
        case .walking:
            return 7.5  // Every 5-10 seconds (average 7.5)
        case .biking:
            return 4.0  // Every 3-5 seconds (average 4)
        case .driving:
            return 2.5  // Every 2-3 seconds (average 2.5)
        }
    }

    /// Icon name for SF Symbols
    var iconName: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .biking:
            return "bicycle"
        case .driving:
            return "car.fill"
        }
    }
}
