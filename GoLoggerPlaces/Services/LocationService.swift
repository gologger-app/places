import Foundation
import CoreLocation
import Combine

/// Service responsible for managing location tracking and trail recording
class LocationService: NSObject, ObservableObject {

    // MARK: - Configuration

    /// Toggle between continuous updates and distance-based updates
    /// - true: Get all GPS updates (best for testing, uses more battery)
    /// - false: Only update when moved significant distance (better for production)
    private static let useContinuousUpdates = false

    // MARK: - Published Properties

    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRecording: Bool = false
    @Published var recordedLocations: [CLLocation] = []
    @Published var currentDistance: Double = 0.0  // In meters
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private let geocoder = CLGeocoder()
    private var lastGeocodedLocation: CLLocation?
    private var recordingStartTime: Date?

    /// Minimum distance in meters before triggering a new geocoding request
    private static let geocodingDistanceThreshold: Double = 75

    // MARK: - Initialization

    override init() {
        self.locationManager = CLLocationManager()
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10  // Update every 10 meters moved
        // Only enable background updates when recording (configured in startRecordingTrail)
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// Request "When In Use" authorization for location services
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request "Always" authorization for background location tracking
    /// This should be called after "When In Use" has been granted
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Start updating user's current location
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            return
        }

        locationManager.startUpdatingLocation()
    }

    /// Stop updating user's current location
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// Start recording a trail
    func startRecordingTrail() {
        print("🎬 startRecordingTrail() called")
        print("🔐 Authorization status: \(authorizationStatus.rawValue)")

        // Log the actual permission status
        let statusString: String
        switch authorizationStatus {
        case .notDetermined: statusString = "Not Determined"
        case .restricted: statusString = "Restricted"
        case .denied: statusString = "Denied"
        case .authorizedAlways: statusString = "Always"
        case .authorizedWhenInUse: statusString = "When In Use"
        @unknown default: statusString = "Unknown"
        }
        print("🔐 Permission level: \(statusString)")

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission required to record trail"
            print("❌ Location permission not granted")
            return
        }

        // Clear any previous recording
        recordedLocations = []
        currentDistance = 0.0
        recordingStartTime = Date()
        isRecording = true

        // Configure for tracking during recording
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness  // Optimized for walking/running

        // Enable background updates only if we have "Always" authorization
        // Note: This requires "Location updates" background mode in Info.plist
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
        }

        if Self.useContinuousUpdates {
            locationManager.distanceFilter = kCLDistanceFilterNone  // Get all updates
            print("📊 Location tracking configured: accuracy=Best, distanceFilter=None (continuous), activityType=fitness")
        } else {
            locationManager.distanceFilter = 5  // Update every 5 meters
            print("📊 Location tracking configured: accuracy=Best, distanceFilter=5m, activityType=fitness")
        }

        locationManager.startUpdatingLocation()
        print("📡 Location updates started")

        // Capture current location immediately as the first point
        if let location = currentLocation {
            print("📍 Adding current location as first point")
            if location.horizontalAccuracy > 0 && location.horizontalAccuracy < 50 {
                recordedLocations.append(location)
                print("✅ First location added! accuracy=\(location.horizontalAccuracy)m")
            }
        }

        print("✅ Recording started, isRecording: \(isRecording)")
        errorMessage = nil
    }

    /// Stop recording the trail and return the recorded locations
    func stopRecordingTrail() -> [CLLocation] {
        print("🛑 stopRecordingTrail() called")
        print("📊 Total locations recorded: \(recordedLocations.count)")
        print("📏 Total distance: \(currentDistance)m")

        isRecording = false
        recordingStartTime = nil

        // Reset to normal tracking
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = false

        let locations = recordedLocations
        recordedLocations = []
        currentDistance = 0.0

        return locations
    }

    /// Get elapsed time since recording started
    var elapsedTime: TimeInterval {
        guard let startTime = recordingStartTime else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }

    /// Check if location services are enabled
    var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    /// Check if authorization is granted
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - Private Methods

    private func calculateDistance(from locations: [CLLocation]) -> Double {
        guard locations.count > 1 else { return 0 }

        var distance: Double = 0
        for i in 1..<locations.count {
            distance += locations[i].distance(from: locations[i-1])
        }
        return distance
    }

    /// Perform reverse geocoding to get address from coordinates
    private func reverseGeocodeLocation(_ location: CLLocation) {
        // Don't geocode if we already have a pending request
        guard !geocoder.isGeocoding else { return }

        // Check if we've moved enough distance from last geocoded location
        if let lastLocation = lastGeocodedLocation {
            let distance = location.distance(from: lastLocation)
            if distance < Self.geocodingDistanceThreshold {
                return  // Not far enough, skip geocoding
            }
        }

        // Perform reverse geocoding
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let error = error {
                // Silently handle geocoding errors (e.g., no network)
                // Don't update currentAddress, keep previous value or nil
                print("⚠️ Geocoding error: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                // Build address string from placemark components
                var addressComponents: [String] = []

                // Add street address (house number + street name)
                if let subThoroughfare = placemark.subThoroughfare, let thoroughfare = placemark.thoroughfare {
                    addressComponents.append("\(subThoroughfare) \(thoroughfare)")
                } else if let thoroughfare = placemark.thoroughfare {
                    addressComponents.append(thoroughfare)
                }

                // Add city
                if let locality = placemark.locality {
                    addressComponents.append(locality)
                }

                // Add state/province
                if let administrativeArea = placemark.administrativeArea {
                    addressComponents.append(administrativeArea)
                }

                // Add postal code
                if let postalCode = placemark.postalCode {
                    addressComponents.append(postalCode)
                }

                let address = addressComponents.joined(separator: ", ")
                DispatchQueue.main.async {
                    self.currentAddress = address.isEmpty ? nil : address
                    self.lastGeocodedLocation = location
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let timestamp = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .medium)
        print("📍 Location update received at \(timestamp): lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), accuracy=\(location.horizontalAccuracy)m, isRecording=\(isRecording)")

        // Update current location
        currentLocation = location

        // Attempt to reverse geocode location to get address
        reverseGeocodeLocation(location)

        // If recording, add to recorded locations and update distance
        if isRecording {
            print("🎙️ Recording is active, checking accuracy...")
            // Filter out inaccurate locations
            if location.horizontalAccuracy > 0 && location.horizontalAccuracy < 50 {
                recordedLocations.append(location)
                print("✅ Location added! Total points: \(recordedLocations.count)")

                // Update distance
                if recordedLocations.count > 1 {
                    let lastTwo = Array(recordedLocations.suffix(2))
                    let segmentDistance = lastTwo[1].distance(from: lastTwo[0])
                    currentDistance += segmentDistance
                    print("📏 Distance updated: +\(segmentDistance)m, total: \(currentDistance)m")
                }
            } else {
                print("⚠️ Location too inaccurate (\(location.horizontalAccuracy)m), skipping")
            }
        } else {
            print("ℹ️ Not recording, location update ignored")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location error: \(error.localizedDescription)"
        print("Location manager error: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            errorMessage = nil
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable in Settings."
        case .notDetermined:
            errorMessage = nil
        @unknown default:
            errorMessage = "Unknown authorization status"
        }
    }
}
