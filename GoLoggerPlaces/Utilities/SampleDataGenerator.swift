import Foundation
import SwiftData
import CoreLocation

/// Generates sample data for App Store screenshots
/// Only used during development - remove before App Store submission
struct SampleDataGenerator {

    /// Generate sample data for screenshots
    /// Call this from a debug menu or temporarily from app launch
    @MainActor
    static func generateSampleData(modelContext: ModelContext) {
        // Clear existing data first
        clearAllData(modelContext: modelContext)

        // Create collections
        let hikingCollection = Collection(name: "Hiking Trails", description: "My favorite hiking spots")
        let cafeCollection = Collection(name: "Coffee Shops", description: "Best cafes in town")
        let parkCollection = Collection(name: "Parks & Nature", description: "Green spaces to explore")
        let bikeCollection = Collection(name: "Bike Routes", description: "Cycling adventures")

        modelContext.insert(hikingCollection)
        modelContext.insert(cafeCollection)
        modelContext.insert(parkCollection)
        modelContext.insert(bikeCollection)

        // Create venues (using San Francisco as example location)
        let venues = [
            createVenue(
                label: "Golden Gate Park",
                latitude: 37.7694,
                longitude: -122.4862,
                address: "Golden Gate Park, San Francisco",
                notes: "Beautiful urban park with gardens and museums",
                collections: [parkCollection, hikingCollection]
            ),
            createVenue(
                label: "Blue Bottle Coffee",
                latitude: 37.7823,
                longitude: -122.4075,
                address: "66 Mint St, San Francisco",
                notes: "Famous SF coffee roaster. Try the New Orleans iced!",
                collections: [cafeCollection]
            ),
            createVenue(
                label: "Lands End Trail",
                latitude: 37.7879,
                longitude: -122.5048,
                address: "Lands End, San Francisco",
                notes: "Stunning coastal views and Golden Gate vistas",
                collections: [hikingCollection, parkCollection]
            ),
            createVenue(
                label: "Sightglass Coffee",
                latitude: 37.7684,
                longitude: -122.4102,
                address: "270 7th St, San Francisco",
                notes: "Great espresso in a beautiful SoMa space",
                collections: [cafeCollection]
            ),
            createVenue(
                label: "Dolores Park",
                latitude: 37.7596,
                longitude: -122.4269,
                address: "Dolores Park, San Francisco",
                notes: "Best city views and people watching",
                collections: [parkCollection]
            ),
            createVenue(
                label: "Crissy Field",
                latitude: 37.8039,
                longitude: -122.4697,
                address: "Crissy Field, San Francisco",
                notes: "Waterfront park with Golden Gate Bridge views",
                collections: [hikingCollection]
            )
        ]

        for venue in venues {
            modelContext.insert(venue)
            // Add some visits to venues
            let visitCount = Int.random(in: 1...4)
            for i in 0..<visitCount {
                let visit = Visit(date: Date().addingTimeInterval(-Double(i * 86400 * Int.random(in: 1...30))))
                venue.addVisit(visit)
                modelContext.insert(visit)
            }
        }

        // Create trails with realistic GPS points following actual paths in San Francisco
        let trails = [
            // Embarcadero waterfront walk
            createTrail(
                name: "Embarcadero Morning Walk",
                hexColor: "#FF6B35",
                points: generateTrailFromWaypoints(
                    waypoints: embarcaderoWalkWaypoints,
                    durationMinutes: 30
                ),
                collections: [hikingCollection, parkCollection]
            ),
            // Golden Gate Park bike ride
            createTrail(
                name: "Golden Gate Park Ride",
                hexColor: "#4ECDC4",
                points: generateTrailFromWaypoints(
                    waypoints: goldenGateParkBikeWaypoints,
                    durationMinutes: 20
                ),
                collections: [bikeCollection]
            ),
            // Lands End trail hike
            createTrail(
                name: "Lands End Trail",
                hexColor: "#2ECC71",
                points: generateTrailFromWaypoints(
                    waypoints: landsEndTrailWaypoints,
                    durationMinutes: 45
                ),
                collections: [hikingCollection, parkCollection]
            ),
            // Dolores Park to Castro walk
            createTrail(
                name: "Mission to Castro Walk",
                hexColor: "#9B59B6",
                points: generateTrailFromWaypoints(
                    waypoints: missionToCastroWaypoints,
                    durationMinutes: 25
                ),
                collections: [hikingCollection]
            ),
            // Marina to Golden Gate bike
            createTrail(
                name: "Marina to Bridge Ride",
                hexColor: "#E74C3C",
                points: generateTrailFromWaypoints(
                    waypoints: marinaToBridgeWaypoints,
                    durationMinutes: 15
                ),
                collections: [bikeCollection]
            )
        ]

        for trail in trails {
            modelContext.insert(trail)
            for point in trail.points {
                modelContext.insert(point)
            }
            trail.updateCache()
        }

        // Update collection caches
        hikingCollection.updateCache()
        cafeCollection.updateCache()
        parkCollection.updateCache()
        bikeCollection.updateCache()

        try? modelContext.save()

        print("✅ Sample data generated successfully!")
    }

    /// Clear all existing data
    @MainActor
    private static func clearAllData(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: TrailPoint.self)
            try modelContext.delete(model: WayPoint.self)
            try modelContext.delete(model: Visit.self)
            try modelContext.delete(model: Link.self)
            try modelContext.delete(model: Trail.self)
            try modelContext.delete(model: Venue.self)
            try modelContext.delete(model: Collection.self)
            try modelContext.save()
        } catch {
            print("Error clearing data: \(error)")
        }
    }

    /// Create a venue with collections
    private static func createVenue(
        label: String,
        latitude: Double,
        longitude: Double,
        address: String?,
        notes: String?,
        collections: [Collection]
    ) -> Venue {
        let venue = Venue(
            latitude: latitude,
            longitude: longitude,
            label: label,
            address: address,
            notes: notes
        )
        venue.collections = collections
        for collection in collections {
            collection.venues.append(venue)
        }
        return venue
    }

    /// Create a trail with points and collections
    private static func createTrail(
        name: String,
        hexColor: String,
        points: [TrailPoint],
        collections: [Collection]
    ) -> Trail {
        let trail = Trail(hexColor: hexColor)
        trail.name = name
        trail.points = points
        trail.collections = collections
        for collection in collections {
            collection.trails.append(trail)
        }
        // Set created date to sometime in the past
        trail.createdOn = Date().addingTimeInterval(-Double.random(in: 86400...2592000)) // 1-30 days ago
        return trail
    }

    /// Generate trail points by interpolating between waypoints
    /// This creates realistic GPS tracks that follow actual paths
    private static func generateTrailFromWaypoints(
        waypoints: [(lat: Double, lon: Double, alt: Double)],
        durationMinutes: Int
    ) -> [TrailPoint] {
        var points: [TrailPoint] = []
        let startTime = Date().addingTimeInterval(-Double(durationMinutes * 60))

        // Calculate total distance for speed estimation
        var totalDistance: Double = 0
        for i in 1..<waypoints.count {
            let loc1 = CLLocation(latitude: waypoints[i-1].lat, longitude: waypoints[i-1].lon)
            let loc2 = CLLocation(latitude: waypoints[i].lat, longitude: waypoints[i].lon)
            totalDistance += loc2.distance(from: loc1)
        }

        let avgSpeed = totalDistance / Double(durationMinutes * 60) // m/s

        // Interpolate points between waypoints
        var accumulatedTime: Double = 0
        for i in 0..<waypoints.count - 1 {
            let start = waypoints[i]
            let end = waypoints[i + 1]

            let loc1 = CLLocation(latitude: start.lat, longitude: start.lon)
            let loc2 = CLLocation(latitude: end.lat, longitude: end.lon)
            let segmentDistance = loc2.distance(from: loc1)

            // Number of points for this segment (roughly one every 10-20 meters)
            let segmentPoints = max(2, Int(segmentDistance / 15))
            let segmentDuration = segmentDistance / avgSpeed

            for j in 0..<segmentPoints {
                let fraction = Double(j) / Double(segmentPoints)

                let lat = start.lat + (end.lat - start.lat) * fraction
                let lon = start.lon + (end.lon - start.lon) * fraction
                let alt = start.alt + (end.alt - start.alt) * fraction

                // Add small GPS noise for realism
                let noisyLat = lat + Double.random(in: -0.00002...0.00002)
                let noisyLon = lon + Double.random(in: -0.00002...0.00002)
                let noisyAlt = alt + Double.random(in: -1...1)

                let timestamp = startTime.addingTimeInterval(accumulatedTime + segmentDuration * fraction)

                // Calculate course (bearing) to next point
                let course = calculateBearing(from: (start.lat, start.lon), to: (end.lat, end.lon))

                // Vary speed slightly
                let speed = avgSpeed + Double.random(in: -avgSpeed * 0.2...avgSpeed * 0.2)

                let point = TrailPoint(
                    latitude: noisyLat,
                    longitude: noisyLon,
                    altitude: noisyAlt,
                    timestamp: timestamp,
                    speed: max(0.5, speed),
                    course: course,
                    horizontalAccuracy: Double.random(in: 3...10)
                )
                points.append(point)
            }

            accumulatedTime += segmentDuration
        }

        // Add final point
        let lastWaypoint = waypoints.last!
        let finalPoint = TrailPoint(
            latitude: lastWaypoint.lat + Double.random(in: -0.00002...0.00002),
            longitude: lastWaypoint.lon + Double.random(in: -0.00002...0.00002),
            altitude: lastWaypoint.alt,
            timestamp: startTime.addingTimeInterval(Double(durationMinutes * 60)),
            speed: 0,
            course: 0,
            horizontalAccuracy: Double.random(in: 3...10)
        )
        points.append(finalPoint)

        return points
    }

    /// Calculate bearing between two coordinates
    private static func calculateBearing(from: (Double, Double), to: (Double, Double)) -> Double {
        let lat1 = from.0 * .pi / 180
        let lat2 = to.0 * .pi / 180
        let dLon = (to.1 - from.1) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }
        return bearing
    }

    // MARK: - Realistic Route Waypoints for San Francisco

    /// Embarcadero waterfront walk - along the SF waterfront
    private static let embarcaderoWalkWaypoints: [(lat: Double, lon: Double, alt: Double)] = [
        (37.7955, -122.3937, 3),   // Start at Ferry Building
        (37.7970, -122.3960, 3),   // Along Embarcadero
        (37.7990, -122.3985, 3),   // Passing Pier 7
        (37.8010, -122.4010, 3),   // Continuing north
        (37.8035, -122.4040, 3),   // Near Pier 15
        (37.8060, -122.4070, 3),   // Exploratorium area
        (37.8080, -122.4095, 3),   // Pier 27
        (37.8060, -122.4070, 3),   // Heading back
        (37.8035, -122.4040, 3),   // Return path
        (37.8010, -122.4010, 3),   // Southbound
        (37.7990, -122.3985, 3),   // Near Pier 7
        (37.7970, -122.3960, 3),   // Almost back
        (37.7955, -122.3937, 3),   // Back at Ferry Building
    ]

    /// Golden Gate Park bike ride - through the park
    private static let goldenGateParkBikeWaypoints: [(lat: Double, lon: Double, alt: Double)] = [
        (37.7694, -122.4530, 60),  // Start at Conservatory of Flowers
        (37.7700, -122.4580, 55),  // Heading west
        (37.7698, -122.4640, 50),  // Past tennis courts
        (37.7695, -122.4700, 48),  // De Young Museum area
        (37.7692, -122.4760, 45),  // Stow Lake nearby
        (37.7690, -122.4820, 42),  // Continuing west
        (37.7688, -122.4880, 40),  // Past Spreckels Lake
        (37.7685, -122.4940, 38),  // Approaching ocean
        (37.7683, -122.5000, 35),  // Near Beach Chalet
        (37.7680, -122.5050, 30),  // Ocean Beach end
    ]

    /// Lands End trail - coastal hiking trail
    private static let landsEndTrailWaypoints: [(lat: Double, lon: Double, alt: Double)] = [
        (37.7879, -122.5048, 50),  // Start at Lands End Lookout
        (37.7872, -122.5070, 55),  // Heading along coast
        (37.7865, -122.5095, 60),  // Climbing up
        (37.7858, -122.5120, 65),  // Mile Rock overlook
        (37.7850, -122.5145, 70),  // Continuing on trail
        (37.7843, -122.5170, 75),  // USS SF Memorial
        (37.7836, -122.5195, 70),  // Descending
        (37.7830, -122.5218, 60),  // Eagle Point
        (37.7824, -122.5240, 50),  // Near Sutro Baths
        (37.7790, -122.5135, 45),  // Sutro Baths ruins
        (37.7783, -122.5115, 40),  // Cliff House area
        (37.7779, -122.5105, 35),  // End at Cliff House
    ]

    /// Mission to Castro walk - through the neighborhoods
    private static let missionToCastroWaypoints: [(lat: Double, lon: Double, alt: Double)] = [
        (37.7596, -122.4269, 25),  // Start at Dolores Park
        (37.7610, -122.4285, 35),  // Up the hill
        (37.7625, -122.4300, 50),  // Climbing
        (37.7640, -122.4318, 65),  // 20th Street
        (37.7655, -122.4335, 80),  // Near Liberty Hill
        (37.7670, -122.4352, 95),  // Continuing up
        (37.7685, -122.4370, 110), // Approaching Castro
        (37.7620, -122.4350, 100), // Castro Street
        (37.7605, -122.4365, 90),  // Castro Theatre area
    ]

    /// Marina to Golden Gate Bridge bike ride
    private static let marinaToBridgeWaypoints: [(lat: Double, lon: Double, alt: Double)] = [
        (37.8030, -122.4370, 5),   // Start at Marina Green
        (37.8039, -122.4450, 5),   // Along Marina Blvd
        (37.8045, -122.4530, 5),   // Crissy Field east
        (37.8040, -122.4610, 5),   // Crissy Field center
        (37.8038, -122.4697, 5),   // Crissy Field west
        (37.8050, -122.4750, 10),  // Warming Hut
        (37.8070, -122.4780, 20),  // Fort Point approach
        (37.8100, -122.4770, 30),  // Climbing to bridge
        (37.8150, -122.4780, 50),  // Near toll plaza
        (37.8199, -122.4783, 70),  // Golden Gate Bridge south tower
    ]
}
