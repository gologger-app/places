import SwiftUI

/// View for selecting a collection to record a trail or add a venue to
struct CollectionSelectionView: View {
    let collections: [Collection]
    let onSelectCollection: (Collection) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(collections) { collection in
                Button(action: {
                    onSelectCollection(collection)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack {
                            Text("\(collection.venueCount) venue\(collection.venueCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !collection.trails.isEmpty {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text("\(collection.trailCount) trail\(collection.trailCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Select Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CollectionSelectionView(
            collections: [
                Collection(name: "Weekend Trip", description: "A fun weekend"),
                Collection(name: "Day Hike", description: "Morning hike")
            ],
            onSelectCollection: { _ in }
        )
    }
}
