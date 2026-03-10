import SwiftUI
import SwiftData
import CoreLocation
import MapKit

/// Sheet for creating a new venue from map tap with address fetching and collection selection
struct VenueCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let coordinate: CLLocationCoordinate2D
    let userLocation: CLLocation?
    var prefillName: String? = nil
    var prefillAddress: String? = nil
    var onSave: (() -> Void)? = nil

    @State private var venueName: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var altitude: String = ""
    @State private var selectedCollections: [Collection] = []
    @State private var availableCollections: [Collection] = []
    @State private var showCollectionSelectionSheet = false
    @State private var isLoadingAddress = true

    private let distanceThreshold: CLLocationDistance = 50.0  // 50 meters

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Primary Information
                Section {
                    // Venue Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if isLoadingAddress {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading...")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 8) {
                                TextField("Enter venue name", text: $venueName)
                                    .font(.title3)
                                    .fontWeight(.medium)

                                if !venueName.isEmpty {
                                    Button(action: { venueName = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listRowSeparator(.hidden)

                    // Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if isLoadingAddress {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Fetching address...")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 8) {
                                TextField("Enter address", text: $address)
                                    .foregroundStyle(address.isEmpty ? .tertiary : .primary)

                                if !address.isEmpty {
                                    Button(action: { address = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Color(.systemGroupedBackground))

                // MARK: - Location Details
                Section {
                    VStack(spacing: 12) {
                        // Latitude
                        HStack(spacing: 12) {
                            Image(systemName: "location.north.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text("Latitude")
                                .foregroundStyle(.secondary)

                            Spacer()

                            TextField("0.000000", text: $latitude)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)
                        }

                        Divider()

                        // Longitude
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text("Longitude")
                                .foregroundStyle(.secondary)

                            Spacer()

                            TextField("0.000000", text: $longitude)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)
                        }

                        Divider()

                        // Altitude
                        HStack(spacing: 12) {
                            Image(systemName: "mountain.2.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text("Altitude")
                                .foregroundStyle(.secondary)

                            Spacer()

                            TextField("0.0", text: $altitude)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)

                            Text("m")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Coordinates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Notes
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add notes about this venue...", text: $notes, axis: .vertical)
                            .lineLimit(4...8)
                    }
                } header: {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Collections
                Section {
                    Button(action: { showCollectionSelectionSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: selectedCollections.isEmpty ? "folder.badge.plus" : "folder.fill")
                                .foregroundStyle(selectedCollections.isEmpty ? Color.secondary : Color.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedCollections.isEmpty ? "Add to Collection" : "Collections")
                                    .foregroundStyle(.primary)

                                if !selectedCollections.isEmpty {
                                    Text("\(selectedCollections.count) selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }

                    if !selectedCollections.isEmpty {
                        ForEach(selectedCollections) { collection in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)

                                Text(collection.name)
                                    .font(.subheadline)
                            }
                            .padding(.leading, 36)
                        }
                    }
                } header: {
                    Text("Organization")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveVenue()
                    }
                    .fontWeight(.semibold)
                    .disabled(venueName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadLocationData()
                fetchCollections()
            }
            .sheet(isPresented: $showCollectionSelectionSheet) {
                NavigationStack {
                    CollectionSelectionSheet(
                        selectedCollections: selectedCollections,
                        availableCollections: availableCollections,
                        onSave: { newSelection in
                            selectedCollections = newSelection
                        }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func fetchCollections() {
        do {
            let descriptor = FetchDescriptor<Collection>(
                sortBy: [SortDescriptor(\.editDate, order: .reverse)]
            )
            availableCollections = try modelContext.fetch(descriptor)
            print("✅ VenueCreationSheet fetched \(availableCollections.count) collections")
        } catch {
            print("❌ VenueCreationSheet failed to fetch collections: \(error)")
            availableCollections = []
        }
    }

    private func loadLocationData() {
        // Set coordinates
        latitude = String(format: "%.6f", coordinate.latitude)
        longitude = String(format: "%.6f", coordinate.longitude)

        // Check if location is near user and set altitude
        if let userLoc = userLocation {
            let tappedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = tappedLocation.distance(from: userLoc)

            if distance <= distanceThreshold {
                altitude = String(format: "%.1f", userLoc.altitude)
            }
        }

        // Use prefill values if provided, otherwise reverse geocode
        if let name = prefillName {
            venueName = name
            address = prefillAddress ?? ""
            isLoadingAddress = false
        } else {
            fetchAddress()
        }
    }

    private func fetchAddress() {
        isLoadingAddress = true

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingAddress = false

                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    address = ""
                    venueName = "New Venue"
                    return
                }

                guard let placemark = placemarks?.first else {
                    address = ""
                    venueName = "New Venue"
                    return
                }

                // Build address string
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

                address = addressComponents.joined(separator: ", ")

                // Set default venue name
                // Prefer POI name, then street address, then "New Venue"
                if let poiName = placemark.name,
                   poiName != placemark.thoroughfare,
                   !poiName.contains(","),
                   !poiName.allSatisfy({ $0.isNumber || $0.isWhitespace || $0 == "-" }) {
                    venueName = poiName
                } else if let thoroughfare = placemark.thoroughfare {
                    if let subThoroughfare = placemark.subThoroughfare {
                        venueName = "\(subThoroughfare) \(thoroughfare)"
                    } else {
                        venueName = thoroughfare
                    }
                } else {
                    venueName = "New Venue"
                }
            }
        }
    }

    private func saveVenue() {
        let trimmedName = venueName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Parse coordinates and altitude from text fields
        let finalLatitude = Double(latitude) ?? coordinate.latitude
        let finalLongitude = Double(longitude) ?? coordinate.longitude
        let finalAltitude = altitude.isEmpty ? nil : Double(altitude)

        // Create new venue
        let newVenue = Venue(
            latitude: finalLatitude,
            longitude: finalLongitude,
            altitude: finalAltitude,
            label: trimmedName,
            address: address.isEmpty ? nil : address,
            notes: notes.isEmpty ? nil : notes
        )

        // Add to selected collections
        for collection in selectedCollections {
            collection.addVenue(newVenue)
        }

        modelContext.insert(newVenue)

        try? modelContext.save()
        onSave?()
        dismiss()
    }
}

#Preview {
    VenueCreationSheet(
        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        userLocation: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    .modelContainer(for: [Collection.self, Venue.self], inMemory: true)
}
