import MapKit

/// Custom annotation for displaying venues on the map
class VenueAnnotation: NSObject, MKAnnotation {
    let venue: Venue

    var coordinate: CLLocationCoordinate2D {
        venue.coordinate
    }

    var title: String? {
        venue.label
    }

    init(venue: Venue) {
        self.venue = venue
        super.init()
    }
}
