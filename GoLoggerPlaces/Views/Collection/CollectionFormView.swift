import SwiftUI
import SwiftData

/// Form for creating or editing a collection
struct CollectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let collection: Collection?  // nil for new collection, non-nil for editing
    let onCreate: ((Collection) -> Void)?  // Optional callback when a new collection is created

    @State private var name: String = ""
    @State private var description: String = ""

    init(collection: Collection?, onCreate: ((Collection) -> Void)? = nil) {
        self.collection = collection
        self.onCreate = onCreate
    }

    var body: some View {
        Form {
            Section("Collection Information") {
                TextField("Collection Name", text: $name)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(collection == nil ? "New Collection" : "Edit Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveCollection()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            loadCollectionData()
        }
    }

    // MARK: - Actions

    private func loadCollectionData() {
        guard let collection = collection else { return }

        name = collection.name
        description = collection.collectionDescription ?? ""
    }

    private func saveCollection() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingCollection = collection {
            // Update existing collection
            existingCollection.name = trimmedName
            existingCollection.collectionDescription = description.isEmpty ? nil : description
            existingCollection.editDate = Date()
        } else {
            // Create new collection
            let newCollection = Collection(
                name: trimmedName,
                description: description.isEmpty ? nil : description
            )
            modelContext.insert(newCollection)

            // Call onCreate callback if provided
            onCreate?(newCollection)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview("New Collection") {
    NavigationStack {
        CollectionFormView(collection: nil)
            .modelContainer(for: [Collection.self], inMemory: true)
    }
}
