import SwiftUI
import MapKit
import CoreLocation

/// A map view that displays a trail with color-coded segments based on speed or altitude
struct GradientMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let trail: Trail
    let trailMarkers: [TrailMarkerAnnotation]
    let colorMode: MapColorMode
    var isInteractive: Bool = false

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.mapType = .standard
        mapView.showsCompass = isInteractive
        mapView.isUserInteractionEnabled = isInteractive
        mapView.isZoomEnabled = isInteractive
        mapView.isScrollEnabled = isInteractive
        mapView.isPitchEnabled = isInteractive
        mapView.isRotateEnabled = isInteractive

        // Set initial region
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update markers
        context.coordinator.updateTrailMarkers(mapView: mapView, markers: trailMarkers)

        // Update gradient overlays based on color mode
        context.coordinator.updateGradientOverlays(
            mapView: mapView,
            trail: trail,
            colorMode: colorMode
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        mapView.delegate = nil
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: GradientMapView
        private var currentTrailMarkerIDs: Set<String> = []
        private var currentColorMode: MapColorMode?
        private var currentTrailID: UUID?

        init(parent: GradientMapView) {
            self.parent = parent
        }

        func updateTrailMarkers(mapView: MKMapView, markers: [TrailMarkerAnnotation]) {
            let markerIdentifier = { (marker: TrailMarkerAnnotation) -> String in
                "\(marker.coordinate.latitude),\(marker.coordinate.longitude)-\(marker.type)"
            }

            let newMarkerIDs = Set(markers.map { markerIdentifier($0) })

            guard newMarkerIDs != currentTrailMarkerIDs else { return }

            let existingMarkers = mapView.annotations.compactMap { $0 as? TrailMarkerAnnotation }
            let existingIDs = Set(existingMarkers.map { markerIdentifier($0) })

            let toRemove = existingMarkers.filter { !newMarkerIDs.contains(markerIdentifier($0)) }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }

            let toAdd = markers.filter { !existingIDs.contains(markerIdentifier($0)) }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }

            currentTrailMarkerIDs = newMarkerIDs
        }

        func updateGradientOverlays(mapView: MKMapView, trail: Trail, colorMode: MapColorMode) {
            // Only update if trail or color mode changed
            let needsUpdate = currentTrailID != trail.id || currentColorMode != colorMode

            guard needsUpdate else { return }

            // Remove existing overlays
            mapView.removeOverlays(mapView.overlays)

            // Get sorted points
            let sortedPoints = trail.points.sorted { $0.timestamp < $1.timestamp }
            guard sortedPoints.count > 1 else { return }

            // Calculate values for gradient (speed or altitude)
            var values: [Double] = []

            switch colorMode {
            case .simple:
                // Simple mode should not use GradientMapView
                // This case should never be reached in practice
                return

            case .speed:
                // Calculate speed between consecutive points
                for i in 1..<sortedPoints.count {
                    let currentPoint = sortedPoints[i]
                    let previousPoint = sortedPoints[i - 1]

                    let currentLocation = CLLocation(
                        latitude: currentPoint.latitude,
                        longitude: currentPoint.longitude
                    )
                    let previousLocation = CLLocation(
                        latitude: previousPoint.latitude,
                        longitude: previousPoint.longitude
                    )

                    let distance = currentLocation.distance(from: previousLocation)
                    let timeDiff = currentPoint.timestamp.timeIntervalSince(previousPoint.timestamp)

                    if timeDiff > 0 {
                        let speedMps = distance / timeDiff
                        let speedKph = speedMps * 3.6
                        values.append(speedKph)
                    } else {
                        values.append(0)
                    }
                }

            case .altitude:
                // Use altitude values
                for point in sortedPoints.dropFirst() {
                    values.append(point.altitude ?? 0)
                }
            }

            // Normalize values to 0-1 range for color mapping
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = maxValue - minValue

            // Create colored segments
            for i in 1..<sortedPoints.count {
                let startPoint = sortedPoints[i - 1]
                let endPoint = sortedPoints[i]

                let coordinates = [startPoint.coordinate, endPoint.coordinate]
                let polyline = MKPolyline(coordinates: coordinates, count: 2)

                // Calculate normalized value for color
                let value = values[i - 1]
                let normalizedValue = range > 0 ? (value - minValue) / range : 0.5

                // Store the normalized value in the polyline's subtitle for rendering
                polyline.subtitle = String(normalizedValue)
                polyline.title = String(describing: colorMode)

                mapView.addOverlay(polyline)
            }

            currentTrailID = trail.id
            currentColorMode = colorMode
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let trailMarker = annotation as? TrailMarkerAnnotation else {
                return nil
            }

            let identifier = "TrailMarkerAnnotation"
            let annotationView: MKMarkerAnnotationView

            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                annotationView = dequeuedView
                annotationView.annotation = annotation
            } else {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.displayPriority = .required
            }

            switch trailMarker.type {
            case .start:
                annotationView.markerTintColor = .systemGreen
                annotationView.glyphImage = UIImage(systemName: "play.circle.fill")
            case .end:
                annotationView.markerTintColor = .systemRed
                annotationView.glyphImage = UIImage(systemName: "checkered.flag.fill")
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline,
                  let normalizedValueString = polyline.subtitle,
                  let normalizedValue = Double(normalizedValueString),
                  let colorModeString = polyline.title else {
                let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3
                return renderer
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 4

            // Determine color based on mode and normalized value
            let isSpeedMode = colorModeString == "speed"
            renderer.strokeColor = colorForValue(normalizedValue, isSpeed: isSpeedMode)

            return renderer
        }

        /// Map normalized value (0-1) to a color gradient
        private func colorForValue(_ normalizedValue: Double, isSpeed: Bool) -> UIColor {
            let clamped = max(0, min(1, normalizedValue))

            if isSpeed {
                // Speed gradient: green -> yellow -> orange -> red
                switch clamped {
                case 0..<0.33:
                    // Green to yellow
                    let t = clamped / 0.33
                    return interpolateColor(from: .systemGreen, to: .systemYellow, progress: t)
                case 0.33..<0.67:
                    // Yellow to orange
                    let t = (clamped - 0.33) / 0.34
                    return interpolateColor(from: .systemYellow, to: .systemOrange, progress: t)
                default:
                    // Orange to red
                    let t = (clamped - 0.67) / 0.33
                    return interpolateColor(from: .systemOrange, to: .systemRed, progress: t)
                }
            } else {
                // Altitude gradient: blue -> cyan -> green -> yellow -> orange
                switch clamped {
                case 0..<0.25:
                    let t = clamped / 0.25
                    return interpolateColor(from: .systemBlue, to: .systemCyan, progress: t)
                case 0.25..<0.5:
                    let t = (clamped - 0.25) / 0.25
                    return interpolateColor(from: .systemCyan, to: .systemGreen, progress: t)
                case 0.5..<0.75:
                    let t = (clamped - 0.5) / 0.25
                    return interpolateColor(from: .systemGreen, to: .systemYellow, progress: t)
                default:
                    let t = (clamped - 0.75) / 0.25
                    return interpolateColor(from: .systemYellow, to: .systemOrange, progress: t)
                }
            }
        }

        /// Interpolate between two colors
        private func interpolateColor(from: UIColor, to: UIColor, progress: Double) -> UIColor {
            var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
            var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0

            from.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
            to.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

            let t = CGFloat(progress)
            return UIColor(
                red: fromR + (toR - fromR) * t,
                green: fromG + (toG - fromG) * t,
                blue: fromB + (toB - fromB) * t,
                alpha: fromA + (toA - fromA) * t
            )
        }
    }
}
