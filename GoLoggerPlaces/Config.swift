import Foundation

/// Unit system for displaying measurements
enum UnitSystem: String, Codable, CaseIterable {
    case metric
    case imperial

    var name: String {
        switch self {
        case .metric: return "Metric (km, m, km/h)"
        case .imperial: return "Imperial (mi, ft, mph)"
        }
    }
}

/// Application configuration constants
enum Config {

    // MARK: - Unit System Configuration

    /// UserDefaults key for storing the unit system preference
    private static let unitSystemDefaultsKey = "unitSystemPreference"

    /// Unit system for displaying speeds, distances, and altitudes
    /// Defaults to metric
    static var unitSystem: UnitSystem {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: unitSystemDefaultsKey),
                  let system = UnitSystem(rawValue: rawValue) else {
                return .metric
            }
            return system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: unitSystemDefaultsKey)
        }
    }

}
