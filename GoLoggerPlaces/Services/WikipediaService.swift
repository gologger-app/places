import Foundation
import CoreLocation

/// Service for fetching nearby places from Wikipedia
@MainActor
class WikipediaService: ObservableObject {
    @Published var nearbyPlaces: [WikipediaPlace] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Cache with expiration (1 hour)
    private var cache: [String: (places: [WikipediaPlace], timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 3600

    private let baseURL = "https://en.wikipedia.org/w/api.php"
    private let searchRadius = 1000 // meters
    private let maxResults = 10

    /// Fetch nearby Wikipedia articles for a coordinate
    func fetchNearbyPlaces(latitude: Double, longitude: Double) {
        let cacheKey = "\(latitude),\(longitude)"

        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            self.nearbyPlaces = cached.places
            return
        }

        Task {
            isLoading = true
            errorMessage = nil

            do {
                // Step 1: Geosearch to find nearby articles
                let geosearchResults = try await performGeosearch(latitude: latitude, longitude: longitude)

                // Step 2: Fetch page info (summaries and thumbnails) for each result
                let places = try await fetchPageInfo(for: geosearchResults)

                // Update cache and published property
                cache[cacheKey] = (places: places, timestamp: Date())
                self.nearbyPlaces = places
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.nearbyPlaces = []
                self.isLoading = false
            }
        }
    }

    /// Perform geosearch to find nearby Wikipedia articles
    private func performGeosearch(latitude: Double, longitude: Double) async throws -> [WikipediaGeosearchResponse.GeosearchResult] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "geosearch"),
            URLQueryItem(name: "gscoord", value: "\(latitude)|\(longitude)"),
            URLQueryItem(name: "gsradius", value: "\(searchRadius)"),
            URLQueryItem(name: "gslimit", value: "\(maxResults)"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw WikipediaError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WikipediaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw WikipediaError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let geosearchResponse = try decoder.decode(WikipediaGeosearchResponse.self, from: data)

        return geosearchResponse.query.geosearch
    }

    /// Fetch page information (summary and thumbnail) for multiple page IDs
    private func fetchPageInfo(for geosearchResults: [WikipediaGeosearchResponse.GeosearchResult]) async throws -> [WikipediaPlace] {
        guard !geosearchResults.isEmpty else {
            return []
        }

        let pageIds = geosearchResults.map { String($0.pageid) }.joined(separator: "|")

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "prop", value: "extracts|pageimages"),
            URLQueryItem(name: "pageids", value: pageIds),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exsentences", value: "2"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "100"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw WikipediaError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WikipediaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw WikipediaError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let pageInfoResponse = try decoder.decode(WikipediaPageInfoResponse.self, from: data)

        // Combine geosearch results with page info
        var places: [WikipediaPlace] = []

        for geosearchResult in geosearchResults {
            let pageIdString = String(geosearchResult.pageid)

            if let page = pageInfoResponse.query.pages[pageIdString] {
                let summary = page.extract ?? "No summary available"
                let thumbnailURL = page.thumbnail.flatMap { URL(string: $0.source) }
                let pageURL = URL(string: "https://en.wikipedia.org/?curid=\(page.pageid)")!

                let place = WikipediaPlace(
                    id: page.pageid,
                    title: page.title,
                    summary: summary,
                    thumbnailURL: thumbnailURL,
                    pageURL: pageURL,
                    distance: geosearchResult.dist,
                    latitude: geosearchResult.lat,
                    longitude: geosearchResult.lon
                )

                places.append(place)
            }
        }

        // Sort by distance
        places.sort { $0.distance < $1.distance }

        return places
    }
}

// MARK: - Errors

enum WikipediaError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Wikipedia API URL"
        case .invalidResponse:
            return "Invalid response from Wikipedia"
        case .httpError(let code):
            return "Wikipedia API error (HTTP \(code))"
        }
    }
}
