import SwiftUI
import SwiftData

/// Navigation destinations for trail navigation
enum TrailNavigation: Hashable {
    case trail(Trail)
    case collection(Collection)
}

/// Sort options for trails
enum TrailSortOption: String, CaseIterable {
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

/// List view displaying all trails
struct TrailListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trails: [Trail]

    @State private var searchText = ""
    @State private var sortOption: TrailSortOption = .createdOn

    var body: some View {
        Group {
            if trails.isEmpty {
                emptyState
            } else {
                trailList
            }
        }
        .navigationTitle("Trails")
        .searchable(text: $searchText, prompt: "Search trails")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(TrailSortOption.allCases, id: \.self) { option in
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
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Trails Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record your first trail from the Map tab")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var trailList: some View {
        List {
            ForEach(filteredTrails) { trail in
                NavigationLink(value: TrailNavigation.trail(trail)) {
                    TrailRowListView(trail: trail)
                }
            }
            .onDelete(perform: deleteTrails)
        }
    }

    private var filteredTrails: [Trail] {
        var filtered = trails

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { trail in
                // Search by trail name
                (trail.name?.lowercased().contains(searchLower) ?? false) ||
                // Search by collection names
                trail.collections.contains(where: { $0.name.lowercased().contains(searchLower) })
            }
        }

        // Sort
        switch sortOption {
        case .createdOn:
            return filtered.sorted { $0.createdOn > $1.createdOn }
        case .editDate:
            return filtered.sorted { $0.editDate > $1.editDate }
        case .alphabetical:
            return filtered.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    // MARK: - Actions

    private func deleteTrails(at offsets: IndexSet) {
        // Collect trails to delete
        let trailsToDelete = offsets.map { filteredTrails[$0] }

        // Delete after a small delay to allow SwiftUI's delete animation to complete
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            for trail in trailsToDelete {
                modelContext.delete(trail)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Trail Row View

struct TrailRowListView: View {
    let trail: Trail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.blue)

                Text(trail.displayName)
                    .font(.headline)

                Spacer()

                // Color indicator
                Circle()
                    .fill(Color(hex: trail.hexColor) ?? .blue)
                    .frame(width: 12, height: 12)
            }

            HStack(spacing: 16) {
                if let distance = trail.totalDistance, distance > 0 {
                    Label(trail.distanceFormatted, systemImage: "ruler")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let duration = trail.actualDuration, duration > 0 {
                    Label(trail.durationFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if trail.cachedPointCount > 0 {
                    Label("\(trail.cachedPointCount)", systemImage: "location.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

//                if !trail.collections.isEmpty {
//                    Label("\(trail.collections.count)", systemImage: "folder")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TrailListView()
        .modelContainer(for: [Collection.self, Venue.self, Trail.self], inMemory: true)
}
