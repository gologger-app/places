import SwiftUI
import SwiftData

/// Sort options for venues
enum VenueSortOption: String, CaseIterable {
    case createdOn = "Created"
    case editDate = "Last Edited"
    case alphabetical = "Alphabetical"

    var systemImage: String {
        switch self {
        case .createdOn: return "calendar.badge.plus"
        case .editDate: return "calendar.badge.clock"
        case .alphabetical: return "textformat"
        }
    }
}

/// List view displaying all venues
struct VenueListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var venues: [Venue]

    @State private var searchText = ""
    @State private var sortOption: VenueSortOption = .createdOn
    @State private var showAddressSearch = false

    var body: some View {
        Group {
            if venues.isEmpty {
                emptyState
            } else {
                venueList
            }
        }
        .navigationTitle("Venues")
        .searchable(text: $searchText, prompt: "Search venues")
        .sheet(isPresented: $showAddressSearch) {
            VenueAddressSearchSheet(userLocation: nil)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showAddressSearch = true }) {
                    Label("Add by Address", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(VenueSortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            HStack {
                                Label(option.rawValue, systemImage: option.systemImage)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Venues Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add venues from the Map tab or tap + to search by address")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var venueList: some View {
        List {
            ForEach(filteredVenues) { venue in
                NavigationLink(value: venue) {
                    VenueRowListView(venue: venue)
                }
            }
            .onDelete(perform: deleteVenues)
        }
    }

    private var filteredVenues: [Venue] {
        var filtered = venues

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { venue in
                venue.label.lowercased().contains(searchLower) ||
                venue.address?.lowercased().contains(searchLower) ?? false ||
                venue.notes?.lowercased().contains(searchLower) ?? false
            }
        }

        // Sort
        switch sortOption {
        case .createdOn:
            return filtered.sorted { $0.createdOn > $1.createdOn }
        case .editDate:
            return filtered.sorted { $0.editDate > $1.editDate }
        case .alphabetical:
            return filtered.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        }
    }

    // MARK: - Actions

    private func deleteVenues(at offsets: IndexSet) {
        // Collect venues to delete
        let venuesToDelete = offsets.map { filteredVenues[$0] }

        // Delete after a small delay to allow SwiftUI's delete animation to complete
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            for venue in venuesToDelete {
                modelContext.delete(venue)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Venue Row View

struct VenueRowListView: View {
    let venue: Venue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(venue.label)
                .font(.headline)

            if let address = venue.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label(venue.coordinatesFormatted, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Collections count hidden to avoid loading relationship during list rendering
//                if !venue.collections.isEmpty {
//                    Label("\(venue.collections.count)", systemImage: "folder")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VenueListView()
        .modelContainer(for: [Collection.self, Venue.self, Trail.self], inMemory: true)
}
