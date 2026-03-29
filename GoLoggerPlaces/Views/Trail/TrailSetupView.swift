import SwiftUI
import SwiftData

/// Pre-recording setup sheet for selecting collection and travel mode
struct TrailSetupView: View {
    let collections: [Collection]
    let onStart: ([Collection], TravelMode?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCollections: [Collection] = []
    @State private var showCollectionSelectionSheet = false
    @State private var selectedMode: TravelMode? = nil
    @State private var showModePicker = false

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
                Button(action: { showModePicker = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedMode?.icon ?? "figure.walk")
                            .foregroundStyle(selectedMode != nil ? Color.blue : Color.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Travel Mode")
                                .foregroundStyle(.primary)
                            Text(selectedMode?.name ?? "None (Optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Travel Mode (Optional)")
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
        .sheet(isPresented: $showModePicker) {
            TravelModePicker(selectedMode: $selectedMode)
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
        onStart(selectedCollections, selectedMode)
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
