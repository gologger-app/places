import Foundation
import CoreLocation

/// Represents a Wikipedia article about a nearby place
struct WikipediaPlace: Identifiable, Codable {
    let id: Int              // Wikipedia page ID
    let title: String
    let summary: String      // Short extract from article
    let thumbnailURL: URL?
    let pageURL: URL
    let distance: Double     // Distance in meters from reference point
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Wikipedia API Response Models

/// Response from Wikipedia Geosearch API
struct WikipediaGeosearchResponse: Codable {
    let query: GeosearchQuery

    struct GeosearchQuery: Codable {
        let geosearch: [GeosearchResult]
    }

    struct GeosearchResult: Codable {
        let pageid: Int
        let title: String
        let lat: Double
        let lon: Double
        let dist: Double
    }
}

/// Response from Wikipedia Page Info API
struct WikipediaPageInfoResponse: Codable {
    let query: PageQuery

    struct PageQuery: Codable {
        let pages: [String: Page]
    }

    struct Page: Codable {
        let pageid: Int
        let title: String
        let extract: String?
        let thumbnail: Thumbnail?

        struct Thumbnail: Codable {
            let source: String
        }
    }
}
