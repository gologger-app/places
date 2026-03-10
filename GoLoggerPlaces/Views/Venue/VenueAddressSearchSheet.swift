import SwiftUI
import MapKit
import CoreLocation

/// Identifiable wrapper for MKMapItem
private struct MapItemResult: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem

    var name: String { mapItem.name ?? "Unknown" }
    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }

    var formattedAddress: String? {
        let placemark = mapItem.placemark
        var parts: [String] = []
        if let sub = placemark.subThoroughfare, let thor = placemark.thoroughfare {
            parts.append("\(sub) \(thor)")
        } else if let thor = placemark.thoroughfare {
            parts.append(thor)
        }
        if let locality = placemark.locality { parts.append(locality) }
        if let admin = placemark.administrativeArea { parts.append(admin) }
        if let postal = placemark.postalCode { parts.append(postal) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

/// Sheet for searching a place by address or name and creating a venue from the result
struct VenueAddressSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userLocation: CLLocation?

    @State private var searchText = ""
    @State private var searchResults: [MapItemResult] = []
    @State private var isSearching = false
    @State private var selectedResult: MapItemResult?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different address or place name")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(searchResults) { result in
                        Button(action: { selectedResult = result }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let address = result.formattedAddress {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search by Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Address or place name"
            )
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []
                    isSearching = false
                    return
                }
                isSearching = true
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await performSearch(query: newValue)
                }
            }
            .sheet(item: $selectedResult) { result in
                VenueCreationSheet(
                    coordinate: result.coordinate,
                    userLocation: userLocation,
                    prefillName: result.name,
                    prefillAddress: result.formattedAddress,
                    onSave: { dismiss() }
                )
            }
        }
    }

    // MARK: - Search

    private func performSearch(query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        if let userLocation {
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            await MainActor.run {
                searchResults = response.mapItems.map { MapItemResult(mapItem: $0) }
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }
}

#Preview {
    VenueAddressSearchSheet(userLocation: nil)
}
