import SwiftUI
import SwiftData
import CoreLocation
import MapKit

/// Form for creating or editing a venue
struct VenueFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let collections: [Collection]
    let coordinate: CLLocationCoordinate2D?
    let venue: Venue?

    @State private var label: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var altitude: String = ""
    @State private var selectedCollections: [Collection] = []
    @State private var showingLinkForm: Bool = false
    @State private var editingLink: Link?
    @State private var showingAddVisitSheet: Bool = false
    @State private var editingVisit: Visit?
    @State private var mapRegion = MKCoordinateRegion()
    @State private var pinCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var showCoordinateEditor = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    // Validation states
    @State private var latitudeError: String?
    @State private var longitudeError: String?
    @State private var altitudeError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Map Section
                mapSection

                // Content
                VStack(spacing: 24) {
                    // Basic Info
                    basicInfoSection

                    // Notes
                    if venue != nil || !notes.isEmpty {
                        notesSection
                    }

                    // Visits (editing only)
                    if let venue = venue {
                        visitsSection(venue: venue)
                    }

                    // Collections (editing only)
                    if venue != nil {
                        collectionsSection
                    }

                    // Links
                    linksSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(venue == nil ? "New Venue" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveVenue()
                }
                .disabled(!canSave)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadVenueData()
        }
        .sheet(isPresented: $showingLinkForm) {
            // Reset editingLink when sheet is dismissed
            editingLink = nil
        } content: {
            LinkFormView(link: editingLink) { savedLink in
                if let venue = venue {
                    if editingLink == nil {
                        venue.addLink(savedLink)
                        modelContext.insert(savedLink)
                    }
                    try? modelContext.save()
                }
            }
        }
        .sheet(isPresented: $showingAddVisitSheet) {
            NavigationStack {
                if let visit = editingVisit {
                    EditVisitSheet(visit: visit)
                } else if let venue = venue {
                    AddVisitSheet(venue: venue)
                }
            }
        }
        .sheet(isPresented: $showCoordinateEditor) {
            CoordinateEditorSheet(
                latitude: $latitude,
                longitude: $longitude,
                altitude: $altitude,
                latitudeError: $latitudeError,
                longitudeError: $longitudeError,
                altitudeError: $altitudeError,
                onValidate: { validateAllCoordinates() }
            )
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            MapReader { proxy in
                Map(initialPosition: mapCameraPosition, interactionModes: [.pan, .zoom]) {
                    Annotation("", coordinate: pinCoordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.red, .white)
                                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        }
                    }
                }
                .frame(height: 280)
                .onTapGesture { location in
                    if let coordinate = proxy.convert(location, from: .local) {
                        updatePinFromMap(coordinate)
                    }
                }
            }

            // Coordinate overlay
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    showCoordinateEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text("Coordinates")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)

                        Text(coordinateDisplay)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        if !altitude.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mountain.2.fill")
                                    .font(.caption2)
                                Text("\(altitude)m")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("Tap map or badge to edit")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(16)
        }
    }

    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("Venue name", text: $label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
            }

            Divider()

            // Address
            VStack(alignment: .leading, spacing: 8) {
                Label("Address", systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("Optional", text: $address)
                    .textFieldStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField("Add notes about this venue...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...8)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func visitsSection(venue: Venue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Visits", systemImage: "calendar")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    editingVisit = nil
                    showingAddVisitSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }

            let sortedVisits = venue.visits.sorted { $0.date > $1.date }

            if sortedVisits.isEmpty {
                Text("No visits recorded")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(sortedVisits, id: \.id) { visit in
                    Button {
                        editingVisit = visit
                        showingAddVisitSheet = true
                    } label: {
                        VisitRow(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteVisits)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Collections", systemImage: "folder")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(collections.filter { !selectedCollections.contains($0) }) { collection in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCollections.append(collection)
                            }
                        } label: {
                            Text(collection.name)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .disabled(collections.filter { !selectedCollections.contains($0) }.isEmpty)
            }

            if selectedCollections.isEmpty {
                Text("Not in any collections")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(selectedCollections) { collection in
                    CollectionTag(collection: collection)
                }
                .onDelete(perform: deleteCollections)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Links", systemImage: "link")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    editingLink = nil
                    showingLinkForm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if let venue = venue, !venue.links.isEmpty {
                ForEach(venue.links) { link in
                    Button {
                        editingLink = link
                        showingLinkForm = true
                    } label: {
                        LinkRow(link: link)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteLinks)
            } else {
                Text("No links yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var coordinateDisplay: String {
        if !latitude.isEmpty && !longitude.isEmpty {
            return "\(latitude), \(longitude)"
        }
        return "Tap to edit"
    }

    private var canSave: Bool {
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard latitudeError == nil, longitudeError == nil, altitudeError == nil else { return false }
        guard !latitude.isEmpty, !longitude.isEmpty else { return false }
        return true
    }

    // MARK: - Actions

    private func loadVenueData() {
        if let venue = venue {
            label = venue.label
            address = venue.address ?? ""
            notes = venue.notes ?? ""
            latitude = String(format: "%.6f", venue.latitude)
            longitude = String(format: "%.6f", venue.longitude)
            altitude = venue.altitude.map { String(format: "%.1f", $0) } ?? ""
            selectedCollections = venue.collections

            pinCoordinate = venue.coordinate
            mapRegion = MKCoordinateRegion(
                center: venue.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapCameraPosition = .region(mapRegion)
        } else if let coordinate = coordinate {
            latitude = String(format: "%.6f", coordinate.latitude)
            longitude = String(format: "%.6f", coordinate.longitude)

            pinCoordinate = coordinate
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapCameraPosition = .region(mapRegion)
        }
    }

    private func saveVenue() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty else { return }

        guard let lat = Double(latitude),
              let lon = Double(longitude) else {
            return
        }

        let alt: Double? = altitude.isEmpty ? nil : Double(altitude)

        let savedVenue: Venue
        if let existingVenue = venue {
            existingVenue.label = trimmedLabel
            existingVenue.address = address.isEmpty ? nil : address
            existingVenue.notes = notes.isEmpty ? nil : notes
            existingVenue.latitude = lat
            existingVenue.longitude = lon
            existingVenue.altitude = alt
            existingVenue.editDate = Date()

            let oldCollections = Set(existingVenue.collections)
            let newCollections = Set(selectedCollections)

            for collection in oldCollections.subtracting(newCollections) {
                collection.removeVenue(existingVenue)
            }

            for collection in newCollections.subtracting(oldCollections) {
                collection.addVenue(existingVenue)
            }

            savedVenue = existingVenue
        } else {
            let newVenue = Venue(
                latitude: lat,
                longitude: lon,
                altitude: alt,
                label: trimmedLabel,
                address: address.isEmpty ? nil : address,
                notes: notes.isEmpty ? nil : notes
            )

            for collection in selectedCollections {
                collection.addVenue(newVenue)
            }

            modelContext.insert(newVenue)
            savedVenue = newVenue
        }

        try? modelContext.save()

        dismiss()
    }

    private func deleteLinks(at offsets: IndexSet) {
        guard let venue = venue else { return }

        for index in offsets {
            let link = venue.links[index]
            venue.removeLink(link)
            modelContext.delete(link)
        }

        try? modelContext.save()
    }

    private func deleteVisits(at offsets: IndexSet) {
        guard let venue = venue else { return }

        let sortedVisits = venue.visits.sorted { $0.date > $1.date }
        for index in offsets {
            let visit = sortedVisits[index]
            venue.removeVisit(visit)
            modelContext.delete(visit)
        }

        try? modelContext.save()
    }

    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            selectedCollections.remove(at: index)
        }
    }

    // MARK: - Validation

    private func validateLatitude(_ value: String) {
        if value.isEmpty {
            latitudeError = nil
            return
        }

        guard let lat = Double(value) else {
            latitudeError = "Invalid number"
            return
        }

        if lat < -90 || lat > 90 {
            latitudeError = "Must be between -90 and 90"
        } else {
            latitudeError = nil
            if let lon = Double(longitude), longitudeError == nil {
                updatePinFromCoordinates(lat: lat, lon: lon)
            }
        }
    }

    private func validateLongitude(_ value: String) {
        if value.isEmpty {
            longitudeError = nil
            return
        }

        guard let lon = Double(value) else {
            longitudeError = "Invalid number"
            return
        }

        if lon < -180 || lon > 180 {
            longitudeError = "Must be between -180 and 180"
        } else {
            longitudeError = nil
            if let lat = Double(latitude), latitudeError == nil {
                updatePinFromCoordinates(lat: lat, lon: lon)
            }
        }
    }

    private func validateAltitude(_ value: String) {
        if value.isEmpty {
            altitudeError = nil
            return
        }

        guard Double(value) != nil else {
            altitudeError = "Invalid number"
            return
        }

        altitudeError = nil
    }

    private func validateAllCoordinates() {
        validateLatitude(latitude)
        validateLongitude(longitude)
        validateAltitude(altitude)
    }

    // MARK: - Map Interaction

    private func updatePinFromCoordinates(lat: Double, lon: Double) {
        // Just update the pin coordinate
        // Don't update the map camera - let the user control pan/zoom
        let newCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        pinCoordinate = newCoordinate
    }

    private func updatePinFromMap(_ coordinate: CLLocationCoordinate2D) {
        // Only update the pin coordinate, never touch the camera
        pinCoordinate = coordinate
        latitude = String(format: "%.6f", coordinate.latitude)
        longitude = String(format: "%.6f", coordinate.longitude)

        validateLatitude(latitude)
        validateLongitude(longitude)
    }
}

// MARK: - Supporting Views

struct VisitRow: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(visit.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let note = visit.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 4)
    }
}

struct CollectionTag: View {
    let collection: Collection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.caption)
                .foregroundStyle(.blue)

            Text(collection.name)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct LinkRow: View {
    let link: Link

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(link.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let url = link.url, !url.isEmpty {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 4)
    }
}

struct CoordinateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: String
    @Binding var longitude: String
    @Binding var altitude: String
    @Binding var latitudeError: String?
    @Binding var longitudeError: String?
    @Binding var altitudeError: String?
    let onValidate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Latitude")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        TextField("e.g., 37.774900", text: $latitude)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: latitude) { _, _ in onValidate() }

                        if let error = latitudeError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Valid range: -90 to 90")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Longitude")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        TextField("e.g., -122.419400", text: $longitude)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: longitude) { _, _ in onValidate() }

                        if let error = longitudeError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Valid range: -180 to 180")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mountain.2.fill")
                                .foregroundStyle(.blue)
                            Text("Altitude (optional)")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        TextField("e.g., 150", text: $altitude)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: altitude) { _, _ in onValidate() }

                        if let error = altitudeError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Elevation in meters above sea level")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Manual Input")
                } footer: {
                    Text("You can also tap directly on the map to set the pin location. The coordinates will update automatically.")
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
