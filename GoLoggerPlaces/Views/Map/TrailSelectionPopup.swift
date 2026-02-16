import SwiftUI

/// Popup view for displaying selected trail(s) on the map
struct TrailSelectionPopup: View {
    let trails: [Trail]
    let onTrailSelected: (Trail) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if trails.count == 1, let trail = trails.first {
                // Single trail - show name and info button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trail.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 10))
                            if let distance = trail.totalDistance {
                                Text(MeasurementFormatter.formatDistance(distance))
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        onTrailSelected(trail)
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                }
                .padding(12)
            } else {
                // Multiple trails - show list
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(trails.count) Trails")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(trails) { trail in
                                Button(action: {
                                    onTrailSelected(trail)
                                }) {
                                    HStack {
                                        // Trail color indicator
                                        Circle()
                                            .fill(Color(hex: trail.hexColor) ?? .blue)
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(trail.displayName)
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)

                                            HStack(spacing: 4) {
                                                Image(systemName: "figure.walk")
                                                    .font(.system(size: 9))
                                                if let distance = trail.totalDistance {
                                                    Text(MeasurementFormatter.formatDistance(distance))
                                                        .font(.system(size: 9))
                                                }
                                            }
                                            .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                if trail.id != trails.last?.id {
                                    Divider()
                                        .padding(.leading, 32)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.bottom, 8)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            // Prevent dismissing when tapping inside the popup
        }
    }
}

#Preview {
    VStack {
        Spacer()

        // Preview with single trail
        TrailSelectionPopup(
            trails: [Trail.preview()],
            onTrailSelected: { _ in },
            onDismiss: { }
        )
        .padding()

        Spacer()
    }
}

// MARK: - Preview Helpers

extension Trail {
    static func preview() -> Trail {
        let trail = Trail(hexColor: "#FF5733")
        trail.name = "Morning Bike Ride in Central Park"
        return trail
    }
}
