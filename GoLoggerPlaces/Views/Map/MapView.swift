import SwiftUI
import MapKit

/// SwiftUI wrapper for MKMapView
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var venues: [Venue]
    var trails: [Trail]
    var recordingLocations: [CLLocation]  // Current recording trail
    var trailMarkers: [TrailMarkerAnnotation] = []  // Start/end markers for trails
    var onAnnotationTapped: ((Venue) -> Void)?
    var onTrailTapped: (([Trail]) -> Void)?  // Callback when trail(s) are tapped
    var mapType: MKMapType = .standard
    var cameraPitch: CGFloat = 0
    var showAnnotationCallouts: Bool = true
    @Binding var mapHeading: Double
    @Binding var mapSpan: MKCoordinateSpan

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = mapType
        mapView.showsCompass = false  // Disable native compass (we have custom one)

        // Set initial camera with pitch
        let camera = MKMapCamera(
            lookingAtCenter: region.center,
            fromDistance: regionSpanToDistance(span: region.span),
            pitch: cameraPitch,
            heading: 0
        )
        mapView.setCamera(camera, animated: false)

        // Add native scale view (top-left)
        let scale = MKScaleView(mapView: mapView)
        scale.scaleVisibility = .visible
        scale.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(scale)

        // Position scale
        NSLayoutConstraint.activate([
            scale.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 8),
            scale.leadingAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.leadingAnchor, constant: 8)
        ])

        // Add tap gesture recognizer for trail selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    private func regionSpanToDistance(span: MKCoordinateSpan) -> CLLocationDistance {
        // Approximate conversion from span to distance
        // This is a rough calculation; exact conversion depends on latitude
        let metersPerDegree: Double = 111_000 // Approximate meters per degree of latitude
        return span.latitudeDelta * metersPerDegree * 2
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type if changed
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Update camera if region or pitch changed
        let currentCamera = mapView.camera
        let centerChanged = abs(currentCamera.centerCoordinate.latitude - region.center.latitude) > 0.001 ||
                           abs(currentCamera.centerCoordinate.longitude - region.center.longitude) > 0.001
        let pitchChanged = abs(currentCamera.pitch - cameraPitch) > 0.1

        if pitchChanged && !centerChanged {
            // Only pitch changed - preserve exact altitude and position
            let camera = MKMapCamera(
                lookingAtCenter: currentCamera.centerCoordinate,
                fromDistance: currentCamera.altitude,
                pitch: cameraPitch,
                heading: currentCamera.heading
            )
            // Use non-animated update to prevent Metal synchronization issues
            mapView.setCamera(camera, animated: false)
        } else if centerChanged {
            // Region center changed - recalculate from span
            let camera = MKMapCamera(
                lookingAtCenter: region.center,
                fromDistance: regionSpanToDistance(span: region.span),
                pitch: cameraPitch,
                heading: currentCamera.heading
            )
            // Use non-animated update to prevent Metal synchronization issues
            mapView.setCamera(camera, animated: false)
        }

        // Update venue annotations
        context.coordinator.updateAnnotations(mapView: mapView, venues: venues)

        // Update trail markers
        context.coordinator.updateTrailMarkers(mapView: mapView, markers: trailMarkers)

        // Update trail overlays
        context.coordinator.updateOverlays(mapView: mapView, trails: trails, recordingLocations: recordingLocations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            parent: self,
            onAnnotationTapped: onAnnotationTapped,
            onTrailTapped: onTrailTapped
        )
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        // Ensure all pending operations are cancelled
        coordinator.regionUpdateWorkItem?.cancel()

        // Remove all overlays and annotations to release resources
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Set delegate to nil to prevent callbacks during deallocation
        mapView.delegate = nil
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let parent: MapView
        let onAnnotationTapped: ((Venue) -> Void)?
        let onTrailTapped: (([Trail]) -> Void)?

        // Cache to track what's currently displayed
        private var currentVenueIDs: Set<UUID> = []
        private var currentTrailMarkerIDs: Set<String> = []
        private var currentTrailIDs: Set<UUID> = []
        private var currentTrailColors: [UUID: String] = [:]  // Track trail colors
        private var hasRecordingOverlay = false
        private var recordingLocationCount = 0

        // Debounce timer for region updates
        fileprivate var regionUpdateWorkItem: DispatchWorkItem?

        init(
            parent: MapView,
            onAnnotationTapped: ((Venue) -> Void)?,
            onTrailTapped: (([Trail]) -> Void)?
        ) {
            self.parent = parent
            self.onAnnotationTapped = onAnnotationTapped
            self.onTrailTapped = onTrailTapped
        }

        // MARK: - Annotation Management

        func updateAnnotations(mapView: MKMapView, venues: [Venue]) {
            let newVenueIDs = Set(venues.map { $0.id })

            // Only update if the venue set has actually changed
            guard newVenueIDs != currentVenueIDs else {
                return
            }

            let existingAnnotations = mapView.annotations.compactMap { $0 as? VenueAnnotation }
            let existingIDs = Set(existingAnnotations.map { $0.venue.id })

            // Remove annotations that are no longer needed
            let toRemove = existingAnnotations.filter { !newVenueIDs.contains($0.venue.id) }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }

            // Add new annotations
            let toAdd = venues.filter { !existingIDs.contains($0.id) }
            if !toAdd.isEmpty {
                let newAnnotations = toAdd.map { VenueAnnotation(venue: $0) }
                mapView.addAnnotations(newAnnotations)
            }

            currentVenueIDs = newVenueIDs
        }

        func updateTrailMarkers(mapView: MKMapView, markers: [TrailMarkerAnnotation]) {
            // Create unique identifiers for markers (coordinate + type)
            let markerIdentifier = { (marker: TrailMarkerAnnotation) -> String in
                "\(marker.coordinate.latitude),\(marker.coordinate.longitude)-\(marker.type)"
            }

            let newMarkerIDs = Set(markers.map { markerIdentifier($0) })

            // Only update if markers have actually changed
            guard newMarkerIDs != currentTrailMarkerIDs else {
                return
            }

            let existingMarkers = mapView.annotations.compactMap { $0 as? TrailMarkerAnnotation }
            let existingIDs = Set(existingMarkers.map { markerIdentifier($0) })

            // Remove markers that are no longer needed
            let toRemove = existingMarkers.filter { !newMarkerIDs.contains(markerIdentifier($0)) }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }

            // Add new markers
            let toAdd = markers.filter { !existingIDs.contains(markerIdentifier($0)) }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }

            currentTrailMarkerIDs = newMarkerIDs
        }

        // MARK: - Overlay Management

        func updateOverlays(mapView: MKMapView, trails: [Trail], recordingLocations: [CLLocation]) {
            let newTrailIDs = Set(trails.map { $0.id })
            let newTrailColors = Dictionary(uniqueKeysWithValues: trails.map { ($0.id, $0.hexColor) })
            let hasRecording = recordingLocations.count > 1

            // Check if anything has actually changed
            let trailsChanged = newTrailIDs != currentTrailIDs
            let colorsChanged = newTrailColors != currentTrailColors
            let recordingChanged = hasRecording != hasRecordingOverlay || recordingLocations.count != recordingLocationCount

            guard trailsChanged || colorsChanged || recordingChanged else {
                return
            }

            // Get existing overlays
            let existingPolylines = mapView.overlays.compactMap { $0 as? MKPolyline }

            // Separate recording overlay from trail overlays
            let recordingOverlays = existingPolylines.filter { $0.title == "recording" }
            let trailOverlays = existingPolylines.filter { $0.title != "recording" }

            // Update trail overlays if they changed or if colors changed
            if trailsChanged || colorsChanged {
                // Remove old trail overlays
                if !trailOverlays.isEmpty {
                    mapView.removeOverlays(trailOverlays)
                }

                // Add new trail overlays
                for trail in trails {
                    let coordinates = trail.points
                        .sorted(by: { $0.timestamp < $1.timestamp })
                        .map { $0.coordinate }
                    if coordinates.count > 1 {
                        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                        polyline.subtitle = trail.hexColor
                        mapView.addOverlay(polyline)
                    }
                }

                currentTrailIDs = newTrailIDs
                currentTrailColors = newTrailColors
            }

            // Update recording overlay if it changed
            if recordingChanged {
                // Remove old recording overlay if it exists
                if !recordingOverlays.isEmpty {
                    mapView.removeOverlays(recordingOverlays)
                }

                // Add new recording overlay if recording
                if hasRecording {
                    let coordinates = recordingLocations.map { $0.coordinate }
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    polyline.title = "recording"
                    mapView.addOverlay(polyline)
                }

                hasRecordingOverlay = hasRecording
                recordingLocationCount = recordingLocations.count
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location
            if annotation is MKUserLocation {
                return nil
            }

            // Handle trail markers
            if let trailMarker = annotation as? TrailMarkerAnnotation {
                let identifier = "TrailMarkerAnnotation"
                let annotationView: MKMarkerAnnotationView

                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    annotationView = dequeuedView
                    annotationView.annotation = annotation
                } else {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView.displayPriority = .required
                }

                // Customize based on marker type
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

            // Handle cluster annotations
            if annotation is MKClusterAnnotation {
                let identifier = "ClusterAnnotation"
                let annotationView: MKMarkerAnnotationView

                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    annotationView = dequeuedView
                    annotationView.annotation = annotation
                } else {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }

                // Customize cluster appearance
                annotationView.markerTintColor = .systemPurple
                annotationView.glyphImage = nil  // Shows count badge

                return annotationView
            }

            guard annotation is VenueAnnotation else {
                return nil
            }

            let identifier = "VenueAnnotation"
            let annotationView: MKMarkerAnnotationView

            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                annotationView = dequeuedView
                annotationView.annotation = annotation
            } else {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = parent.showAnnotationCallouts
                if parent.showAnnotationCallouts {
                    annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                }
                // Enable clustering
                annotationView.clusteringIdentifier = "VenueCluster"
            }

            // Customize marker appearance
            annotationView.markerTintColor = .systemBlue
            annotationView.glyphImage = UIImage(systemName: "mappin.circle.fill")

            return annotationView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let venueAnnotation = view.annotation as? VenueAnnotation else {
                return
            }

            onAnnotationTapped?(venueAnnotation.venue)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Cancel any pending region updates
            regionUpdateWorkItem?.cancel()

            // Debounce region updates to prevent rapid feedback loops
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Use weak reference to parent to prevent retain cycles
                self.parent.region = mapView.region
                self.parent.mapHeading = mapView.camera.heading
                self.parent.mapSpan = mapView.region.span
            }

            regionUpdateWorkItem = workItem

            // Small delay to debounce rapid changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }

        deinit {
            // Cancel any pending work items to prevent crashes
            regionUpdateWorkItem?.cancel()
        }

        // MARK: - Tap Gesture Handling

        @objc func handleMapTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard gestureRecognizer.state == .ended,
                  let mapView = gestureRecognizer.view as? MKMapView else {
                return
            }

            let tapPoint = gestureRecognizer.location(in: mapView)
            let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)

            // Find trails near the tap point
            let tappedTrails = findTrailsNearPoint(tapPoint, coordinate: tapCoordinate, in: mapView)

            // If we found trails, call the callback
            if !tappedTrails.isEmpty {
                onTrailTapped?(tappedTrails)
            }
        }

        // UIGestureRecognizerDelegate - allow tap gesture to work alongside other gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        private func findTrailsNearPoint(_ tapPoint: CGPoint, coordinate: CLLocationCoordinate2D, in mapView: MKMapView) -> [Trail] {
            let tapTolerance: CGFloat = 30  // Points on screen
            var nearbyTrails: [(trail: Trail, distance: CGFloat)] = []

            for trail in parent.trails {
                // Get sorted points for the trail
                let sortedPoints = trail.points.sorted { $0.timestamp < $1.timestamp }
                guard sortedPoints.count > 1 else { continue }

                // Check if any segment of the trail is near the tap point
                for i in 1..<sortedPoints.count {
                    let point1 = sortedPoints[i - 1]
                    let point2 = sortedPoints[i]

                    let coord1 = CLLocationCoordinate2D(latitude: point1.latitude, longitude: point1.longitude)
                    let coord2 = CLLocationCoordinate2D(latitude: point2.latitude, longitude: point2.longitude)

                    // Convert coordinates to screen points
                    let screenPoint1 = mapView.convert(coord1, toPointTo: mapView)
                    let screenPoint2 = mapView.convert(coord2, toPointTo: mapView)

                    // Calculate distance from tap point to line segment
                    let distance = distanceFromPointToLineSegment(
                        point: tapPoint,
                        lineStart: screenPoint1,
                        lineEnd: screenPoint2
                    )

                    if distance <= tapTolerance {
                        // Trail is within tap tolerance
                        nearbyTrails.append((trail: trail, distance: distance))
                        break  // Don't check other segments of this trail
                    }
                }
            }

            // Sort by distance and return trails (closest first)
            return nearbyTrails
                .sorted { $0.distance < $1.distance }
                .map { $0.trail }
        }

        /// Calculate perpendicular distance from a point to a line segment
        private func distanceFromPointToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
            let dx = lineEnd.x - lineStart.x
            let dy = lineEnd.y - lineStart.y

            // If the line segment is actually a point
            if dx == 0 && dy == 0 {
                return hypot(point.x - lineStart.x, point.y - lineStart.y)
            }

            // Calculate the parameter t that represents the point on the line segment
            // closest to the given point (clamped to [0, 1] to stay on the segment)
            let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)))

            // Calculate the closest point on the line segment
            let closestX = lineStart.x + t * dx
            let closestY = lineStart.y + t * dy

            // Return the distance from the point to the closest point on the segment
            return hypot(point.x - closestX, point.y - closestY)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // Style the recording trail differently
                if polyline.title == "recording" {
                    renderer.strokeColor = .systemRed
                    renderer.lineWidth = 4
                } else {
                    // Use the trail's custom hex color (stored in subtitle)
                    if let hexColor = polyline.subtitle,
                       let color = UIColor(hex: hexColor) {
                        renderer.strokeColor = color
                    } else {
                        // Fallback to system blue if no color is set
                        renderer.strokeColor = .systemBlue
                    }
                    renderer.lineWidth = 3
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Trail Marker Annotation

enum TrailMarkerType {
    case start
    case end
}

class TrailMarkerAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let type: TrailMarkerType

    var title: String? {
        type == .start ? "Start" : "End"
    }

    init(coordinate: CLLocationCoordinate2D, type: TrailMarkerType) {
        self.coordinate = coordinate
        self.type = type
        super.init()
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    /// Initialize UIColor from hex string (e.g., "#FF5733" or "FF5733")
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else {
            return nil
        }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// Convert UIColor to hex string
    func toHexString() -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }

        let red = Int(components[0] * 255.0)
        let green = Int(components[1] * 255.0)
        let blue = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
