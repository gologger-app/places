//
//  Link.swift
//  GoLoggerPlaces
//
//  Created on 2025-11-22.
//

import Foundation
import SwiftData

@Model
final class Link {
    var id: UUID
    var name: String?
    var url: String?

    // Back references
    var venue: Venue?
    var trail: Trail?

    init(name: String? = nil, url: String? = nil) {
        self.id = UUID()
        self.name = name
        self.url = url
    }

    // MARK: - Computed Properties

    /// Returns a display name for the link, using URL as fallback
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return url ?? "Unnamed Link"
    }

    /// Validates if the URL string is a valid URL format
    var isValidURL: Bool {
        guard let urlString = url, !urlString.isEmpty else {
            return false
        }

        // Check if it's a valid URL
        if let url = URL(string: urlString) {
            // Check if it has a scheme (http, https, etc.)
            return url.scheme != nil
        }

        return false
    }

    /// Returns a URL object if the url string is valid
    var validURL: URL? {
        guard isValidURL, let urlString = url else {
            return nil
        }
        return URL(string: urlString)
    }
}
