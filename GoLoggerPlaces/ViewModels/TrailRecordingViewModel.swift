import Foundation
import CoreLocation
import Combine
import SwiftData

/// Temporary waypoint data stored during recording
struct TemporaryWaypoint {
    let label: String
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let visitTime: Date
}

/// ViewModel for managing trail recording
class TrailRecordingViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var totalDistance: Double = 0  // In meters
    @Published var pointCount: Int = 0
    @Published var waypointCount: Int = 0  // Number of waypoints added during recording
    @Published var currentCollections: [Collection] = []  // Exposed for filtering map during recording
    @Published var showingWaypointAdd: Bool = false  // For showing waypoint creation sheet
    @Published var showWaypointCreatedFeedback: Bool = false  // For showing confirmation
    @Published var suggestedWaypointLabel: String = ""  // Suggested label for new waypoint

    private let locationService: LocationService
    private let modelContext: ModelContext
    private let notificationService = NotificationService.shared
    private var timer: AnyCancellable?
    private var recordingStartTime: Date?
    private var totalPausedTime: TimeInterval = 0
    private var currentPauseStartTime: Date?
    private var pauseIntervals: [(Date, Date)] = []
    private var temporaryWaypoints: [TemporaryWaypoint] = []  // Store waypoints until trail is saved

    init(locationService: LocationService, modelContext: ModelContext) {
        self.locationService = locationService
        self.modelContext = modelContext
    }

    // MARK: - Recording Control

    /// Start recording a trail (optionally for collections)
    func startRecording(collections: [Collection]) {
        guard !isRecording else { return }

        currentCollections = collections
        recordingStartTime = Date()
        isRecording = true
        isPaused = false
        elapsedTime = 0
        totalDistance = 0
        pointCount = 0
        waypointCount = 0
        totalPausedTime = 0
        pauseIntervals = []
        temporaryWaypoints = []

        // Request notification permission and show notification
        Task {
            if !notificationService.isAuthorized {
                _ = await notificationService.requestAuthorization()
            }
            // Show initial recording notification
            let tripName = collections.first?.name ?? "Trail Recording"
            await MainActor.run {
                notificationService.showRecordingNotification(
                    tripName: tripName,
                    distance: 0,
                    duration: 0
                )
            }
        }

        // Start location tracking
        locationService.startRecordingTrail()

        // Start timer to update elapsed time
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsedTime()
            }
    }

    /// Pause recording
    func pauseRecording() {
        guard isRecording && !isPaused else { return }

        isPaused = true
        currentPauseStartTime = Date()

        // Stop location updates
        locationService.stopUpdatingLocation()

        // Update notification to show paused state
        updateNotification()
    }

    /// Resume recording
    func resumeRecording() {
        guard isRecording && isPaused else { return }

        isPaused = false

        // Calculate pause duration
        if let pauseStart = currentPauseStartTime {
            let pauseEnd = Date()
            let pauseDuration = pauseEnd.timeIntervalSince(pauseStart)
            totalPausedTime += pauseDuration
            pauseIntervals.append((pauseStart, pauseEnd))
            currentPauseStartTime = nil
        }

        // Resume location updates
        locationService.startUpdatingLocation()

        // Update notification to show resumed state
        updateNotification()
    }

    /// Stop recording and save the trail
    func stopRecording() -> Trail? {
        guard isRecording else { return nil }

        // If paused, finalize the pause
        if isPaused, let pauseStart = currentPauseStartTime {
            let pauseEnd = Date()
            totalPausedTime += pauseEnd.timeIntervalSince(pauseStart)
            pauseIntervals.append((pauseStart, pauseEnd))
        }

        // Stop tracking
        isRecording = false
        isPaused = false
        timer?.cancel()
        timer = nil

        // Clear recording notification
        notificationService.clearRecordingNotification()

        // Get recorded locations from location service
        let locations = locationService.stopRecordingTrail()

        guard !locations.isEmpty else {
            print("No locations recorded")
            resetState()
            return nil
        }

        // Create trail with recorded locations
        let dataService = DataService(modelContext: modelContext)
        let trail = dataService.createTrail(
            locations: locations,
            collections: currentCollections
        )

        // Create and attach waypoints to the trail
        for tempWaypoint in temporaryWaypoints {
            let waypoint = WayPoint(
                label: tempWaypoint.label,
                latitude: tempWaypoint.latitude,
                longitude: tempWaypoint.longitude,
                altitude: tempWaypoint.altitude,
                visitTime: tempWaypoint.visitTime
            )
            // Insert waypoint first
            modelContext.insert(waypoint)
            // Then append to trail - SwiftData will handle the inverse relationship
            trail.waypoints.append(waypoint)
        }

        // Save the waypoints with the trail
        do {
            try modelContext.save()
            print("✅ Successfully saved \(temporaryWaypoints.count) waypoints to trail")
        } catch {
            print("❌ Error saving waypoints: \(error)")
        }

        // Reset state
        resetState()

        return trail
    }

    private func resetState() {
        currentCollections = []
        recordingStartTime = nil
        elapsedTime = 0
        totalDistance = 0
        pointCount = 0
        waypointCount = 0
        totalPausedTime = 0
        currentPauseStartTime = nil
        pauseIntervals = []
        temporaryWaypoints = []
    }

    // MARK: - Private Methods

    private func updateElapsedTime() {
        guard let startTime = recordingStartTime else { return }

        // Calculate elapsed time excluding pauses
        let totalElapsed = Date().timeIntervalSince(startTime)
        var currentPauseDuration: TimeInterval = 0

        // If currently paused, include the ongoing pause duration
        if isPaused, let pauseStart = currentPauseStartTime {
            currentPauseDuration = Date().timeIntervalSince(pauseStart)
        }

        elapsedTime = totalElapsed - totalPausedTime - currentPauseDuration

        // Don't update stats if paused
        if !isPaused {
            // Also update distance and point count from location service
            totalDistance = locationService.currentDistance
            pointCount = locationService.recordedLocations.count

            // Update notification every 10 seconds to avoid too many updates
            if Int(elapsedTime) % 10 == 0 {
                updateNotification()
            }
        }
    }

    private func updateNotification() {
        let tripName = currentCollections.first?.name ?? "Trail Recording"
        notificationService.updateRecordingNotification(
            tripName: tripName,
            distance: totalDistance,
            duration: elapsedTime
        )
    }

    // MARK: - Waypoint Creation

    /// Generate a default label suggestion based on current time
    func generateDefaultWaypointLabel() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: Date())
        return "Waypoint \(timeString)"
    }

    /// Show waypoint creation sheet with suggested label
    func showWaypointCreationSheet() {
        guard locationService.currentLocation != nil else {
            print("Cannot create waypoint: location not available")
            return
        }

        // Generate suggested label
        suggestedWaypointLabel = generateDefaultWaypointLabel()
        showingWaypointAdd = true
    }

    /// Create a waypoint at the current location during recording with custom label
    func createWaypointWithLabel(_ label: String) {
        guard let location = locationService.currentLocation else {
            print("Cannot create waypoint: location not available")
            return
        }

        // Store temporary waypoint data - will be converted to WayPoint when trail is saved
        let tempWaypoint = TemporaryWaypoint(
            label: label.isEmpty ? generateDefaultWaypointLabel() : label,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            visitTime: Date()
        )
        temporaryWaypoints.append(tempWaypoint)

        waypointCount += 1
        print("✅ Created waypoint '\(tempWaypoint.label)' at current location (total: \(waypointCount))")

        // Show brief feedback
        showWaypointCreatedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showWaypointCreatedFeedback = false
        }
    }

    // MARK: - Computed Properties

    /// Formatted elapsed time string (HH:MM:SS or MM:SS)
    var elapsedTimeFormatted: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Formatted distance string
    var distanceFormatted: String {
        return MeasurementFormatter.formatDistance(totalDistance)
    }
}
