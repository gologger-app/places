import SwiftUI

/// Quick waypoint creation view for use during trail recording
struct VenueQuickAddView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TrailRecordingViewModel

    @State private var label: String = ""
    @State private var notes: String = ""
    @FocusState private var labelIsFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Waypoint Name") {
                    TextField("Label (required)", text: $label)
                        .focused($labelIsFocused)
                }

                Section("Optional Details") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text("The waypoint will be created at your current location with the current timestamp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveWaypoint()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                labelIsFocused = true
            }
        }
    }

    // MARK: - Actions

    private func saveWaypoint() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty else { return }

        // Use the new createWaypointWithLabel method
        viewModel.createWaypointWithLabel(trimmedLabel)

        dismiss()
    }
}
