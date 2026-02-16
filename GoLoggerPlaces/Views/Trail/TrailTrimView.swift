import SwiftUI
import SwiftData
import CoreLocation
import MapKit

/// View for trimming the start and end of a trail
struct TrailTrimView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trail: Trail
    let onTrimComplete: () -> Void

    // Slider values (update immediately)
    @State private var startSliderValue: Double = 0
    @State private var endSliderValue: Double = 0

    // Actual trim indices (debounced)
    @State private var startTrimIndex: Int = 0
    @State private var endTrimIndex: Int = 0

    @State private var showConfirmAlert = false
    @State private var updateTask: Task<Void, Never>?

    // Map state
    @State private var mapRegion: MKCoordinateRegion
    @State private var mapHeading: Double = 0
    @State private var mapSpan: MKCoordinateSpan

    init(trail: Trail, onTrimComplete: @escaping () -> Void) {
        self.trail = trail
        self.onTrimComplete = onTrimComplete

        // Initialize map region
        let region = Self.calculateRegion(for: trail)
        _mapRegion = State(initialValue: region)
        _mapSpan = State(initialValue: region.span)
    }

    private var sortedPoints: [TrailPoint] {
        trail.points.sorted { $0.timestamp < $1.timestamp }
    }

    private var maxTrimIndex: Int {
        max(0, sortedPoints.count - 1)
    }

    private var remainingPoints: Int {
        max(0, sortedPoints.count - startTrimIndex - endTrimIndex)
    }

    private var trimmedPoints: ArraySlice<TrailPoint> {
        guard remainingPoints > 0 else {
            return []
        }
        let endIndex = sortedPoints.count - endTrimIndex
        return sortedPoints[startTrimIndex..<endIndex]
    }

    private var trimmedLocations: [CLLocation] {
        trimmedPoints.map { point in
            CLLocation(
                coordinate: point.coordinate,
                altitude: point.altitude ?? 0,
                horizontalAccuracy: point.horizontalAccuracy ?? 0,
                verticalAccuracy: -1,
                timestamp: point.timestamp
            )
        }
    }

    private var trailMarkers: [TrailMarkerAnnotation] {
        var markers: [TrailMarkerAnnotation] = []

        // Add start marker for trimmed trail
        if let firstPoint = trimmedPoints.first {
            markers.append(TrailMarkerAnnotation(
                coordinate: firstPoint.coordinate,
                type: .start
            ))
        }

        // Add end marker for trimmed trail
        if let lastPoint = trimmedPoints.last {
            markers.append(TrailMarkerAnnotation(
                coordinate: lastPoint.coordinate,
                type: .end
            ))
        }

        return markers
    }

    private var newDistance: Double {
        guard trimmedPoints.count > 1 else { return 0 }

        var distance: Double = 0
        let pointsArray = Array(trimmedPoints)
        for i in 1..<pointsArray.count {
            let previousLocation = CLLocation(
                latitude: pointsArray[i-1].latitude,
                longitude: pointsArray[i-1].longitude
            )
            let currentLocation = CLLocation(
                latitude: pointsArray[i].latitude,
                longitude: pointsArray[i].longitude
            )
            distance += currentLocation.distance(from: previousLocation)
        }
        return distance
    }

    private var newDuration: TimeInterval {
        guard let first = trimmedPoints.first,
              let last = trimmedPoints.last else {
            return 0
        }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    private var newDistanceFormatted: String {
        return MeasurementFormatter.formatDistance(newDistance)
    }

    private var newDurationFormatted: String {
        let hours = Int(newDuration) / 3600
        let minutes = (Int(newDuration) % 3600) / 60
        let seconds = Int(newDuration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private var startTimeFormatted: String {
        guard let firstPoint = trimmedPoints.first else {
            return "N/A"
        }
        return firstPoint.timestamp.formatted(date: .abbreviated, time: .shortened)
    }

    private var endTimeFormatted: String {
        guard let lastPoint = trimmedPoints.last else {
            return "N/A"
        }
        return lastPoint.timestamp.formatted(date: .abbreviated, time: .shortened)
    }

    private var canTrim: Bool {
        remainingPoints >= 2
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Info section
                    infoSection

                    // Map preview
                    mapPreviewSection

                    // Trim controls
                    trimControlsSection

                    // Preview section
                    previewSection

                    // Warning if too few points
                    if !canTrim {
                        warningSection
                    }
                }
                .padding()
            }
            .navigationTitle("Trim Trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Trim") {
                        showConfirmAlert = true
                    }
                    .disabled(!canTrim)
                    .fontWeight(.semibold)
                }
            }
            .alert("Trim Trail?", isPresented: $showConfirmAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Trim", role: .destructive) {
                    performTrim()
                }
            } message: {
                Text("This will permanently remove \(startTrimIndex + endTrimIndex) points from the trail. This action cannot be undone.")
            }
        }
    }

    // MARK: - Subviews

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Trim Trail Endpoints", systemImage: "scissors")
                .font(.headline)

            Text("Remove unwanted points from the start and end of your trail. This is useful if you forgot to stop recording.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Preview")
                .font(.headline)

            MapView(
                region: $mapRegion,
                venues: [],
                trails: [],
                recordingLocations: trimmedLocations,
                trailMarkers: trailMarkers,
                mapHeading: $mapHeading,
                mapSpan: $mapSpan
            )
            .frame(height: 250)
            .cornerRadius(12)
            .allowsHitTesting(true)
        }
    }

    private var trimControlsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Trim Controls")
                .font(.headline)

            // Start trim slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Trim Start", systemImage: "arrowtriangle.right.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)

                    Spacer()

                    Text("\(Int(startSliderValue)) points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 12) {
                    Button {
                        startSliderValue = max(0, startSliderValue - 1)
                        debouncedUpdate()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(startSliderValue > 0 ? .blue : .gray.opacity(0.3))
                    }
                    .disabled(startSliderValue <= 0)

                    Slider(value: $startSliderValue, in: 0...Double(maxTrimIndex - Int(endSliderValue)), step: 1)
                        .tint(.blue)
                        .onChange(of: startSliderValue) { oldValue, newValue in
                            debouncedUpdate()
                        }

                    Button {
                        let maxValue = Double(maxTrimIndex - Int(endSliderValue))
                        startSliderValue = min(maxValue, startSliderValue + 1)
                        debouncedUpdate()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(startSliderValue < Double(maxTrimIndex - Int(endSliderValue)) ? .blue : .gray.opacity(0.3))
                    }
                    .disabled(startSliderValue >= Double(maxTrimIndex - Int(endSliderValue)))
                }

                if Int(startSliderValue) > 0, let firstTrimmed = sortedPoints.first {
                    let estimatedTime = firstTrimmed.timestamp.addingTimeInterval(TimeInterval(Int(startSliderValue)))
                    Text("New start: \(estimatedTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)

            // End trim slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Trim End", systemImage: "arrowtriangle.left.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)

                    Spacer()

                    Text("\(Int(endSliderValue)) points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 12) {
                    Button {
                        endSliderValue = max(0, endSliderValue - 1)
                        debouncedUpdate()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(endSliderValue > 0 ? .orange : .gray.opacity(0.3))
                    }
                    .disabled(endSliderValue <= 0)

                    Slider(value: $endSliderValue, in: 0...Double(maxTrimIndex - Int(startSliderValue)), step: 1)
                        .tint(.orange)
                        .onChange(of: endSliderValue) { oldValue, newValue in
                            debouncedUpdate()
                        }

                    Button {
                        let maxValue = Double(maxTrimIndex - Int(startSliderValue))
                        endSliderValue = min(maxValue, endSliderValue + 1)
                        debouncedUpdate()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(endSliderValue < Double(maxTrimIndex - Int(startSliderValue)) ? .orange : .gray.opacity(0.3))
                    }
                    .disabled(endSliderValue >= Double(maxTrimIndex - Int(startSliderValue)))
                }

                if Int(endSliderValue) > 0, let lastTrimmed = sortedPoints.last {
                    let estimatedTime = lastTrimmed.timestamp.addingTimeInterval(-TimeInterval(Int(endSliderValue)))
                    Text("New end: \(estimatedTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)

            VStack(spacing: 12) {
                // Points comparison
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Points")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("\(sortedPoints.count)")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("\(remainingPoints)")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(remainingPoints < 2 ? .red : .primary)
                        }
                    }

                    Spacer()

                    if startTrimIndex + endTrimIndex > 0 {
                        Text("-\(startTrimIndex + endTrimIndex)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red)
                            .cornerRadius(8)
                    }
                }

                Divider()

                // Distance comparison
                ComparisonRow(
                    label: "Distance",
                    oldValue: trail.distanceFormatted,
                    newValue: newDistanceFormatted,
                    icon: "figure.walk"
                )

                Divider()

                // Duration comparison
                ComparisonRow(
                    label: "Duration",
                    oldValue: trail.durationFormatted,
                    newValue: newDurationFormatted,
                    icon: "clock"
                )

                Divider()

                // Time range
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                        Text("Time Range")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Start:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(startTimeFormatted)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        HStack(spacing: 4) {
                            Text("End:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(endTimeFormatted)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }

    private var warningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Too Few Points")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("A trail must have at least 2 points. Reduce the amount you're trimming.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func debouncedUpdate() {
        // Cancel any existing update task
        updateTask?.cancel()

        // Create a new task with a delay
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard !Task.isCancelled else { return }

            await MainActor.run {
                startTrimIndex = Int(startSliderValue)
                endTrimIndex = Int(endSliderValue)
            }
        }
    }

    private static func calculateRegion(for trail: Trail) -> MKCoordinateRegion {
        let coordinates = trail.points.map { $0.coordinate }
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let minLat = coordinates.map { $0.latitude }.min()!
        let maxLat = coordinates.map { $0.latitude }.max()!
        let minLon = coordinates.map { $0.longitude }.min()!
        let maxLon = coordinates.map { $0.longitude }.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private func performTrim() {
        guard canTrim else { return }

        // Get the points to keep
        let pointsToKeep = Array(trimmedPoints)

        // Get the points to remove
        let pointsToRemove = sortedPoints.filter { point in
            !pointsToKeep.contains { $0.id == point.id }
        }

        // Remove the trimmed points
        for point in pointsToRemove {
            modelContext.delete(point)
        }

        // Update trail edit date
        trail.editDate = Date()

        // Save changes
        try? modelContext.save()

        // Notify completion and dismiss
        onTrimComplete()
        dismiss()
    }
}

// MARK: - Supporting Views

struct ComparisonRow: View {
    let label: String
    let oldValue: String
    let newValue: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(oldValue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(newValue)
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
    }
}

#Preview {
    TrailTrimView(trail: Trail(), onTrimComplete: {})
        .modelContainer(for: [Trail.self, TrailPoint.self], inMemory: true)
}
