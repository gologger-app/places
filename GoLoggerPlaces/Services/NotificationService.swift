import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let recordingNotificationId = "recording_active"

    @Published var isAuthorized = false

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Permission Management

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Recording Notifications

    func showRecordingNotification(tripName: String, distance: Double, duration: TimeInterval) {
        // Ensure we have permission
        guard isAuthorized else {
            print("Notification not authorized")
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Recording Active"
        content.body = formatNotificationBody(tripName: tripName, distance: distance, duration: duration)
        content.sound = nil // Silent notification to avoid disturbing
        content.categoryIdentifier = "RECORDING_CATEGORY"
        content.interruptionLevel = .passive // Low priority, won't break through Focus modes

        // Create request with identifier so we can update it
        let request = UNNotificationRequest(
            identifier: recordingNotificationId,
            content: content,
            trigger: nil // Immediate delivery
        )

        // Schedule the notification
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling recording notification: \(error)")
            }
        }
    }

    func updateRecordingNotification(tripName: String, distance: Double, duration: TimeInterval) {
        // This will replace the existing notification with the same ID
        showRecordingNotification(tripName: tripName, distance: distance, duration: duration)
    }

    func clearRecordingNotification() {
        // Remove the recording notification
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [recordingNotificationId])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [recordingNotificationId])
    }

    // MARK: - Helper Methods

    private func formatNotificationBody(tripName: String, distance: Double, duration: TimeInterval) -> String {
        let distanceKm = distance / 1000.0
        let distanceStr = String(format: "%.2f km", distanceKm)
        let durationStr = formatDuration(duration)

        return "\(tripName) • \(distanceStr) • \(durationStr)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
