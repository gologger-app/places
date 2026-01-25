import SwiftUI
import SwiftData

/// View displaying comprehensive statistics about collections, venues, trails, and storage
struct StatisticsView: View {
    @Query private var collections: [Collection]
    @Query private var venues: [Venue]
    @Query private var trails: [Trail]
    @Query private var trailPoints: [TrailPoint]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overview Section
                    StatisticsSectionView(title: "Overview") {
                        StatisticsRow(label: "Total Collections", value: "\(collections.count)")
                        StatisticsRow(label: "Total Venues", value: "\(venues.count)")
                        StatisticsRow(label: "Total Trails", value: "\(trails.count)")
                        StatisticsRow(label: "Total Trail Points", value: "\(trailPoints.count)")
                    }

                    // Distance Statistics
                    if !trails.isEmpty {
                        StatisticsSectionView(title: "Distance") {
                            StatisticsRow(label: "Total Distance", value: totalDistanceFormatted)
                            StatisticsRow(label: "Average Trail Distance", value: averageTrailDistanceFormatted)
                            if let longest = longestTrail {
                                StatisticsRow(
                                    label: "Longest Trail",
                                    value: longest.distanceFormatted,
                                    subtitle: longest.collections.first?.name
                                )
                            }
                        }
                    }

                    // Time Statistics
                    if !trails.isEmpty {
                        StatisticsSectionView(title: "Duration") {
                            StatisticsRow(label: "Total Recording Time", value: totalDurationFormatted)
                            StatisticsRow(label: "Average Trail Duration", value: averageDurationFormatted)
                            if let longest = longestDurationTrail {
                                StatisticsRow(
                                    label: "Longest Recording",
                                    value: longest.durationFormatted,
                                    subtitle: longest.collections.first?.name
                                )
                            }
                        }
                    }

                    // Trail Points Statistics
                    if !trails.isEmpty {
                        StatisticsSectionView(title: "Trail Points") {
                            StatisticsRow(label: "Average Points per Trail", value: String(format: "%.1f", averagePointsPerTrail))
                            if let mostPoints = trailWithMostPoints {
                                StatisticsRow(
                                    label: "Most Points",
                                    value: "\(mostPoints.points.count)",
                                    subtitle: mostPoints.collections.first?.name
                                )
                            }
                        }
                    }

                    // Storage Statistics
                    StatisticsSectionView(title: "Storage") {
                        StatisticsRow(label: "Estimated Export Size", value: estimatedStorageSize)
                    }

                    // Additional Insights
                    if !collections.isEmpty {
                        StatisticsSectionView(title: "Insights") {
                            StatisticsRow(label: "Avg Venues per Collection", value: String(format: "%.1f", averageVenuesPerCollection))
                            StatisticsRow(label: "Avg Trails per Collection", value: String(format: "%.1f", averageTrailsPerCollection))
                            if let mostVenues = collectionWithMostVenues {
                                StatisticsRow(
                                    label: "Most Venues",
                                    value: "\(mostVenues.venueCount)",
                                    subtitle: mostVenues.name
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
        }
    }

    // MARK: - Computed Properties

    private var totalDistance: Double {
        trails.compactMap { $0.totalDistance }.reduce(0, +)
    }

    private var totalDistanceFormatted: String {
        return MeasurementFormatter.formatDistanceLarge(totalDistance)
    }

    private var averageTrailDistanceFormatted: String {
        let trailsWithDistance = trails.compactMap { $0.totalDistance }
        guard !trailsWithDistance.isEmpty else { return "N/A" }

        let average = trailsWithDistance.reduce(0, +) / Double(trailsWithDistance.count)
        return MeasurementFormatter.formatDistanceLarge(average)
    }

    private var longestTrail: Trail? {
        trails.max(by: { ($0.totalDistance ?? 0) < ($1.totalDistance ?? 0) })
    }

    private var totalDuration: TimeInterval {
        trails.compactMap { $0.actualDuration }.reduce(0, +)
    }

    private var totalDurationFormatted: String {
        formatDuration(totalDuration)
    }

    private var averageDurationFormatted: String {
        let trailsWithDuration = trails.compactMap { $0.actualDuration }
        guard !trailsWithDuration.isEmpty else { return "N/A" }

        let average = trailsWithDuration.reduce(0, +) / Double(trailsWithDuration.count)
        return formatDuration(average)
    }

    private var longestDurationTrail: Trail? {
        trails.max(by: { ($0.actualDuration ?? 0) < ($1.actualDuration ?? 0) })
    }

    private var averagePointsPerTrail: Double {
        guard !trails.isEmpty else { return 0 }
        return Double(trailPoints.count) / Double(trails.count)
    }

    private var trailWithMostPoints: Trail? {
        trails.max(by: { $0.points.count < $1.points.count })
    }

    private var averageVenuesPerCollection: Double {
        guard !collections.isEmpty else { return 0 }
        return Double(venues.count) / Double(collections.count)
    }

    private var averageTrailsPerCollection: Double {
        guard !collections.isEmpty else { return 0 }
        return Double(trails.count) / Double(collections.count)
    }

    private var collectionWithMostVenues: Collection? {
        collections.max(by: { $0.venueCount < $1.venueCount })
    }

    private var estimatedStorageSize: String {
        // Estimate JSON export size based on model data
        var estimatedSize = 0

        // Collections: ~300 bytes each (name, description, etc. - no dates)
        estimatedSize += collections.count * 300

        // Venues: ~300 bytes each (coordinates, label, times, etc.)
        estimatedSize += venues.count * 300

        // Trails: ~200 bytes each (mode, distance, duration, etc.)
        estimatedSize += trails.count * 200

        // TrailPoints: ~100 bytes each (coordinates, timestamp, etc.)
        estimatedSize += trailPoints.count * 100

        return formatBytes(estimatedSize)
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "%d sec", seconds)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}

// MARK: - Supporting Views

struct StatisticsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct StatisticsRow: View {
    let label: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.body)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.primary)
                .bold()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [Collection.self, Venue.self, Trail.self, TrailPoint.self], inMemory: true)
}
