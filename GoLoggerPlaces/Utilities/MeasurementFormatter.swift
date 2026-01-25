import Foundation

/// Utility for formatting measurements based on the selected unit system
enum MeasurementFormatter {

    // MARK: - Conversion Constants

    private static let metersToFeet: Double = 3.28084
    private static let metersToMiles: Double = 0.000621371
    private static let kmToMiles: Double = 0.621371
    private static let mpsToMph: Double = 2.23694
    private static let mpsToKmh: Double = 3.6

    // MARK: - Distance Formatting

    /// Formats a distance in meters according to the current unit system
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted string with appropriate unit
    static func formatDistance(_ meters: Double) -> String {
        switch Config.unitSystem {
        case .metric:
            if meters < 1000 {
                return String(format: "%.0fm", meters)
            } else {
                return String(format: "%.2fkm", meters / 1000.0)
            }
        case .imperial:
            let feet = meters * metersToFeet
            if feet < 528 { // Less than 0.1 miles (528 feet)
                return String(format: "%.0fft", feet)
            } else {
                let miles = meters * metersToMiles
                return String(format: "%.2fmi", miles)
            }
        }
    }

    /// Formats a distance for statistics display (always shows larger units)
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted string with appropriate unit
    static func formatDistanceLarge(_ meters: Double) -> String {
        switch Config.unitSystem {
        case .metric:
            return String(format: "%.2f km", meters / 1000.0)
        case .imperial:
            let miles = meters * metersToMiles
            return String(format: "%.2f mi", miles)
        }
    }

    // MARK: - Speed Formatting

    /// Formats a speed in meters per second according to the current unit system
    /// - Parameter metersPerSecond: Speed in meters per second
    /// - Returns: Formatted string with appropriate unit (km/h or mph)
    static func formatSpeed(_ metersPerSecond: Double) -> String {
        switch Config.unitSystem {
        case .metric:
            let kmh = metersPerSecond * mpsToKmh
            return String(format: "%.1f km/h", kmh)
        case .imperial:
            let mph = metersPerSecond * mpsToMph
            return String(format: "%.1f mph", mph)
        }
    }

    /// Returns the speed unit label
    static var speedUnit: String {
        switch Config.unitSystem {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }

    /// Converts meters per second to the current unit system's speed value (without formatting)
    /// - Parameter metersPerSecond: Speed in meters per second
    /// - Returns: Speed value in current unit system (km/h or mph)
    static func speedValue(_ metersPerSecond: Double) -> Double {
        switch Config.unitSystem {
        case .metric:
            return metersPerSecond * mpsToKmh
        case .imperial:
            return metersPerSecond * mpsToMph
        }
    }

    // MARK: - Altitude/Elevation Formatting

    /// Formats an altitude/elevation in meters according to the current unit system
    /// - Parameter meters: Altitude in meters
    /// - Returns: Formatted string with appropriate unit
    static func formatAltitude(_ meters: Double) -> String {
        switch Config.unitSystem {
        case .metric:
            return String(format: "%.0fm", meters)
        case .imperial:
            let feet = meters * metersToFeet
            return String(format: "%.0fft", feet)
        }
    }

    /// Returns the altitude unit label
    static var altitudeUnit: String {
        switch Config.unitSystem {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }

    /// Converts meters to the current unit system's altitude value (without formatting)
    /// - Parameter meters: Altitude in meters
    /// - Returns: Altitude value in current unit system (m or ft)
    static func altitudeValue(_ meters: Double) -> Double {
        switch Config.unitSystem {
        case .metric:
            return meters
        case .imperial:
            return meters * metersToFeet
        }
    }

    // MARK: - Pace Formatting

    /// Formats pace (minutes per km or minutes per mile) from speed in m/s
    /// - Parameter metersPerSecond: Speed in meters per second
    /// - Returns: Formatted string like "5:30 /km" or "8:51 /mi", or "-" if speed is too slow
    static func formatPace(_ metersPerSecond: Double) -> String {
        // Avoid division by zero or extremely slow speeds
        guard metersPerSecond > 0.1 else { return "-" }

        let secondsPerMeter = 1.0 / metersPerSecond

        switch Config.unitSystem {
        case .metric:
            let secondsPerKm = secondsPerMeter * 1000.0
            let minutes = Int(secondsPerKm / 60)
            let seconds = Int(secondsPerKm.truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d /km", minutes, seconds)
        case .imperial:
            let secondsPerMile = secondsPerMeter / metersToMiles
            let minutes = Int(secondsPerMile / 60)
            let seconds = Int(secondsPerMile.truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d /mi", minutes, seconds)
        }
    }

    /// Returns the pace unit label
    static var paceUnit: String {
        switch Config.unitSystem {
        case .metric: return "/km"
        case .imperial: return "/mi"
        }
    }

    // MARK: - Temperature Formatting

    /// Formats a temperature in Celsius according to the current unit system
    /// - Parameter celsius: Temperature in Celsius
    /// - Returns: Formatted string with appropriate unit (°C or °F)
    static func formatTemperature(_ celsius: Double) -> String {
        switch Config.unitSystem {
        case .metric:
            return String(format: "%.1f°C", celsius)
        case .imperial:
            let fahrenheit = celsius * 9/5 + 32
            return String(format: "%.1f°F", fahrenheit)
        }
    }
}
