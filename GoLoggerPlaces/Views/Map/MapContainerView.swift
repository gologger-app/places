import SwiftUI
import SwiftData
import MapKit

/// Main map container view with controls and collection/venue display
struct MapContainerView: View {
    @Binding var navigationPath: NavigationPath

    // Gradient constants
    private let venueButtonGradient = LinearGradient(
        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
        startPoint: .top,
        endPoint: .bottom
    )

    private let recordButtonGradient = LinearGradient(
        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.9)]),
        startPoint: .top,
        endPoint: .bottom
    )

    @Environment(\.modelContext) private var modelContext

    // Lazy-loaded data (fetched only when needed)
    @State private var collections: [Collection] = []
    @State private var allVenuesQuery: [Venue] = []
    @State private var allTrailsQuery: [Trail] = []

    @StateObject private var locationService = LocationService()
    @State private var recordingViewModel: TrailRecordingViewModel?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    // UI State
    @State private var showNewCollectionSheet = false
    @State private var showSelectCollectionSheet = false
    @State private var showFilterSheet = false
    @State private var venueCoordinate: VenueCoordinate?
    @State private var selectedTrails: [Trail] = []
    @State private var trailSelectionPosition: CGPoint = .zero
    @State private var showPermissionAlert = false
    @State private var showStopRecordingAlert = false
    @State private var showRecordingErrorAlert = false
    @State private var recordingErrorMessage = ""
    @State private var filters = MapFilters()
    @State private var hasInitiallyCenteredMap = false
    @State private var mapType: MKMapType = .mutedStandard
    @State private var cameraPitch: CGFloat = 0
    @State private var mapHeading: Double = 0
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    @State private var showLocationDetailSheet = false

    var body: some View {
        mapContentWithSheets
            .withAlerts(
                showStopRecordingAlert: $showStopRecordingAlert,
                showRecordingErrorAlert: $showRecordingErrorAlert,
                recordingErrorMessage: recordingErrorMessage,
                stopRecording: stopRecording
            )
            .onAppear {
                setupLocationService()
                setupRecordingViewModel()

                // Fetch data based on initial filter state
                if filters.showVenues {
                    fetchVenues()
                }
                if filters.showTrails {
                    fetchTrails()
                }
            }
            .onChange(of: locationService.currentLocation) { oldValue, newValue in
                if !hasInitiallyCenteredMap, let location = newValue {
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                    hasInitiallyCenteredMap = true
                }
            }
            .withFilterHandlers(
                filters: filters,
                venueCoordinate: venueCoordinate,
                allVenuesQuery: allVenuesQuery,
                fetchVenues: fetchVenues,
                fetchTrails: fetchTrails,
                refetchVenues: refetchVenues
            )
    }

    // MARK: - View Hierarchy

    private var mapContentWithSheets: some View {
        mapLayers
            .sheet(isPresented: $showNewCollectionSheet) {
                NavigationStack {
                    CollectionFormView(collection: nil)
                }
            }
            .sheet(item: $venueCoordinate) { venueCoord in
                VenueCreationSheet(
                    coordinate: venueCoord.coordinate,
                    userLocation: locationService.currentLocation
                )
            }
            .sheet(isPresented: $showSelectCollectionSheet) {
                NavigationStack {
                    TrailSetupView(
                        collections: collections,
                        onStart: { collections in
                            startRecording(for: collections)
                        }
                    )
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(filters: $filters)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showLocationDetailSheet) {
                if let location = locationService.currentLocation {
                    UserLocationDetailView(
                        location: location,
                        address: locationService.currentAddress
                    )
                }
            }
    }

    private var mapLayers: some View {
        ZStack {
            baseMapView
            centerDotIndicator
            mapControlsOverlay
            bottomControlsOverlay
            yourLocationOverlay
            recordingOverlay
            permissionOverlay
            trailSelectionOverlay
        }
    }

    private var baseMapView: some View {
        MapView(
            region: $region,
            venues: allVenues,
            trails: allTrails,
            waypoints: allWaypoints,
            recordingLocations: locationService.recordedLocations,
            onAnnotationTapped: handleVenueTapped,
            onTrailTapped: handleTrailTapped,
            mapType: mapType,
            cameraPitch: cameraPitch,
            mapHeading: $mapHeading,
            mapSpan: $mapSpan
        )
    }

    private var centerDotIndicator: some View {
        Circle()
            .fill(Color.pink)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private var mapControlsOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                compassControl
                Spacer()
                mapButtonsControl
            }
            Spacer()
        }
    }

    private var compassControl: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            CompassButton(heading: mapHeading)
                .padding(.leading, 8)
        }
    }

    private var mapButtonsControl: some View {
        VStack(spacing: 12) {
            FilterButton(
                isActive: filters.isActive,
                action: { showFilterSheet = true }
            )
            MapStyleButton(mapType: $mapType)
            MapPitchToggle(pitch: $cameraPitch)
            UserLocationButton(action: centerOnUserLocation)
        }
        .padding(.trailing, 16)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var bottomControlsOverlay: some View {
        if recordingViewModel?.isRecording != true {
            VStack {
                Spacer()
                HStack {
                    addVenueButton
                    Spacer()
                    coordinateInfoDisplay
                    Spacer()
                    recordTrailButton
                }
                .padding()
            }
        }
    }

    private var addVenueButton: some View {
        Button(action: handleAddVenue) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(venueButtonGradient)
                .clipShape(Circle())
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }

    private var coordinateInfoDisplay: some View {
        VStack(spacing: 3) {
            Text(coordinateText)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.primary)

            if let distanceText = distanceFromUserText {
                Text("distance: \(distanceText)")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    private var recordTrailButton: some View {
        Button(action: {
            collections = []
            fetchCollections()
            print("🎬 Record button tapped, collections count: \(collections.count)")
            showSelectCollectionSheet = true
        }) {
            Image(systemName: "record.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(recordButtonGradient)
                .clipShape(Circle())
                .shadow(color: Color.red.opacity(0.4), radius: 6, x: 0, y: 3)
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
        }
    }

    @ViewBuilder
    private var yourLocationOverlay: some View {
        if locationService.currentLocation != nil, recordingViewModel?.isRecording != true {
            VStack {
                Button(action: {
                    showLocationDetailSheet = true
                }) {
                    Text("Your location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .padding(.top, 60)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var recordingOverlay: some View {
        if let viewModel = recordingViewModel, viewModel.isRecording {
            TrailRecordingView(
                viewModel: viewModel,
                onStop: {
                    print("🛑 Stop button tapped")
                    showStopRecordingAlert = true
                }
            )
        }
    }

    @ViewBuilder
    private var permissionOverlay: some View {
        if !locationService.isAuthorized && locationService.authorizationStatus != .notDetermined {
            VStack {
                Spacer()
                Text("Location access is required to use GoLogger Places")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var trailSelectionOverlay: some View {
        if !selectedTrails.isEmpty {
            VStack {
                Spacer()
                TrailSelectionPopup(
                    trails: selectedTrails,
                    onTrailSelected: { trail in
                        navigationPath.append(trail)
                        selectedTrails = []
                    },
                    onDismiss: {
                        selectedTrails = []
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
                Spacer()
            }
            .transition(.opacity)
            .onTapGesture {
                selectedTrails = []
            }
        }
    }

    // MARK: - Computed Properties

    private var coordinateText: String {
        String(format: "%.4f, %.4f", region.center.latitude, region.center.longitude)
    }

    private var distanceFromUserText: String? {
        guard let userLocation = locationService.currentLocation else {
            return nil
        }

        let mapCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let distance = userLocation.distance(from: mapCenter)

        return MeasurementFormatter.formatDistance(distance)
    }

    private var allVenues: [Venue] {
        guard filters.showVenues else { return [] }

        // If recording, only show venues from the current collections
        let baseVenues: [Venue]
        if let recordingCollections = recordingViewModel?.currentCollections, !recordingCollections.isEmpty {
            // Show venues from all recording collections
            let venueSet = Set(recordingCollections.flatMap { $0.venues })
            baseVenues = Array(venueSet)
        } else if let selectedCollectionID = filters.selectedCollectionID {
            // Filter venues by selected collection
            baseVenues = allVenuesQuery.filter { venue in
                venue.collections.contains { $0.id == selectedCollectionID }
            }
        } else {
            // Show all venues from the database (both in collections and independent)
            baseVenues = Array(allVenuesQuery)
        }

        // Apply filters manually to avoid SwiftData's Predicate filter
        var filteredVenues: [Venue] = []
        for venue in baseVenues {
            var shouldInclude = true

            // Search filter
            if !filters.searchText.isEmpty {
                let searchLower = filters.searchText.lowercased()
                let matchesLabel = venue.label.lowercased().contains(searchLower)
                let matchesNotes = venue.notes?.lowercased().contains(searchLower) ?? false
                let matchesAddress = venue.address?.lowercased().contains(searchLower) ?? false

                if !matchesLabel && !matchesNotes && !matchesAddress {
                    shouldInclude = false
                }
            }

            if shouldInclude {
                filteredVenues.append(venue)
            }
        }

        return filteredVenues
    }

    private var allWaypoints: [WayPoint] {
        guard filters.showTrails else { return [] }
        return allTrails.flatMap { $0.waypoints }
    }

    private var allTrails: [Trail] {
        guard filters.showTrails else { return [] }

        // If recording, only show trails from the current collections
        let baseTrails: [Trail]
        if let recordingCollections = recordingViewModel?.currentCollections, !recordingCollections.isEmpty {
            // Show trails from all recording collections
            let trailSet = Set(recordingCollections.flatMap { $0.trails })
            baseTrails = Array(trailSet)
        } else if let selectedCollectionID = filters.selectedCollectionID {
            // Filter trails by selected collection
            baseTrails = allTrailsQuery.filter { trail in
                trail.collections.contains { $0.id == selectedCollectionID }
            }
        } else {
            // Show all trails from the database (both in collections and independent)
            baseTrails = Array(allTrailsQuery)
        }

        // Apply filters manually to avoid SwiftData's Predicate filter
        let filteredTrails: [Trail] = baseTrails

        return filteredTrails
    }

    // MARK: - Actions

    private func setupLocationService() {
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestWhenInUseAuthorization()
        }

        if locationService.isAuthorized {
            locationService.startUpdatingLocation()

            // Center map on user's location if available
            if let location = locationService.currentLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }

    private func setupRecordingViewModel() {
        if recordingViewModel == nil {
            recordingViewModel = TrailRecordingViewModel(
                locationService: locationService,
                modelContext: modelContext
            )
        }
    }

    // MARK: - Data Fetching

    private func fetchCollections() {
        guard collections.isEmpty else { return }  // Only fetch if not already loaded

        do {
            let descriptor = FetchDescriptor<Collection>(
                sortBy: [SortDescriptor(\.editDate, order: .reverse)]
            )
            collections = try modelContext.fetch(descriptor)
            print("✅ Fetched \(collections.count) collections")
        } catch {
            print("❌ Failed to fetch collections: \(error)")
        }
    }

    private func fetchVenues() {
        guard allVenuesQuery.isEmpty else { return }  // Only fetch if not already loaded

        do {
            let descriptor = FetchDescriptor<Venue>(
                sortBy: [SortDescriptor(\.editDate, order: .reverse)]
            )
            allVenuesQuery = try modelContext.fetch(descriptor)
            print("✅ Fetched \(allVenuesQuery.count) venues")
        } catch {
            print("❌ Failed to fetch venues: \(error)")
        }
    }

    private func refetchVenues() {
        do {
            let descriptor = FetchDescriptor<Venue>(
                sortBy: [SortDescriptor(\.editDate, order: .reverse)]
            )
            allVenuesQuery = try modelContext.fetch(descriptor)
            print("✅ Refetched \(allVenuesQuery.count) venues")
        } catch {
            print("❌ Failed to refetch venues: \(error)")
        }
    }

    private func fetchTrails() {
        guard allTrailsQuery.isEmpty else { return }  // Only fetch if not already loaded

        do {
            let descriptor = FetchDescriptor<Trail>(
                sortBy: [SortDescriptor(\.editDate, order: .reverse)]
            )
            allTrailsQuery = try modelContext.fetch(descriptor)
            print("✅ Fetched \(allTrailsQuery.count) trails")
        } catch {
            print("❌ Failed to fetch trails: \(error)")
        }
    }

    private func startRecording(for collections: [Collection]) {
        guard let viewModel = recordingViewModel else {
            recordingErrorMessage = "Recording system not initialized. Please try again."
            showRecordingErrorAlert = true
            return
        }

        // Check location permission
        guard locationService.isAuthorized else {
            recordingErrorMessage = "Location permission is required to record trails. Please grant location access in Settings."
            showRecordingErrorAlert = true
            return
        }

        // Request "Always" authorization for background tracking if we only have "When In Use"
        // This is the appropriate time to request it since the user is about to start recording
        if locationService.authorizationStatus == .authorizedWhenInUse {
            locationService.requestAlwaysAuthorization()
        }

        // Zoom in closer to user location when recording starts
        if let location = locationService.currentLocation {
            withAnimation(.easeInOut(duration: 0.8)) {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }

        // Start recording
        viewModel.startRecording(collections: collections)

        // Verify recording actually started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !viewModel.isRecording {
                recordingErrorMessage = locationService.errorMessage ?? "Failed to start recording. Please try again."
                showRecordingErrorAlert = true
            }
        }
    }

    private func stopRecording() {
        guard let viewModel = recordingViewModel else { return }

        if let savedTrail = viewModel.stopRecording() {
            // Trail is saved automatically by the view model
            // Navigate to the trail detail view
            navigationPath.append(savedTrail)
        }
    }

    private func centerOnUserLocation() {
        if let location = locationService.currentLocation {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        } else if locationService.authorizationStatus == .notDetermined {
            locationService.requestWhenInUseAuthorization()
        } else if !locationService.isAuthorized {
            showPermissionAlert = true
        }
    }

    private func handleAddVenue() {
        // Use the center of the current map region
        venueCoordinate = VenueCoordinate(coordinate: region.center)
    }

    private func handleVenueTapped(_ venue: Venue) {
        navigationPath.append(venue)
    }

    private func handleTrailTapped(_ trails: [Trail]) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTrails = trails
        }
    }
}

// MARK: - VenueCoordinate

/// Identifiable wrapper for CLLocationCoordinate2D to use with sheet(item:)
struct VenueCoordinate: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: VenueCoordinate, rhs: VenueCoordinate) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - View Extensions

private extension View {
    func withAlerts(
        showStopRecordingAlert: Binding<Bool>,
        showRecordingErrorAlert: Binding<Bool>,
        recordingErrorMessage: String,
        stopRecording: @escaping () -> Void
    ) -> some View {
        self
            .alert("Stop Recording?", isPresented: showStopRecordingAlert) {
                Button("Cancel", role: .cancel) {
                    print("🛑 Stop recording cancelled")
                }
                Button("Stop & Save", role: .destructive) {
                    print("🛑 Stop & Save selected")
                    stopRecording()
                }
            } message: {
                Text("This will save the recorded trail to your collection.")
            }
            .alert("Cannot Start Recording", isPresented: showRecordingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(recordingErrorMessage)
            }
    }

    func withFilterHandlers(
        filters: MapFilters,
        venueCoordinate: VenueCoordinate?,
        allVenuesQuery: [Venue],
        fetchVenues: @escaping () -> Void,
        fetchTrails: @escaping () -> Void,
        refetchVenues: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: filters.showVenues) { oldValue, newValue in
                if newValue {
                    fetchVenues()
                }
            }
            .onChange(of: filters.showTrails) { oldValue, newValue in
                if newValue {
                    fetchTrails()
                }
            }
            .onChange(of: venueCoordinate) { oldValue, newValue in
                if oldValue != nil && newValue == nil && !allVenuesQuery.isEmpty {
                    refetchVenues()
                }
            }
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack(path: $navigationPath) {
        MapContainerView(navigationPath: $navigationPath)
            .modelContainer(for: [Collection.self, Venue.self, Trail.self], inMemory: true)
    }
}
