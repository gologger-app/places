import SwiftUI
import SwiftData

/// Filter options for map display
struct MapFilters {
    var searchText: String = ""
    var selectedTravelModes: Set<TravelMode> = []
    var showVenues: Bool = true
    var showTrails: Bool = true
    var dateRange: DateRange?
    var selectedCollectionID: UUID?

    var isActive: Bool {
        !searchText.isEmpty ||
        !selectedTravelModes.isEmpty ||
        !showVenues ||
        !showTrails ||
        dateRange != nil ||
        selectedCollectionID != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if !selectedTravelModes.isEmpty { count += 1 }
        if !showVenues || !showTrails { count += 1 }
        if dateRange != nil { count += 1 }
        if selectedCollectionID != nil { count += 1 }
        return count
    }

    mutating func reset() {
        searchText = ""
        selectedTravelModes = []
        showVenues = true
        showTrails = true
        dateRange = nil
        selectedCollectionID = nil
    }
}

struct DateRange {
    var from: Date
    var to: Date
}

/// Filter sheet for map view
struct FilterSheet: View {
    @Binding var filters: MapFilters

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.editDate, order: .reverse) private var collections: [Collection]

    var body: some View {
        NavigationStack {
            Form {
                // Display Filter
                Section("Display") {
                    Toggle("Show Venues", isOn: $filters.showVenues)
                    Toggle("Show Trails", isOn: $filters.showTrails)
                }

                // Collection Filter
                Section("Collection") {
                    Picker("Filter by Collection", selection: $filters.selectedCollectionID) {
                        Text("All Collections").tag(nil as UUID?)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                }

                // Search
                Section("Search") {
                    TextField("Search trips, venues...", text: $filters.searchText)
                        .textInputAutocapitalization(.never)
                }

                // Travel Modes
                Section("Travel Modes") {
                    ForEach(TravelMode.allCases, id: \.self) { mode in
                        Toggle(isOn: Binding(
                            get: { filters.selectedTravelModes.contains(mode) },
                            set: { isSelected in
                                if isSelected {
                                    filters.selectedTravelModes.insert(mode)
                                } else {
                                    filters.selectedTravelModes.remove(mode)
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: mode.iconName)
                                Text(mode.displayName)
                            }
                        }
                    }
                }

                // Clear Filters
                if filters.isActive {
                    Section {
                        Button("Clear All Filters") {
                            filters.reset()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FilterSheet(
        filters: .constant(MapFilters())
    )
}
