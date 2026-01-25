import SwiftUI
import SwiftData

/// View for editing trail properties (rename and trim)
struct TrailEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var trail: Trail
    @State private var showTrimSheet = false

    var body: some View {
        Form {
            // Rename Section
            Section {
                HStack {
                    TextField("Trail Name", text: Binding(
                        get: { trail.name ?? "" },
                        set: { newValue in
                            trail.name = newValue.isEmpty ? nil : newValue
                            trail.editDate = Date()
                        }
                    ), prompt: Text("Enter a custom name"))
                    .autocorrectionDisabled()

                    if let name = trail.name, !name.isEmpty {
                        Button {
                            trail.name = nil
                            trail.editDate = Date()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Trail Name")
            } footer: {
                Text("Give your trail a custom name. If left empty, it will be named based on the date and time.")
            }

            // Trail Color Section
            Section {
                HStack(spacing: 16) {
                    // Color preview circle
                    Circle()
                        .fill(Color(hex: trail.hexColor) ?? .blue)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(.gray.opacity(0.3), lineWidth: 1)
                        )

                    // Color picker
                    ColorPicker("Trail Color", selection: Binding(
                        get: { Color(hex: trail.hexColor) ?? .blue },
                        set: { newColor in
                            if let hexString = newColor.toHexString() {
                                trail.hexColor = hexString
                                trail.editDate = Date()
                            }
                        }
                    ))

                    Spacer()

                    // Show hex code
                    Text(trail.hexColor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                }
            } header: {
                Text("Appearance")
            }

            // Trail Info Section
            Section {
                HStack {
                    Text("Display Name")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(trail.displayName)
                        .fontWeight(.medium)
                }

                Picker("Travel Mode", selection: Binding(
                    get: { trail.travelMode },
                    set: { newValue in
                        trail.travelMode = newValue
                        trail.editDate = Date()
                        try? modelContext.save()
                    }
                )) {
                    ForEach(TravelMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.iconName)
                            .tag(mode)
                    }
                }

                HStack {
                    Text("Distance")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(trail.distanceFormatted)
                        .monospacedDigit()
                }

                HStack {
                    Text("Duration")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(trail.durationFormatted)
                        .monospacedDigit()
                }

                HStack {
                    Text("Points")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(trail.points.count)")
                        .monospacedDigit()
                }
            } header: {
                Text("Trail Information")
            }

            // Trim Section
            Section {
                Button {
                    showTrimSheet = true
                } label: {
                    Label("Trim Trail", systemImage: "scissors")
                }
                .disabled(trail.points.count < 3)
            } header: {
                Text("Trail Editing")
            } footer: {
                if trail.points.count < 3 {
                    Text("Trail must have at least 3 points to trim.")
                } else {
                    Text("Remove unwanted points from the start and end of your trail.")
                }
            }
        }
        .navigationTitle("Edit Trail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    try? modelContext.save()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showTrimSheet) {
            TrailTrimView(trail: trail, onTrimComplete: {
                // Refresh view after trimming
            })
        }
    }
}

#Preview {
    NavigationStack {
        TrailEditView(trail: Trail(travelMode: .walking))
            .modelContainer(for: [Trail.self, TrailPoint.self], inMemory: true)
    }
}
