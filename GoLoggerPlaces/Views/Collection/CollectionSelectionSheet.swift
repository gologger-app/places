import SwiftUI

/// Sheet for selecting collections (multi-select with checkmarks)
struct CollectionSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedCollections: [Collection]
    let availableCollections: [Collection]
    let onSave: ([Collection]) -> Void

    @State private var tempSelectedCollections: Set<UUID>
    @State private var searchText: String = ""
    @State private var showNewCollectionSheet = false

    init(selectedCollections: [Collection], availableCollections: [Collection], onSave: @escaping ([Collection]) -> Void) {
        self.selectedCollections = selectedCollections
        self.availableCollections = availableCollections
        self.onSave = onSave
        _tempSelectedCollections = State(initialValue: Set(selectedCollections.map { $0.id }))
    }

    private var filteredCollections: [Collection] {
        if searchText.isEmpty {
            return availableCollections
        } else {
            return availableCollections.filter { collection in
                collection.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List {
            if availableCollections.isEmpty {
                ContentUnavailableView {
                    Label("No Collections", systemImage: "folder.badge.plus")
                } description: {
                    Text("Create a collection first to organize your venues and trails")
                } actions: {
                    Button("Create Collection") {
                        showNewCollectionSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if filteredCollections.isEmpty {
                ContentUnavailableView.search
            } else {
                ForEach(filteredCollections) { collection in
                    Button(action: {
                        toggleCollection(collection)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let description = collection.collectionDescription {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if tempSelectedCollections.contains(collection.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.gray.opacity(0.3))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search collections")
        .navigationTitle("Manage Collections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showNewCollectionSheet = true }) {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveChanges()
                }
            }
        }
        .sheet(isPresented: $showNewCollectionSheet) {
            NavigationStack {
                CollectionFormView(collection: nil, onCreate: { newCollection in
                    // When a collection is created, auto-select it
                    tempSelectedCollections.insert(newCollection.id)
                })
            }
        }
    }

    private func toggleCollection(_ collection: Collection) {
        if tempSelectedCollections.contains(collection.id) {
            tempSelectedCollections.remove(collection.id)
        } else {
            tempSelectedCollections.insert(collection.id)
        }
    }

    private func saveChanges() {
        let selected = availableCollections.filter { tempSelectedCollections.contains($0.id) }
        onSave(selected)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CollectionSelectionSheet(
            selectedCollections: [Collection(name: "Volcanoes", description: "Volcanic sites")],
            availableCollections: [
                Collection(name: "Volcanoes", description: "Volcanic sites"),
                Collection(name: "Beaches", description: "Coastal spots")
            ],
            onSave: { _ in }
        )
    }
}
