import SwiftUI
import SwiftData

/// List view displaying all collections
struct CollectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Collection.editDate, order: .reverse) private var collections: [Collection]

    @State private var showNewCollectionSheet = false
    @State private var selectedCollection: Collection?
    @State private var searchText = ""

    var body: some View {
        Group {
            if collections.isEmpty {
                emptyState
            } else {
                collectionList
            }
        }
        .navigationTitle("Collections")
        .searchable(text: $searchText, prompt: "Search collections")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showNewCollectionSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewCollectionSheet) {
            NavigationStack {
                CollectionFormView(collection: nil)
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Collections Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first collection to organize venues and trails")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showNewCollectionSheet = true }) {
                Label("New Collection", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }

    private var collectionList: some View {
        List {
            ForEach(filteredCollections) { collection in
                NavigationLink(value: collection) {
                    CollectionRowView(collection: collection)
                }
            }
            .onDelete(perform: deleteCollections)
        }
    }

    private var filteredCollections: [Collection] {
        if searchText.isEmpty {
            return collections
        } else {
            let searchLower = searchText.lowercased()
            return collections.filter { collection in
                collection.name.lowercased().contains(searchLower) ||
                collection.collectionDescription?.lowercased().contains(searchLower) ?? false
            }
        }
    }

    // MARK: - Actions

    private func deleteCollections(at offsets: IndexSet) {
        // Collect collections to delete
        let collectionsToDelete = offsets.map { filteredCollections[$0] }

        // Delete after a small delay to allow SwiftUI's delete animation to complete
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            for collection in collectionsToDelete {
                modelContext.delete(collection)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Collection Row View

struct CollectionRowView: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(collection.name)
                .font(.headline)

            if let description = collection.collectionDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label("\(collection.venueCount)", systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if collection.trailCount > 0 {
                    Label("\(collection.trailCount)", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CollectionListView()
        .modelContainer(for: [Collection.self, Venue.self, Trail.self], inMemory: true)
}
