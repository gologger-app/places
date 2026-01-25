import SwiftUI
import MapKit

// MARK: - Floating Map Button Style

struct FloatingMapButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func floatingMapButton() -> some View {
        modifier(FloatingMapButton())
    }
}

// MARK: - Map Style Button

struct MapStyleButton: View {
    @Binding var mapType: MKMapType

    var body: some View {
        Menu {
            Button {
                mapType = .standard
            } label: {
                Label("Standard", systemImage: mapType == .standard ? "checkmark" : "")
            }

            Button {
                mapType = .satellite
            } label: {
                Label("Satellite", systemImage: mapType == .satellite ? "checkmark" : "")
            }

            Button {
                mapType = .hybrid
            } label: {
                Label("Hybrid", systemImage: mapType == .hybrid ? "checkmark" : "")
            }

            Button {
                mapType = .mutedStandard
            } label: {
                Label("Muted", systemImage: mapType == .mutedStandard ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "map")
                .floatingMapButton()
        }
    }
}

// MARK: - Map Zoom Controls

struct MapZoomInButton: View {
    @Binding var span: MKCoordinateSpan
    @Binding var region: MKCoordinateRegion

    var body: some View {
        Button {
            zoomIn()
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .floatingMapButton()
        }
    }

    private func zoomIn() {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: span.latitudeDelta * 0.5,
            longitudeDelta: span.longitudeDelta * 0.5
        )
        span = newSpan
        region = MKCoordinateRegion(center: region.center, span: newSpan)
    }
}

struct MapZoomOutButton: View {
    @Binding var span: MKCoordinateSpan
    @Binding var region: MKCoordinateRegion

    var body: some View {
        Button {
            zoomOut()
        } label: {
            Image(systemName: "minus.magnifyingglass")
                .floatingMapButton()
        }
    }

    private func zoomOut() {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: span.latitudeDelta * 2.0,
            longitudeDelta: span.longitudeDelta * 2.0
        )
        span = newSpan
        region = MKCoordinateRegion(center: region.center, span: newSpan)
    }
}

// MARK: - Legacy Map Zoom Stepper (deprecated)

struct MapZoomStepper: View {
    @Binding var span: MKCoordinateSpan
    @Binding var region: MKCoordinateRegion

    var body: some View {
        Menu {
            Button {
                zoomIn()
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }

            Button {
                zoomOut()
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
        } label: {
            Image(systemName: "plus.forwardslash.minus")
        }
    }

    private func zoomIn() {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: span.latitudeDelta * 0.5,
            longitudeDelta: span.longitudeDelta * 0.5
        )
        span = newSpan
        region = MKCoordinateRegion(center: region.center, span: newSpan)
    }

    private func zoomOut() {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: span.latitudeDelta * 2.0,
            longitudeDelta: span.longitudeDelta * 2.0
        )
        span = newSpan
        region = MKCoordinateRegion(center: region.center, span: newSpan)
    }
}

// MARK: - Map Pitch Toggle

struct MapPitchToggle: View {
    @Binding var pitch: CGFloat

    var body: some View {
        Button {
            togglePitch()
        } label: {
            Image(systemName: pitch > 0 ? "view.3d" : "view.2d")
                .floatingMapButton()
        }
    }

    private func togglePitch() {
        pitch = pitch > 0 ? 0 : 60
    }
}

// MARK: - User Location Button

struct UserLocationButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person")
                .floatingMapButton()
        }
    }
}

// MARK: - Compass Button

struct CompassButton: View {
    var heading: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)

            Image(systemName: "location.north.line.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .rotationEffect(.degrees(-heading))
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .floatingMapButton()

                if isActive {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 6, y: -6)
                }
            }
        }
    }
}
