import SwiftUI
import SwiftData
import MapKit

/// Detailed view of a collection showing all venues, trails, and metadata
struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var collection: Collection

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showFullScreenMap = false

    // State for interactive full screen map only
    @State private var fullScreenMapHeading: Double = 0
    @State private var fullScreenMapSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Collection Header
                collectionHeader

                // Map Preview
                if !collection.venues.isEmpty || !collection.trails.isEmpty {
                    mapPreview
                }

                // Statistics
                statsSection

                // Venues Section
                venuesSection

                // Trails Section
                trailsSection
            }
            .padding()
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

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
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                CollectionFormView(collection: collection)
            }
        }
        .alert("Delete Collection?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCollection()
            }
        } message: {
            Text("Venues and trails in this collection will not be deleted.")
        }
        .fullScreenCover(isPresented: $showFullScreenMap) {
            NavigationStack {
                MapView(
                    region: .constant(mapRegion),
                    venues: collection.venues,
                    trails: collection.trails,
                    recordingLocations: [],
                    mapHeading: $fullScreenMapHeading,
                    mapSpan: $fullScreenMapSpan
                )
                .ignoresSafeArea()
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showFullScreenMap = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = collection.collectionDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Map")
                .font(.headline)

            ZStack(alignment: .topTrailing) {
                // Use constant bindings to prevent updates when collection changes
                MapView(
                    region: .constant(mapRegion),
                    venues: collection.venues,
                    trails: collection.trails,
                    recordingLocations: [],
                    mapHeading: .constant(0),
                    mapSpan: .constant(mapRegion.span)
                )
                .frame(height: 200)
                .cornerRadius(12)
                .id(collection.id)  // Stable identity prevents recreation on collection updates
                .transaction { transaction in
                    // Disable animations to prevent Metal conflicts
                    transaction.animation = nil
                }

                Button {
                    showFullScreenMap = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(radius: 2)
                }
                .padding(12)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 30) {
            StatView(
                value: "\(collection.venueCount)",
                label: "Venues",
                icon: "mappin.circle"
            )

            StatView(
                value: "\(collection.trailCount)",
                label: collection.trailCount == 1 ? "Trail" : "Trails",
                icon: "point.topleft.down.to.point.bottomright.curvepath"
            )

            if collection.trailCount > 0 {
                StatView(
                    value: collection.trailDistanceFormatted,
                    label: "Total Distance",
                    icon: "ruler"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var venuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Venues")
                    .font(.headline)

                Spacer()

                // Add Venue button will be implemented in next phase
            }

            if collection.venues.isEmpty {
                Text("No venues yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(collection.venues) { venue in
                        VenueRowView(venue: venue)
                    }
                }
            }
        }
    }

    private var trailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trails")
                .font(.headline)

            if collection.trails.isEmpty {
                VStack(spacing: 12) {
                    Text("No trails recorded")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                    Text("Go to the Map tab to record a trail")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(collection.trails) { trail in
                        NavigationLink(value: trail) {
                            TrailSummaryView(trail: trail)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var mapRegion: MKCoordinateRegion {
        // Calculate region that fits all venues and trails
        var coordinates: [CLLocationCoordinate2D] = []

        // Add venue coordinates
        coordinates.append(contentsOf: collection.venues.map { $0.coordinate })

        // Add trail coordinates from all trails
        for trail in collection.trails {
            coordinates.append(contentsOf: trail.points.map { $0.coordinate })
        }

        guard !coordinates.isEmpty else {
            // Default region if no coordinates
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        // Calculate center and span
        let minLat = coordinates.map { $0.latitude }.min()!
        let maxLat = coordinates.map { $0.latitude }.max()!
        let minLon = coordinates.map { $0.longitude }.min()!
        let maxLon = coordinates.map { $0.longitude }.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Actions

    private func deleteCollection() {
        // Dismiss first to prevent issues
        dismiss()

        // Delete after a small delay to ensure view is dismissed
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            modelContext.delete(collection)
            try? modelContext.save()
        }
    }
}

// MARK: - Supporting Views

/// Displays a single statistic with icon, value, and label
struct StatView: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)

            Text(value)
                .font(.system(size: 18, weight: .semibold))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Displays a venue in a row format with navigation
struct VenueRowView: View {
    let venue: Venue

    var body: some View {
        NavigationLink(value: venue) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(venue.label)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let address = venue.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Displays a trail summary with distance, duration, and travel mode
struct TrailSummaryView: View {
    let trail: Trail

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 24))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let startTime = trail.startTime {
                        Text(startTime.formatted(date: .abbreviated, time: .shortened))
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else {
                        Text("Trail")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }

                HStack(spacing: 12) {
                    if let distance = trail.totalDistance, distance > 0 {
                        Label(
                            String(format: "%.2f km", distance / 1000),
                            systemImage: "ruler"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let duration = trail.actualDuration, duration > 0 {
                        Label(
                            formatDuration(duration),
                            systemImage: "clock"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(collection: Collection(name: "Volcanoes", description: "A collection of volcanic sites"))
            .modelContainer(for: [Collection.self, Venue.self, Trail.self], inMemory: true)
    }
}
