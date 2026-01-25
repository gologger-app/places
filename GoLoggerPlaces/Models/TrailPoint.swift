//
//  TrailPoint.swift
//  GoLoggerPlaces
//
//  Created by kalle on 12/14/25.
//


import Foundation
import SwiftData
import CoreLocation

/// Model representing a single location point in a trail
@Model
final class TrailPoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var timestamp: Date
    var speed: Double?  // m/s
    var course: Double?  // Degrees from north
    var horizontalAccuracy: Double?  // Meters

    // Back reference to parent Trail (set via inverse relationship)
    var trail: Trail?

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date = Date(),
        speed: Double? = nil,
        course: Double? = nil,
        horizontalAccuracy: Double? = nil
    ) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
    }

    /// Convenience initializer from CLLocation
    convenience init(from location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp,
            speed: location.speed >= 0 ? location.speed : nil,
            course: location.course >= 0 ? location.course : nil,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }

    /// Convert to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}