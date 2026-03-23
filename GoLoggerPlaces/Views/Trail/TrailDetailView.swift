import SwiftUI
import SwiftData
import MapKit
import Charts
import os.log

private let performanceLog = OSLog(subsystem: "app.gologger.places", category: "TrailDetailView")

/// Helper to measure performance
private func measureTime<T>(_ label: String, block: () -> T) -> T {
    let start = Date()
    let result = block()
    let elapsed = Date().timeIntervalSince(start) * 1000
    os_log("⏱️ %@: %.2f ms", log: performanceLog, type: .debug, label, elapsed)
    return result
}

/// Detailed view of a trail
struct TrailDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var trail: Trail
    @Query private var collections: [Collection]

    @State private var showDeleteAlert = false
    @State private var showFullScreenMap = false
    @State private var showCollectionSheet = false
    @State private var showEditSheet = false
    @State private var showingLinkForm = false
    @State private var showJSONExport = false
    @State private var editingLink: Link?
    @State private var selectedAltitudeTime: Double?
    @State private var selectedSpeedTime: Double?
    @State private var selectedAccuracyTime: Double?
    @State private var mapColorMode: MapColorMode = .simple
    @State private var sampledPointsCache: [TrailPoint] = []
    @State private var showAltitudeChart = false
    @State private var showSpeedChart = false
    @State private var showAccuracyChart = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    // Static region for map preview - calculated once, doesn't need updates
    private var mapRegion: MKCoordinateRegion {
        Self.calculateRegion(for: trail)
    }

    // Trail color derived from trail.hexColor - updates when color changes
    private var trailColor: Color {
        Color(hex: trail.hexColor) ?? .blue
    }

    init(trail: Trail) {
        os_log("🚀 TrailDetailView.init started", log: performanceLog, type: .debug)
        self.trail = trail

        // Compute sampled points once during initialization
        _sampledPointsCache = State(initialValue: Self.computeSampledPoints(from: trail.points))
        os_log("✅ TrailDetailView.init completed", log: performanceLog, type: .debug)
    }

    var body: some View {
        os_log("📱 TrailDetailView.body rendering", log: performanceLog, type: .debug)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map Preview
                mapPreview

                // Altitude Chart
                altitudeChartSection

                // Speed Chart
                speedChartSection

                // Accuracy Chart
                accuracyChartSection

                // Statistics
                statisticsSection

                // Waypoints
                waypointsSection

                // Trail Information
                detailsSection

                // Collections
                collectionsSection

                // Links
                linksSection
            }
            .padding()
        }
        .navigationTitle(trail.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportToFile()
                    } label: {
                        Label("Export Trail", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Trail", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Trail?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTrail()
            }
        } message: {
            Text("This trail will be permanently deleted from the trip.")
        }
        .sheet(isPresented: $showFullScreenMap) {
            FullScreenTrailMapView(trail: trail, region: mapRegion, trailMarkers: trailMarkers, trailColor: trailColor, sampledPoints: sampledPointsCache)
        }
        .sheet(isPresented: $showCollectionSheet) {
            NavigationStack {
                CollectionSelectionSheet(
                    selectedCollections: trail.collections,
                    availableCollections: collections,
                    onSave: { selected in
                        updateCollections(selected)
                    }
                )
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                TrailEditView(trail: trail)
            }
        }
        .sheet(isPresented: $showingLinkForm) {
            LinkFormView(link: editingLink) { savedLink in
                if editingLink == nil {
                    // Adding new link
                    trail.addLink(savedLink)
                    modelContext.insert(savedLink)
                }
                // If editing, changes are already applied to the link object
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showJSONExport) {
            JSONExportPreviewSheet(jsonString: trailJSONExport)
        }
        .sheet(isPresented: $showAltitudeChart) {
            NavigationStack {
                if let altData = altitudeChartData {
                    AltitudeChartSheet(
                        trail: trail,
                        altitudeChartData: altData,
                        selectedAltitudeTime: $selectedAltitudeTime
                    )
                }
            }
        }
        .sheet(isPresented: $showSpeedChart) {
            NavigationStack {
                SpeedChartSheet(
                    trail: trail,
                    speedChartData: speedChartData,
                    selectedSpeedTime: $selectedSpeedTime
                )
            }
        }
        .sheet(isPresented: $showAccuracyChart) {
            NavigationStack {
                if let accData = accuracyChartData {
                    AccuracyChartSheet(
                        trail: trail,
                        accuracyChartData: accData,
                        selectedAccuracyTime: $selectedAccuracyTime
                    )
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Subviews

    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)

            ZStack(alignment: .topTrailing) {
                // Simple map preview with trail polyline in trail color
                let sortedPoints = sampledPointsCache.sorted(by: { $0.timestamp < $1.timestamp })
                let pointsWithAltitude = sortedPoints.filter { $0.altitude != nil }
                Map(initialPosition: .region(mapRegion)) {
                    // Trail polyline
                    MapPolyline(coordinates: sortedPoints.map { $0.coordinate })
                        .stroke(trailColor, lineWidth: 3)

                    // Start marker
                    if let firstPoint = sortedPoints.first {
                        Annotation("Start", coordinate: firstPoint.coordinate) {
                            Circle()
                                .fill(.green)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }

                    // End marker
                    if let lastPoint = sortedPoints.last {
                        Annotation("End", coordinate: lastPoint.coordinate) {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }

                    // Highest altitude marker
                    if let highestPoint = pointsWithAltitude.max(by: { $0.altitude! < $1.altitude! }) {
                        Annotation("", coordinate: highestPoint.coordinate) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                    .background(Circle().fill(.white).padding(-4))
                                Text(MeasurementFormatter.formatAltitude(highestPoint.altitude!))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Lowest altitude marker
                    if let lowestPoint = pointsWithAltitude.min(by: { $0.altitude! < $1.altitude! }) {
                        Annotation("", coordinate: lowestPoint.coordinate) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                    .background(Circle().fill(.white).padding(-4))
                                Text(MeasurementFormatter.formatAltitude(lowestPoint.altitude!))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Waypoint markers
                    ForEach(trail.waypoints) { waypoint in
                        Annotation(waypoint.label, coordinate: waypoint.coordinate) {
                            VStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                                    .background(Circle().fill(.white).padding(-4))
                                Text(waypoint.label)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.purple)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .frame(height: 250)
                .cornerRadius(12)
                .allowsHitTesting(false)

                // Full screen button
                Button {
                    showFullScreenMap = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(12)
            }
        }
    }

    private var colorLegend: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                // Min value
                if mapColorMode == .speed {
                    Text(minSpeedFormatted)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                } else {
                    Text(minAltitudeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: mapColorMode == .speed ?
                                [.green, .yellow, .orange, .red] :
                                [.blue, .cyan, .green, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60, height: 8)
                    .cornerRadius(4)

                // Max value
                if mapColorMode == .speed {
                    Text(maxSpeedFormatted)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                } else {
                    Text(maxAltitudeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
    }

    private var chartButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Altitude Chart Button - show if trail has altitude data
                if hasAltitudeData {
                    Button(action: { showAltitudeChart = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.blue)
                            Text("Altitude")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                // Speed Chart Button - always show if we have data points
                if trail.pointCount > 1 {
                    Button(action: { showSpeedChart = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gauge")
                                .foregroundStyle(.green)
                            Text("Speed")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Accuracy Chart Button - show if trail has accuracy data
            if hasAccuracyData {
                Button(action: { showAccuracyChart = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.magnifyingglass")
                            .foregroundStyle(.orange)
                        Text("GPS Accuracy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Check if trail has altitude data without computing the full chart
    private var hasAltitudeData: Bool {
        guard trail.startTime != nil else { return false }
        return sampledPointsCache.contains { $0.altitude != nil }
    }

    /// Check if trail has accuracy data without computing the full chart
    private var hasAccuracyData: Bool {
        guard trail.startTime != nil else { return false }
        return sampledPointsCache.contains { $0.horizontalAccuracy != nil && $0.horizontalAccuracy! > 0 }
    }

    // Computed properties for min/max values - only compute when needed by map legend
    private var minSpeedFormatted: String {
        if mapColorMode == .speed {
            return measureTime("minSpeedFormatted calculation") {
                let speeds = speedChartData.map { $0.value }
                if let minSpeed = speeds.min() {
                    return String(format: "%.0f", minSpeed)
                }
                return "0"
            }
        }
        return "0"
    }

    private var maxSpeedFormatted: String {
        if mapColorMode == .speed {
            return measureTime("maxSpeedFormatted calculation") {
                let speeds = speedChartData.map { $0.value }
                if let maxSpeed = speeds.max() {
                    return String(format: "%.0f", maxSpeed)
                }
                return "0"
            }
        }
        return "0"
    }

    private var minAltitudeFormatted: String {
        if mapColorMode == .altitude {
            return measureTime("minAltitudeFormatted calculation") {
                if let altitudes = altitudeChartData?.map({ $0.value }),
                   let minAlt = altitudes.min() {
                    return String(format: "%.0f", minAlt)
                }
                return "0"
            }
        }
        return "0"
    }

    private var maxAltitudeFormatted: String {
        if mapColorMode == .altitude {
            return measureTime("maxAltitudeFormatted calculation") {
                if let altitudes = altitudeChartData?.map({ $0.value }),
                   let maxAlt = altitudes.max() {
                    return String(format: "%.0f", maxAlt)
                }
                return "0"
            }
        }
        return "0"
    }

    private var trailMarkers: [TrailMarkerAnnotation] {
        var markers: [TrailMarkerAnnotation] = []

        // Add start marker
        if let firstPoint = trail.points.sorted(by: { $0.timestamp < $1.timestamp }).first {
            markers.append(TrailMarkerAnnotation(
                coordinate: firstPoint.coordinate,
                type: .start
            ))
        }

        // Add end marker
        if let lastPoint = trail.points.sorted(by: { $0.timestamp < $1.timestamp }).last {
            markers.append(TrailMarkerAnnotation(
                coordinate: lastPoint.coordinate,
                type: .end
            ))
        }

        return markers
    }

    @ViewBuilder
    private var altitudeChartSection: some View {
        if let altitudeData = altitudeChartData, !altitudeData.isEmpty {
            let minAltitude = altitudeData.map { $0.value }.min() ?? 0
            let maxAltitude = altitudeData.map { $0.value }.max() ?? 100
            let range = maxAltitude - minAltitude
            let padding = max(range * 0.1, 5) // 10% padding or at least 5 meters

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Altitude Over Time")
                        .font(.headline)

                    Spacer()

                    // Show min/max values
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("↑ \(String(format: "%.0f", maxAltitude)) \(MeasurementFormatter.altitudeUnit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("↓ \(String(format: "%.0f", minAltitude)) \(MeasurementFormatter.altitudeUnit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Chart(altitudeData) { point in
                    LineMark(
                        x: .value("Time", point.elapsedTime),
                        y: .value("Altitude", point.value)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.elapsedTime),
                        y: .value("Altitude", point.value)
                    )
                    .foregroundStyle(.blue.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)

                    if let selectedTime = selectedAltitudeTime,
                       let selectedPoint = altitudeData.min(by: { abs($0.elapsedTime - selectedTime) < abs($1.elapsedTime - selectedTime) }) {
                        RuleMark(x: .value("Time", selectedPoint.elapsedTime))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selectedPoint.formattedTime)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.1f m", selectedPoint.value))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            }
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: (minAltitude - padding)...(maxAltitude + padding))
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .stride(by: calculateOptimalXAxisStride(dataPoints: altitudeData))) { value in
                        if let seconds = value.as(Double.self) {
                            let minutes = Int(seconds) / 60
                            let secs = Int(seconds) % 60
                            AxisValueLabel {
                                Text(String(format: "%d:%02d", minutes, secs))
                                    .font(.caption2)
                            }
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let altitude = value.as(Double.self) {
                                Text(String(format: "%.0f", altitude))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedAltitudeTime)
//                .chartPlotStyle { plotArea in
//                    plotArea.padding(.top, 60)
//                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private var speedChartSection: some View {
        if !speedChartData.isEmpty {
            let minSpeed = speedChartData.map { $0.value }.min() ?? 0
            let maxSpeed = speedChartData.map { $0.value }.max() ?? 10
            let range = maxSpeed - minSpeed
            let padding = max(range * 0.1, 1) // 10% padding or at least 1 km/h

            VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speed Over Time")
                    .font(.headline)

                Spacer()

                // Show min/max values
                VStack(alignment: .trailing, spacing: 2) {
                    Text("↑ \(String(format: "%.1f", maxSpeed)) \(MeasurementFormatter.speedUnit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("↓ \(String(format: "%.1f", minSpeed)) \(MeasurementFormatter.speedUnit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Chart(speedChartData) { point in
                LineMark(
                    x: .value("Time", point.elapsedTime),
                    y: .value("Speed", point.value)
                )
                .foregroundStyle(.green.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.elapsedTime),
                    y: .value("Speed", point.value)
                )
                .foregroundStyle(.green.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)

                if let selectedTime = selectedSpeedTime,
                   let selectedPoint = speedChartData.min(by: { abs($0.elapsedTime - selectedTime) < abs($1.elapsedTime - selectedTime) }) {
                    RuleMark(x: .value("Time", selectedPoint.elapsedTime))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .annotation(position: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedPoint.formattedTime)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(String(format: "%.1f", selectedPoint.value)) \(MeasurementFormatter.speedUnit)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: (minSpeed - padding)...(maxSpeed + padding))
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: calculateOptimalXAxisStride(dataPoints: speedChartData))) { value in
                    if let seconds = value.as(Double.self) {
                        let minutes = Int(seconds) / 60
                        let secs = Int(seconds) % 60
                        AxisValueLabel {
                            Text(String(format: "%d:%02d", minutes, secs))
                                .font(.caption2)
                        }
                        AxisGridLine()
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let speed = value.as(Double.self) {
                            Text(String(format: "%.0f", speed))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedSpeedTime)
//            .chartPlotStyle { plotArea in
//                plotArea.padding(.top, 60)
//            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private var accuracyChartSection: some View {
        if let accuracyData = accuracyChartData, !accuracyData.isEmpty {
            let minAccuracy = accuracyData.map { $0.value }.min() ?? 0
            let maxAccuracy = accuracyData.map { $0.value }.max() ?? 50
            let range = maxAccuracy - minAccuracy
            let padding = max(range * 0.1, 5)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("GPS Accuracy Over Time")
                        .font(.headline)

                    Spacer()

                    // Info button with explanation
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Lower values indicate better GPS accuracy")
                }

                Chart(accuracyData) { point in
                    LineMark(
                        x: .value("Time", point.elapsedTime),
                        y: .value("Accuracy", point.value)
                    )
                    .foregroundStyle(.orange.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.elapsedTime),
                        y: .value("Accuracy", point.value)
                    )
                    .foregroundStyle(.orange.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)

                    if let selectedTime = selectedAccuracyTime,
                       let selectedPoint = accuracyData.min(by: { abs($0.elapsedTime - selectedTime) < abs($1.elapsedTime - selectedTime) }) {
                        RuleMark(x: .value("Time", selectedPoint.elapsedTime))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selectedPoint.formattedTime)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "±%.1f m", selectedPoint.value))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            }
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: (minAccuracy - padding)...(maxAccuracy + padding))
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .stride(by: calculateOptimalXAxisStride(dataPoints: accuracyData))) { value in
                        if let seconds = value.as(Double.self) {
                            let minutes = Int(seconds) / 60
                            let secs = Int(seconds) % 60
                            AxisValueLabel {
                                Text(String(format: "%d:%02d", minutes, secs))
                                    .font(.caption2)
                            }
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let accuracy = value.as(Double.self) {
                                Text(String(format: "%.0f", accuracy))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedAccuracyTime)
//                .chartPlotStyle { plotArea in
//                    plotArea.padding(.top, 60)
//                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                // Accuracy summary
                HStack(spacing: 16) {
                    AccuracySummaryCard(
                        label: "Average",
                        value: String(format: "±%.1f m", accuracyData.map { $0.value }.reduce(0, +) / Double(accuracyData.count)),
                        icon: "target"
                    )

                    AccuracySummaryCard(
                        label: "Best",
                        value: String(format: "±%.1f m", minAccuracy),
                        icon: "checkmark.circle.fill"
                    )

                    AccuracySummaryCard(
                        label: "Worst",
                        value: String(format: "±%.1f m", maxAccuracy),
                        icon: "exclamationmark.triangle.fill"
                    )
                }
            }
        }
    }


    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatCard(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    label: "Distance",
                    value: trail.distanceFormatted,
                    color: .blue
                )

                StatCard(
                    icon: "clock",
                    label: "Duration",
                    value: trail.durationFormatted,
                    color: .green
                )
            }

            HStack(spacing: 20) {
                StatCard(
                    icon: "location.fill",
                    label: "Points",
                    value: "\(trail.pointCount)",
                    color: .orange
                )

                StatCard(
                    icon: "mappin.circle.fill",
                    label: "Waypoints",
                    value: "\(trail.waypoints.count)",
                    color: .cyan
                )
            }

            if let avgSpeed = averageSpeed {
                HStack(spacing: 20) {
                    StatCard(
                        icon: "speedometer",
                        label: "Avg Speed",
                        value: avgSpeed,
                        color: .purple
                    )

                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var waypointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Waypoints")
                    .font(.headline)

                Spacer()

                Text("\(trail.waypoints.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if trail.waypoints.isEmpty {
                Text("No waypoints recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(trail.waypoints.sorted(by: { $0.visitTime < $1.visitTime })) { waypoint in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(waypoint.label)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    Text(waypoint.visitTime.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let altitude = waypoint.altitude {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(MeasurementFormatter.formatAltitude(altitude))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("altitude")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }

                            PhotoStripView(
                                photos: waypoint.photos,
                                onAdd: { image in addPhoto(image, to: waypoint) },
                                onDelete: { photo in deletePhoto(photo) }
                            )
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 12) {
                // Notes
                if let notes = trail.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.leading, 32)
                    }
                    .padding(.bottom, 4)
                }

                // Addresses
                if let startAddress = trail.startAddress {
                    DetailRow(
                        label: "Start Location",
                        value: startAddress,
                        icon: "location.circle.fill"
                    )
                }

                if let endAddress = trail.endAddress {
                    DetailRow(
                        label: "End Location",
                        value: endAddress,
                        icon: "mappin.circle.fill"
                    )
                }

                if let startTime = trail.startTime {
                    DetailRow(
                        label: "Start Time",
                        value: startTime.formatted(date: .abbreviated, time: .shortened),
                        icon: "clock.arrow.circlepath"
                    )
                }

                if let endTime = trail.endTime {
                    DetailRow(
                        label: "End Time",
                        value: endTime.formatted(date: .abbreviated, time: .shortened),
                        icon: "flag.checkered"
                    )
                }

                DetailRow(
                    label: "Total Points",
                    value: "\(trail.pointCount) locations",
                    icon: "map"
                )

                if let elevation = elevationGain {
                    DetailRow(
                        label: "Elevation Gain",
                        value: elevation,
                        icon: "arrow.up.right"
                    )
                }

                Button {
                    showJSONExport = true
                } label: {
                    HStack(alignment: .top) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("JSON Export Size")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(trail.estimatedJSONExportSize)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Collections")
                    .font(.headline)

                Spacer()

                Button(action: { showCollectionSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }

            if trail.collections.isEmpty {
                Text("Not in any collections")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(trail.collections) { collection in
                        NavigationLink(value: TrailNavigation.collection(collection)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)

                                Text(collection.name)
                                    .font(.body)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Links")
                    .font(.headline)

                Spacer()

                Button {
                    editingLink = nil
                    showingLinkForm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }

            if trail.links.isEmpty {
                Text("No links yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(trail.links) { link in
                        Button {
                            if let validURL = link.validURL {
                                UIApplication.shared.open(validURL)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(link.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    if let url = link.url, !url.isEmpty {
                                        Text(url)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                editingLink = link
                                showingLinkForm = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteLink(link)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var averageSpeed: String? {
        guard let distance = trail.totalDistance,
              let duration = trail.actualDuration,
              duration > 0 else {
            return nil
        }

        let speedMps = distance / duration  // meters per second
        return MeasurementFormatter.formatSpeed(speedMps)
    }

    private var elevationGain: String? {
        // Sort points by timestamp and extract altitudes
        let sortedPoints = trail.points.sorted { $0.timestamp < $1.timestamp }
        let pointsWithAltitude = sortedPoints.compactMap { $0.altitude }
        guard pointsWithAltitude.count > 1 else { return nil }

        var totalGain: Double = 0
        for i in 1..<pointsWithAltitude.count {
            let diff = pointsWithAltitude[i] - pointsWithAltitude[i-1]
            if diff > 0 {
                totalGain += diff
            }
        }

        if totalGain > 0 {
            return MeasurementFormatter.formatAltitude(totalGain)
        }
        return nil
    }

    /// Uniformly sampled points for chart rendering (max 1000 points)
    /// Cached during init to avoid redundant calculations
    private var sampledPoints: [TrailPoint] {
        sampledPointsCache
    }

    /// Static helper to compute sampled points
    private static func computeSampledPoints(from points: [TrailPoint]) -> [TrailPoint] {
        return measureTime("sampledPoints calculation") {
            guard points.count > 1000 else { return points }

            let step = Int(ceil(Double(points.count) / 1000.0))
            var sampled: [TrailPoint] = []

            for i in stride(from: 0, to: points.count, by: step) {
                sampled.append(points[i])
            }

            // Always include the last point if it wasn't already sampled
            if let last = points.last, sampled.last?.id != last.id {
                sampled.append(last)
            }

            return sampled
        }
    }

    private var altitudeChartData: [ChartDataPoint]? {
        return measureTime("altitudeChartData calculation") {
            guard let startTime = trail.startTime else { return nil }

            let pointsWithAltitude = sampledPoints.filter { $0.altitude != nil }
            guard pointsWithAltitude.count > 1 else { return nil }

            let dataPoints = pointsWithAltitude.map { point in
                let elapsedTime = point.timestamp.timeIntervalSince(startTime)
                let altitudeValue = MeasurementFormatter.altitudeValue(point.altitude!)
                return ChartDataPoint(elapsedTime: elapsedTime, value: altitudeValue)
            }

            return dataPoints.sorted { $0.elapsedTime < $1.elapsedTime }
        }
    }

    private var accuracyChartData: [ChartDataPoint]? {
        return measureTime("accuracyChartData calculation") {
            guard let startTime = trail.startTime else { return nil }

            let pointsWithAccuracy = sampledPoints.filter { $0.horizontalAccuracy != nil && $0.horizontalAccuracy! > 0 }
            guard pointsWithAccuracy.count > 1 else { return nil }

            let dataPoints = pointsWithAccuracy.map { point in
                let elapsedTime = point.timestamp.timeIntervalSince(startTime)
                return ChartDataPoint(elapsedTime: elapsedTime, value: point.horizontalAccuracy!)
            }

            return dataPoints.sorted { $0.elapsedTime < $1.elapsedTime }
        }
    }

    private var speedChartData: [ChartDataPoint] {
        return measureTime("speedChartData calculation") {
            guard let startTime = trail.startTime,
                  sampledPoints.count > 1 else { return [] }

            var dataPoints: [ChartDataPoint] = []
            let windowSize = 5  // Smooth over 5 points

            for i in 1..<sampledPoints.count {
                let currentPoint = sampledPoints[i]
                let previousPoint = sampledPoints[i - 1]

                // Create CLLocation objects for distance calculation
                let currentLocation = CLLocation(
                    latitude: currentPoint.latitude,
                    longitude: currentPoint.longitude
                )
                let previousLocation = CLLocation(
                    latitude: previousPoint.latitude,
                    longitude: previousPoint.longitude
                )

                // Calculate instantaneous speed
                let distance = currentLocation.distance(from: previousLocation)
                let timeDiff = currentPoint.timestamp.timeIntervalSince(previousPoint.timestamp)

                guard timeDiff > 0 else { continue }

                let speedMps = distance / timeDiff
                let speedValue = MeasurementFormatter.speedValue(speedMps)

                let elapsedTime = currentPoint.timestamp.timeIntervalSince(startTime)
                dataPoints.append(ChartDataPoint(elapsedTime: elapsedTime, value: speedValue))
            }

            // Sort by elapsed time first
            dataPoints.sort { $0.elapsedTime < $1.elapsedTime }

            // Apply smoothing using moving average
            guard dataPoints.count > windowSize else { return dataPoints }

            var smoothedPoints: [ChartDataPoint] = []
            for i in 0..<dataPoints.count {
                let startIdx = max(0, i - windowSize / 2)
                let endIdx = min(dataPoints.count, i + windowSize / 2 + 1)
                let window = dataPoints[startIdx..<endIdx]
                let avgSpeed = window.map { $0.value }.reduce(0, +) / Double(window.count)

                smoothedPoints.append(ChartDataPoint(
                    elapsedTime: dataPoints[i].elapsedTime,
                    value: avgSpeed
                ))
            }

            return smoothedPoints
        }
    }

    /// Calculate optimal stride for x-axis to prevent label overlap
    private func calculateOptimalXAxisStride(dataPoints: [ChartDataPoint]) -> Double {
        guard !dataPoints.isEmpty,
              let maxTime = dataPoints.map({ $0.elapsedTime }).max() else {
            return 60 // Default to 1 minute
        }

        // Aim for approximately 5-7 labels across the chart
        let targetLabels = 6
        let stride = maxTime / Double(targetLabels)

        // Round to nice intervals: 30s, 1m, 2m, 5m, 10m, 15m, 30m, 1h, etc.
        let niceIntervals: [Double] = [30, 60, 120, 300, 600, 900, 1800, 3600, 7200]

        // Find the closest nice interval that's >= stride
        return niceIntervals.first(where: { $0 >= stride }) ?? 3600
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

    /// Generate JSON export string for the trail
    private var trailJSONExport: String {
        do {
            let trailExport = trail.toExport()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(trailExport)
            return String(data: jsonData, encoding: .utf8) ?? "Error: Could not convert data to string"
        } catch {
            return "Error generating JSON: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    private func addPhoto(_ image: UIImage, to waypoint: WayPoint) {
        do {
            let filename = try PhotoStorage.save(image)
            let photo = Photo(filename: filename)
            modelContext.insert(photo)
            waypoint.photos.append(photo)
            photo.waypoint = waypoint
            try? modelContext.save()
        } catch {
            print("Failed to save photo: \(error)")
        }
    }

    private func deletePhoto(_ photo: Photo) {
        PhotoStorage.delete(photo.filename)
        modelContext.delete(photo)
        try? modelContext.save()
    }

    private func deleteTrail() {
        modelContext.delete(trail)
        try? modelContext.save()
        dismiss()
    }

    private func updateCollections(_ selected: [Collection]) {
        let oldCollections = Set(trail.collections)
        let newCollections = Set(selected)

        // Remove from collections that are no longer selected
        for collection in oldCollections.subtracting(newCollections) {
            collection.removeTrail(trail)
        }

        // Add to newly selected collections
        for collection in newCollections.subtracting(oldCollections) {
            collection.addTrail(trail)
        }

        try? modelContext.save()
    }

    private func deleteLink(_ link: Link) {
        trail.removeLink(link)
        modelContext.delete(link)
        try? modelContext.save()
    }

    private func exportToFile() {
        do {
            let trailExport = trail.toExport()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(trailExport)

            // Create filename with trail name and date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: trail.createdOn)
            let safeName = trail.name?.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "-", options: .regularExpression) ?? "trail"
            let filename = "\(safeName)-\(dateString).json"

            // Write to temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)

            try jsonData.write(to: fileURL)

            shareURL = fileURL
            showShareSheet = true
        } catch {
            print("Failed to export trail: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

enum MapColorMode {
    case simple
    case speed
    case altitude
}

// MARK: - Supporting Views

struct AccuracySummaryCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.orange)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        TrailDetailView(trail: Trail())
            .modelContainer(for: [Trail.self, TrailPoint.self], inMemory: true)
    }
}

// MARK: - Full Screen Trail Map View

struct FullScreenTrailMapView: View {
    @Environment(\.dismiss) private var dismiss

    let trail: Trail
    @State private var region: MKCoordinateRegion
    let trailMarkers: [TrailMarkerAnnotation]
    let trailColor: Color
    let sampledPoints: [TrailPoint]
    @State private var mapHeading: Double = 0
    @State private var mapSpan: MKCoordinateSpan
    @State private var mapColorMode: MapColorMode = .simple

    init(trail: Trail, region: MKCoordinateRegion, trailMarkers: [TrailMarkerAnnotation], trailColor: Color, sampledPoints: [TrailPoint]) {
        self.trail = trail
        self._region = State(initialValue: region)
        self.trailMarkers = trailMarkers
        self.trailColor = trailColor
        self.sampledPoints = sampledPoints
        self._mapSpan = State(initialValue: region.span)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if mapColorMode == .simple {
                    // Simple map with polyline
                    let sortedPoints = sampledPoints.sorted(by: { $0.timestamp < $1.timestamp })
                    let pointsWithAltitude = sortedPoints.filter { $0.altitude != nil }
                    Map(position: .constant(.region(region))) {
                        // Trail polyline
                        MapPolyline(coordinates: sortedPoints.map { $0.coordinate })
                            .stroke(trailColor, lineWidth: 4)

                        // Start marker
                        if let firstPoint = sortedPoints.first {
                            Annotation("Start", coordinate: firstPoint.coordinate) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }

                        // End marker
                        if let lastPoint = sortedPoints.last {
                            Annotation("End", coordinate: lastPoint.coordinate) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }

                        // Highest altitude marker
                        if let highestPoint = pointsWithAltitude.max(by: { $0.altitude! < $1.altitude! }) {
                            Annotation("", coordinate: highestPoint.coordinate) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.green)
                                        .background(Circle().fill(.white).padding(-4))
                                    Text(MeasurementFormatter.formatAltitude(highestPoint.altitude!))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.green)
                                        .cornerRadius(6)
                                }
                            }
                        }

                        // Lowest altitude marker
                        if let lowestPoint = pointsWithAltitude.min(by: { $0.altitude! < $1.altitude! }) {
                            Annotation("", coordinate: lowestPoint.coordinate) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.orange)
                                        .background(Circle().fill(.white).padding(-4))
                                    Text(MeasurementFormatter.formatAltitude(lowestPoint.altitude!))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.orange)
                                        .cornerRadius(6)
                                }
                            }
                        }

                        // Waypoint markers
                        ForEach(trail.waypoints) { waypoint in
                            Annotation(waypoint.label, coordinate: waypoint.coordinate) {
                                VStack(spacing: 2) {
                                    Image(systemName: "flag.fill")
                                        .font(.title2)
                                        .foregroundStyle(.purple)
                                        .background(Circle().fill(.white).padding(-4))
                                    Text(waypoint.label)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.purple)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .ignoresSafeArea()
                } else {
                    // Gradient map for speed/altitude
                    GradientMapView(
                        region: $region,
                        trail: trail,
                        trailMarkers: trailMarkers,
                        colorMode: mapColorMode,
                        isInteractive: true
                    )
                    .ignoresSafeArea()
                }

                // Top overlay controls
                VStack {
                    HStack {
                        Spacer()

                        VStack(alignment: .trailing, spacing: 12) {
                            // Close button
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.gray)
                                    .background(Circle().fill(.ultraThinMaterial))
                            }

                            // Color mode toggle
                            Picker("View Mode", selection: $mapColorMode) {
                                Text("Simple").tag(MapColorMode.simple)
                                Text("Speed").tag(MapColorMode.speed)
                                Text("Altitude").tag(MapColorMode.altitude)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)

                            // Color legend (only for speed/altitude)
                            if mapColorMode != .simple {
                                colorLegend
                            }
                        }
                    }
                    .padding()

                    Spacer()
                }
            }
        }
    }

    private var colorLegend: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                // Min value
                VStack(spacing: 2) {
                    if mapColorMode == .speed {
                        Text(minSpeedFormatted)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text(MeasurementFormatter.speedUnit)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text(minAltitudeFormatted)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text(MeasurementFormatter.altitudeUnit)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: mapColorMode == .speed ?
                                [.green, .yellow, .orange, .red] :
                                [.blue, .cyan, .green, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 10)
                    .cornerRadius(5)

                // Max value
                VStack(spacing: 2) {
                    if mapColorMode == .speed {
                        Text(maxSpeedFormatted)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text(MeasurementFormatter.speedUnit)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text(maxAltitudeFormatted)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text(MeasurementFormatter.altitudeUnit)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
    }

    // Computed properties for min/max values
    private var minSpeedFormatted: String {
        let sortedPoints = trail.points.sorted { $0.timestamp < $1.timestamp }
        guard sortedPoints.count > 1 else { return "0" }

        var speeds: [Double] = []
        for i in 1..<sortedPoints.count {
            let currentPoint = sortedPoints[i]
            let previousPoint = sortedPoints[i - 1]

            let currentLocation = CLLocation(
                latitude: currentPoint.latitude,
                longitude: currentPoint.longitude
            )
            let previousLocation = CLLocation(
                latitude: previousPoint.latitude,
                longitude: previousPoint.longitude
            )

            let distance = currentLocation.distance(from: previousLocation)
            let timeDiff = currentPoint.timestamp.timeIntervalSince(previousPoint.timestamp)

            if timeDiff > 0 {
                let speedMps = distance / timeDiff
                let speedValue = MeasurementFormatter.speedValue(speedMps)
                speeds.append(speedValue)
            }
        }

        if let minSpeed = speeds.min() {
            return String(format: "%.0f", minSpeed)
        }
        return "0"
    }

    private var maxSpeedFormatted: String {
        let sortedPoints = trail.points.sorted { $0.timestamp < $1.timestamp }
        guard sortedPoints.count > 1 else { return "0" }

        var speeds: [Double] = []
        for i in 1..<sortedPoints.count {
            let currentPoint = sortedPoints[i]
            let previousPoint = sortedPoints[i - 1]

            let currentLocation = CLLocation(
                latitude: currentPoint.latitude,
                longitude: currentPoint.longitude
            )
            let previousLocation = CLLocation(
                latitude: previousPoint.latitude,
                longitude: previousPoint.longitude
            )

            let distance = currentLocation.distance(from: previousLocation)
            let timeDiff = currentPoint.timestamp.timeIntervalSince(previousPoint.timestamp)

            if timeDiff > 0 {
                let speedMps = distance / timeDiff
                let speedValue = MeasurementFormatter.speedValue(speedMps)
                speeds.append(speedValue)
            }
        }

        if let maxSpeed = speeds.max() {
            return String(format: "%.0f", maxSpeed)
        }
        return "0"
    }

    private var minAltitudeFormatted: String {
        let altitudes = trail.points.compactMap { $0.altitude }
        if let minAlt = altitudes.min() {
            let altitudeValue = MeasurementFormatter.altitudeValue(minAlt)
            return String(format: "%.0f", altitudeValue)
        }
        return "0"
    }

    private var maxAltitudeFormatted: String {
        let altitudes = trail.points.compactMap { $0.altitude }
        if let maxAlt = altitudes.max() {
            let altitudeValue = MeasurementFormatter.altitudeValue(maxAlt)
            return String(format: "%.0f", altitudeValue)
        }
        return "0"
    }
}

// MARK: - Chart Data Model

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let elapsedTime: TimeInterval  // seconds from start
    let value: Double

    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - JSON Export Preview Sheet

struct JSONExportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let jsonString: String
    @State private var showCopiedConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(jsonString)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("JSON Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
            .overlay(alignment: .top) {
                if showCopiedConfirmation {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Copied to clipboard!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(.ultraThickMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = jsonString

        // Show confirmation
        withAnimation {
            showCopiedConfirmation = true
        }

        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopiedConfirmation = false
            }
        }
    }
}

// MARK: - Altitude Chart Sheet

struct AltitudeChartSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trail: Trail
    let altitudeChartData: [ChartDataPoint]?
    @Binding var selectedAltitudeTime: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let altitudeData = altitudeChartData, !altitudeData.isEmpty {
                    let minAltitude = altitudeData.map { $0.value }.min() ?? 0
                    let maxAltitude = altitudeData.map { $0.value }.max() ?? 100
                    let range = maxAltitude - minAltitude
                    let padding = max(range * 0.1, 5)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Altitude Over Time")
                                .font(.headline)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("↑ \(String(format: "%.0f", maxAltitude)) \(MeasurementFormatter.altitudeUnit)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("↓ \(String(format: "%.0f", minAltitude)) \(MeasurementFormatter.altitudeUnit)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Chart {
                            ForEach(altitudeData) { point in
                                LineMark(
                                    x: .value("Time", point.elapsedTime),
                                    y: .value("Altitude", point.value)
                                )
                                .foregroundStyle(.blue.gradient)
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Time", point.elapsedTime),
                                    y: .value("Altitude", point.value)
                                )
                                .foregroundStyle(.blue.opacity(0.1).gradient)
                                .interpolationMethod(.catmullRom)
                            }

                            // Mark highest point
                            if let highestPoint = altitudeData.max(by: { $0.value < $1.value }) {
                                PointMark(
                                    x: .value("Time", highestPoint.elapsedTime),
                                    y: .value("Altitude", highestPoint.value)
                                )
                                .foregroundStyle(.green)
                                .symbolSize(100)
                                .annotation(position: .top, spacing: 8) {
                                    VStack(spacing: 2) {
                                        Text("↑ Highest")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.green)
                                        Text("\(String(format: "%.0f", highestPoint.value)) \(MeasurementFormatter.altitudeUnit)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
                                }
                            }

                            // Mark lowest point
                            if let lowestPoint = altitudeData.min(by: { $0.value < $1.value }) {
                                PointMark(
                                    x: .value("Time", lowestPoint.elapsedTime),
                                    y: .value("Altitude", lowestPoint.value)
                                )
                                .foregroundStyle(.orange)
                                .symbolSize(100)
                                .annotation(position: .bottom, spacing: 8) {
                                    VStack(spacing: 2) {
                                        Text("↓ Lowest")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.orange)
                                        Text("\(String(format: "%.0f", lowestPoint.value)) \(MeasurementFormatter.altitudeUnit)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
                                }
                            }

                            // Selection indicator
                            if let selectedTime = selectedAltitudeTime,
                               let selectedPoint = altitudeData.min(by: { abs($0.elapsedTime - selectedTime) < abs($1.elapsedTime - selectedTime) }) {
                                RuleMark(x: .value("Time", selectedPoint.elapsedTime))
                                    .foregroundStyle(.gray.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                    .annotation(position: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selectedPoint.formattedTime)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f m", selectedPoint.value))
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                    }
                            }
                        }
                        .frame(height: 300)
                        .chartYScale(domain: (minAltitude - padding)...(maxAltitude + padding))
                        .chartXSelection(value: $selectedAltitudeTime)
                    }
                    .padding()
                }
            }
            .navigationTitle("Altitude Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Speed Chart Sheet

struct SpeedChartSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trail: Trail
    let speedChartData: [ChartDataPoint]
    @Binding var selectedSpeedTime: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                if !speedChartData.isEmpty {
                    let minSpeed = speedChartData.map { $0.value }.min() ?? 0
                    let maxSpeed = speedChartData.map { $0.value }.max() ?? 10
                    let range = maxSpeed - minSpeed
                    let padding = max(range * 0.1, 1)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Speed Over Time")
                                .font(.headline)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("↑ \(String(format: "%.1f", maxSpeed)) \(MeasurementFormatter.speedUnit)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("↓ \(String(format: "%.1f", minSpeed)) \(MeasurementFormatter.speedUnit)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Chart(speedChartData) { point in
                            LineMark(
                                x: .value("Time", point.elapsedTime),
                                y: .value("Speed", point.value)
                            )
                            .foregroundStyle(.green.gradient)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Time", point.elapsedTime),
                                y: .value("Speed", point.value)
                            )
                            .foregroundStyle(.green.opacity(0.1).gradient)
                            .interpolationMethod(.catmullRom)

                            if let selectedTime = selectedSpeedTime,
                               let selectedPoint = speedChartData.min(by: { abs($0.elapsedTime - selectedTime) < abs($1.elapsedTime - selectedTime) }) {
                                RuleMark(x: .value("Time", selectedPoint.elapsedTime))
                                    .foregroundStyle(.gray.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                    .annotation(position: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selectedPoint.formattedTime)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("\(String(format: "%.1f", selectedPoint.value)) \(MeasurementFormatter.speedUnit)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                    }
                            }
                        }
                        .frame(height: 300)
                        .chartYScale(domain: (minSpeed - padding)...(maxSpeed + padding))
                        .chartXSelection(value: $selectedSpeedTime)
                    }
                    .padding()
                }
            }
            .navigationTitle("Speed Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Accuracy Chart Sheet

struct AccuracyChartSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trail: Trail
    let accuracyChartData: [ChartDataPoint]?
    @Binding var selectedAccuracyTime: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let accuracyData = accuracyChartData, !accuracyData.isEmpty {
                    let minAccuracy = accuracyData.map { $0.value }.min() ?? 0
                    let maxAccuracy = accuracyData.map { $0.value }.max() ?? 50
                    let range = maxAccuracy - minAccuracy
                    let padding = max(range * 0.1, 5)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("GPS Accuracy Over Time")
                                .font(.headline)

                            Spacer()

                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .help("Lower values indicate better GPS accuracy")
                        }

                        Chart(accuracyData) { point in
                            LineMark(
                                x: .value("Time", point.elapsedTime),
                                y: .value("Accuracy", point.value)
                            )
                            .foregroundStyle(.orange.gradient)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Time", point.elapsedTime),
                                y: .value("Accuracy", point.value)
                            )
                            .foregroundStyle(.orange.opacity(0.1).gradient)
                            .interpolationMethod(.catmullRom)

                            if let selectedTime = selectedAccuracyTime,
                               let selectedPoint = accuracyData.min(by: { abs($0.elapsedTime - selectedTime) < abs($1.elapsedTime - selectedTime) }) {
                                RuleMark(x: .value("Time", selectedPoint.elapsedTime))
                                    .foregroundStyle(.gray.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                    .annotation(position: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selectedPoint.formattedTime)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "±%.1f m", selectedPoint.value))
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                    }
                            }
                        }
                        .frame(height: 300)
                        .chartYScale(domain: (minAccuracy - padding)...(maxAccuracy + padding))
                        .chartXSelection(value: $selectedAccuracyTime)

                        HStack(spacing: 16) {
                            AccuracySummaryCard(
                                label: "Average",
                                value: String(format: "±%.1f m", accuracyData.map { $0.value }.reduce(0, +) / Double(accuracyData.count)),
                                icon: "target"
                            )

                            AccuracySummaryCard(
                                label: "Best",
                                value: String(format: "±%.1f m", minAccuracy),
                                icon: "checkmark.circle.fill"
                            )

                            AccuracySummaryCard(
                                label: "Worst",
                                value: String(format: "±%.1f m", maxAccuracy),
                                icon: "exclamationmark.triangle.fill"
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("GPS Accuracy Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize Color from hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else {
            return nil
        }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    /// Convert Color to hex string
    func toHexString() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }

        let red = Int(components[0] * 255.0)
        let green = Int(components[1] * 255.0)
        let blue = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
