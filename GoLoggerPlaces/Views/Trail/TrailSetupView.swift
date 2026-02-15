import SwiftUI
import SwiftData

/// Pre-recording setup sheet for selecting collection
struct TrailSetupView: View {
    let collections: [Collection]
    let onStart: (Collection?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCollectionID: UUID?

    var body: some View {
        Form {
                Section("Select Collection (Optional)") {
                    Picker("Collection", selection: $selectedCollectionID) {
                        Text("No collection")
                            .tag(nil as UUID?)

                        ForEach(collections) { collection in
                            HStack {
                                Text(collection.name)
                                if !collection.trails.isEmpty {
                                    Text("(\(collection.trailCount))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(collection.id as UUID?)
                        }
                    }
                }

                Section {
                    Button(action: {
                        createNewCollection()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Collection")
                        }
                    }
                } footer: {
                    Text("Creates a new collection with a default name that you can edit later. Trail can be recorded without a collection.")
                        .font(.caption)
                }

                Section {
                    Button(action: startRecording) {
                        HStack {
                            Spacer()
                            Label("Start Recording", systemImage: "record.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
        }
        .navigationTitle("Record Trail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Clear invalid selection if the selected collection isn't in the collections array
            if let selectedID = selectedCollectionID,
               !collections.contains(where: { $0.id == selectedID }) {
                selectedCollectionID = nil
            }
        }
    }

    // MARK: - Actions

    @discardableResult
    private func createNewCollection() -> Collection {
        // Generate default name with current date/time
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        let defaultName = "Collection - \(dateString)"

        // Create new collection
        let newCollection = Collection(name: defaultName)
        modelContext.insert(newCollection)
        try? modelContext.save()

        // Note: We don't set selectedCollectionID here because the collections array
        // is a snapshot and doesn't include this new collection yet.
        // This would cause a Picker warning about invalid selection.

        return newCollection
    }

    private func startRecording() {
        // Determine which collection to use (if any)
        let collection: Collection?

        if let collectionID = selectedCollectionID,
           let existingCollection = collections.first(where: { $0.id == collectionID }) {
            // Use selected existing collection
            collection = existingCollection
            print("✅ Using selected collection: \(existingCollection.name)")
        } else {
            // No collection selected - record without collection
            collection = nil
            print("ℹ️ No collection selected - recording trail without collection")
        }

        onStart(collection)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        TrailSetupView(
            collections: [
                Collection(name: "Weekend Trip"),
                Collection(name: "Day Hike")
            ],
            onStart: { _ in }
        )
    }
    .modelContainer(for: [Collection.self, Trail.self], inMemory: true)
}
