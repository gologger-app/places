import SwiftUI
import SwiftData

/// Overlay view displayed during trail recording
struct TrailRecordingView: View {
    @ObservedObject var viewModel: TrailRecordingViewModel
    let onStop: () -> Void

    var body: some View {
        VStack {
            Spacer()

            // Waypoint Created Feedback
            if viewModel.showWaypointCreatedFeedback {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Waypoint Added!")
                        .font(.headline)
                }
                .padding()
                .background(.ultraThickMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.bottom, 8)
            }

            // Recording Panel
            VStack(spacing: 16) {
                // Recording Indicator
                HStack {
                    Circle()
                        .fill(viewModel.isPaused ? .orange : .red)
                        .frame(width: 12, height: 12)

                    Text(viewModel.isPaused ? "Paused" : "Recording Trail")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                // Stats
                HStack(spacing: 20) {
                    StatColumn(
                        icon: "clock.fill",
                        value: viewModel.elapsedTimeFormatted,
                        label: "Time"
                    )

                    StatColumn(
                        icon: "figure.walk",
                        value: viewModel.distanceFormatted,
                        label: "Distance"
                    )

                    StatColumn(
                        icon: "mappin.circle.fill",
                        value: "\(viewModel.waypointCount)",
                        label: "Waypoints"
                    )
                }

                // Add Waypoint Button
                Button {
                    print("🗺️ Add Waypoint button tapped")
                    viewModel.showWaypointCreationSheet()
                } label: {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Add Waypoint")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Control Buttons
                HStack(spacing: 12) {
                    // Pause/Resume Button
                    Button {
                        print("⏸️ Pause/Resume button tapped")
                        if viewModel.isPaused {
                            viewModel.resumeRecording()
                        } else {
                            viewModel.pauseRecording()
                        }
                    } label: {
                        HStack {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            Text(viewModel.isPaused ? "Resume" : "Pause")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isPaused ? .green : .orange)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Stop Button
                    Button {
                        print("⏹️ Stop button tapped in TrailRecordingView")
                        onStop()
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThickMaterial)
            )
            .shadow(radius: 10)
            .padding()
        }
        .sheet(isPresented: $viewModel.showingWaypointAdd) {
            WaypointLabelInputSheet(
                suggestedLabel: viewModel.suggestedWaypointLabel,
                onCreate: { label in
                    viewModel.createWaypointWithLabel(label)
                }
            )
        }
    }
}

// MARK: - Supporting Views

struct StatColumn: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Waypoint Label Input Sheet

struct WaypointLabelInputSheet: View {
    let suggestedLabel: String
    let onCreate: (String) -> Void

    @State private var waypointName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Waypoint Name", text: $waypointName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter a name for this waypoint")
                } footer: {
                    Text("Suggested: \(suggestedLabel)")
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
                        let finalLabel = waypointName.trimmingCharacters(in: .whitespaces)
                        onCreate(finalLabel.isEmpty ? suggestedLabel : finalLabel)
                        dismiss()
                    }
                }
            }
            .onAppear {
                waypointName = suggestedLabel
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        TrailRecordingView(
            viewModel: {
                let vm = TrailRecordingViewModel(
                    locationService: LocationService(),
                    modelContext: ModelContext(
                        try! ModelContainer(for: Collection.self)
                    )
                )
                return vm
            }(),
            onStop: { }
        )
    }
}
