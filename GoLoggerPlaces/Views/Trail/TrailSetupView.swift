import SwiftUI
import SwiftData

/// Pre-recording setup sheet for selecting collection
struct TrailSetupView: View {
    let collections: [Collection]
    let onStart: ([Collection]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCollections: [Collection] = []
    @State private var showCollectionSelectionSheet = false

    var body: some View {
        Form {
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
                Text("Organization (Optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showCollectionSelectionSheet) {
            NavigationStack {
                CollectionSelectionSheet(
                    selectedCollections: selectedCollections,
                    availableCollections: collections,
                    onSave: { newSelection in
                        selectedCollections = newSelection
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        if selectedCollections.isEmpty {
            print("ℹ️ No collections selected - recording trail without collections")
        } else {
            print("✅ Using \(selectedCollections.count) collection(s): \(selectedCollections.map { $0.name }.joined(separator: ", "))")
        }

        onStart(selectedCollections)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        TrailSetupView(
            collections: [
                Collection(name: "Weekend Trip"),
                Collection(name: "Day Hike"),
                Collection(name: "City Tour")
            ],
            onStart: { _ in }
        )
    }
    .modelContainer(for: [Collection.self, Trail.self], inMemory: true)
}
