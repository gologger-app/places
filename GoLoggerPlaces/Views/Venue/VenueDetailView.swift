import SwiftUI
import SwiftData
import MapKit

/// Detailed view of a single venue
struct VenueDetailView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss)
    private var dismiss

    @Bindable var venue: Venue
    @Query private var collections: [Collection]

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showCollectionSheet = false
    @State private var showAddVisitSheet = false
    @State private var showNearbyPlaces = false
    @State private var showCopiedAlert = false
    @State private var showAddressCopiedAlert = false
    @State private var showFullscreenMap = false
    @State private var isWeatherExpanded = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var mapHeading: Double = 0
    @State private var mapSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @StateObject private var weatherService = WeatherService()
    @StateObject private var wikipediaService = WikipediaService()
    @StateObject private var locationService = LocationService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero section with map
                heroSection

                VStack(alignment: .leading, spacing: 20) {
                    // Info cards
                    infoCardsSection

                    // Notes
                    if let notes = venue.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    // Photos
                    photosSection

                    // Weather & Time
                    weatherAndTimeSection

                    // Visits
                    visitsSection

                    // Collections
                    collectionsSection

                    // Links
                    linksSection

                    // Wikipedia Nearby Places
                    nearbyPlacesSection
                }
                .padding(.horizontal)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize map region centered on venue
            mapRegion = MKCoordinateRegion(
                center: venue.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )

            // Start tracking user location
            if locationService.isAuthorized {
                locationService.startUpdatingLocation()
            }

            // Fetch weather data
            weatherService.fetchWeather(for: venue.coordinate)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportToFile()
                    } label: {
                        Label("Export Venue", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        openInMaps()
                    } label: {
                        Label("Navigate", systemImage: "arrow.triangle.turn.up.right.circle")
                    }

                    Divider()

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                VenueFormView(collections: collections, coordinate: nil, venue: venue)
            }
        }
        .sheet(isPresented: $showCollectionSheet) {
            NavigationStack {
                CollectionSelectionSheet(
                    selectedCollections: venue.collections,
                    availableCollections: collections
                ) { selected in
                    updateCollections(selected)
                }
            }
        }
        .sheet(isPresented: $showAddVisitSheet) {
            NavigationStack {
                AddVisitSheet(venue: venue)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .fullScreenCover(isPresented: $showFullscreenMap) {
            NavigationStack {
                let staticVenue = venue
                MapView(
                    region: $mapRegion,
                    venues: [staticVenue],
                    trails: [],
                    recordingLocations: [],
                    showAnnotationCallouts: false,
                    mapHeading: $mapHeading,
                    mapSpan: $mapSpan
                )
                .edgesIgnoringSafeArea(.all)
                .id("\(venue.id)-\(venue.latitude)-\(venue.longitude)-fullscreen")
                .navigationTitle(venue.label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showFullscreenMap = false
                        }
                    }
                }
            }
        }
        .alert("Delete Venue?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteVenue()
            }
        } message: {
            Text("This venue will be permanently deleted.")
        }
        .alert("Coordinates Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Coordinates copied to clipboard")
        }
        .alert("Address Copied", isPresented: $showAddressCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Address copied to clipboard")
        }
    }

    // MARK: - Subviews

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Map background
            let staticVenue = venue
            MapView(
                region: $mapRegion,
                venues: [staticVenue],
                trails: [],
                recordingLocations: [],
                mapHeading: $mapHeading,
                mapSpan: $mapSpan
            )
            .frame(height: 300)
            .id("\(venue.id)-\(venue.latitude)-\(venue.longitude)")
            .transaction { transaction in
                transaction.animation = nil
            }

            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)

            // Info overlay
            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(venue.label)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        if let userLoc = locationService.currentLocation {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(formatDistance(from: userLoc))
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }

                        if let address = venue.address, !address.isEmpty {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    // Expand button
                    Button(action: { showFullscreenMap = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
        }
        .frame(height: 300)
    }

    private var infoCardsSection: some View {
        VStack(spacing: 12) {
            // Coordinates card
            Menu {
                Button {
                    UIPasteboard.general.string = venue.coordinatesFormatted
                    showCopiedAlert = true
                } label: {
                    Label("Copy Coordinates", systemImage: "doc.on.doc")
                }

                if let address = venue.address, !address.isEmpty {
                    Button {
                        UIPasteboard.general.string = address
                        showAddressCopiedAlert = true
                    } label: {
                        Label("Copy Address", systemImage: "doc.on.doc")
                    }
                }

                Divider()

                Button {
                    openInOSM()
                } label: {
                    Label("Open in OSM", systemImage: "map")
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Coordinates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(venue.coordinatesFormatted)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let altitude = venue.altitude {
                            Text("Altitude: \(MeasurementFormatter.formatAltitude(altitude))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.blue)
                Text("Notes")
                    .font(.headline)
            }

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var nearbyPlacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .foregroundStyle(.blue)
                Text("Nearby Places")
                    .font(.headline)
            }

            if !showNearbyPlaces {
                Button {
                    showNearbyPlaces = true
                    wikipediaService.fetchNearbyPlaces(
                        latitude: venue.latitude,
                        longitude: venue.longitude
                    )
                } label: {
                    HStack {
                        Text("Load from Wikipedia")
                            .font(.subheadline)
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
            } else {
                wikipediaNearbyContent
            }
        }
    }

    private var wikipediaNearbyContent: some View {
        Group {
            if wikipediaService.isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading nearby places...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            } else if !wikipediaService.nearbyPlaces.isEmpty {
                VStack(spacing: 8) {
                    ForEach(wikipediaService.nearbyPlaces) { place in
                        Button(
                            action: {
                                UIApplication.shared.open(place.pageURL)
                            },
                            label: {
                                WikipediaPlaceRow(place: place)
                            }
                        )
                        .buttonStyle(.plain)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            } else if let error = wikipediaService.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                Text("No nearby places found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }

    private var weatherAndTimeSection: some View {
        WeatherAndTimeSection(weatherService: weatherService, isExpanded: $isWeatherExpanded)
    }

    private var visitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visits")
                .font(.headline)

            let sortedVisits = venue.visits.sorted { $0.date > $1.date }

            if sortedVisits.isEmpty {
                Text("No visits recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedVisits, id: \.id) { visit in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.blue)

                                Text(visit.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.body)

                                Spacer()
                            }

                            if let note = visit.note, !note.isEmpty {
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 28)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collections")
                .font(.headline)

            if venue.collections.isEmpty {
                Text("Not in any collections")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(venue.collections) { collection in
                        NavigationLink(value: collection) {
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
            Text("Links")
                .font(.headline)

            if venue.links.isEmpty {
                Text("No links yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(venue.links) { link in
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
                    }
                }
            }
        }
    }

    private var photosSection: some View {
        PhotoGridView(
            photos: venue.photos,
            onAdd: { image, capturedAt in addPhoto(image, capturedAt: capturedAt, to: venue) },
            onDelete: { photo in deletePhoto(photo) }
        )
    }

    // MARK: - Helpers

    private func formatDistance(from userLocation: CLLocation) -> String {
        let venueLocation = CLLocation(latitude: venue.latitude, longitude: venue.longitude)
        let distance = userLocation.distance(from: venueLocation)

        return "\(MeasurementFormatter.formatDistance(distance)) away"
    }

    // MARK: - Actions

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: venue.coordinate))
        mapItem.name = venue.label
        mapItem.openInMaps(launchOptions: nil)
    }

    private func openInOSM() {
        // Convert MKCoordinateSpan to OSM zoom level
        // OSM zoom formula: zoom = log2(360 / span_in_degrees)
        // Approximation: for latitude span, zoom ≈ log2(360 / latitudeDelta)
        let spanDegrees = mapSpan.latitudeDelta
        let zoom = max(1, min(19, Int(round(log2(360.0 / spanDegrees)))))

        // OpenStreetMap URL format with marker: https://www.openstreetmap.org/?mlat=lat&mlon=lon#map=zoom/lat/lon
        let urlString = String(
            format: "https://www.openstreetmap.org/?mlat=%.6f&mlon=%.6f#map=%d/%.6f/%.6f",
            venue.latitude,
            venue.longitude,
            zoom,
            venue.latitude,
            venue.longitude
        )

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func exportToFile() {
        do {
            let venueExport = venue.toExport()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(venueExport)

            // Create filename with venue name and coordinates
            let safeName = venue.label.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "-", options: .regularExpression)
            let coordString = String(format: "%.4f-%.4f", venue.latitude, venue.longitude)
            let filename = "\(safeName)-\(coordString).json"

            // Write to temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)

            try jsonData.write(to: fileURL)

            shareURL = fileURL
            showShareSheet = true
        } catch {
            print("Failed to export venue: \(error.localizedDescription)")
        }
    }

    private func addPhoto(_ image: UIImage, capturedAt: Date?, to venue: Venue) {
        do {
            let filename = try PhotoStorage.save(image)
            let photo = Photo(filename: filename, capturedAt: capturedAt)
            modelContext.insert(photo)
            venue.photos.append(photo)
            photo.venue = venue
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

    private func deleteVenue() {
        modelContext.delete(venue)
        try? modelContext.save()

        dismiss()
    }

    private func updateCollections(_ selected: [Collection]) {
        let oldCollections = Set(venue.collections)
        let newCollections = Set(selected)

        // Remove from collections that are no longer selected
        for collection in oldCollections.subtracting(newCollections) {
            collection.removeVenue(venue)
        }

        // Add to newly selected collections
        for collection in newCollections.subtracting(oldCollections) {
            collection.addVenue(venue)
        }

        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        VenueDetailView(venue: Venue(
            latitude: 37.7749,
            longitude: -122.4194,
            label: "Golden Gate Park",
            address: "San Francisco, CA",
            notes: "Beautiful park with lots of trails"
        ))
        .modelContainer(for: [Venue.self], inMemory: true)
    }
}
