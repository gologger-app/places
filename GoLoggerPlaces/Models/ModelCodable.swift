import Foundation

// MARK: - Exportable Data Structures

/// Wrapper for all exportable data
struct ExportData: Codable {
    let collections: [CollectionExport]
    let venues: [VenueExport]
    let trails: [TrailExport]
    let exportDate: Date
    let version: String

    enum CodingKeys: String, CodingKey {
        case collections, venues, trails, exportDate, version
        // Backward compatibility for old top-level arrays
        case trailPoints, wayPoints, visits, links
    }

    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collections = try container.decode([CollectionExport].self, forKey: .collections)
        venues = try container.decode([VenueExport].self, forKey: .venues)
        trails = try container.decode([TrailExport].self, forKey: .trails)
        exportDate = try container.decode(Date.self, forKey: .exportDate)
        version = try container.decode(String.self, forKey: .version)

        // Ignore old top-level arrays if present - they're now nested in venues/trails
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(collections, forKey: .collections)
        try container.encode(venues, forKey: .venues)
        try container.encode(trails, forKey: .trails)
        try container.encode(exportDate, forKey: .exportDate)
        try container.encode(version, forKey: .version)
    }

    // Standard init for encoding
    init(collections: [CollectionExport], venues: [VenueExport], trails: [TrailExport],
         exportDate: Date, version: String) {
        self.collections = collections
        self.venues = venues
        self.trails = trails
        self.exportDate = exportDate
        self.version = version
    }
}

// MARK: - Collection Export

struct CollectionExport: Codable {
    let id: UUID
    let name: String
    let collectionDescription: String?
    let editDate: Date
    let venueIDs: [UUID]
    let trailIDs: [UUID]
}

extension Collection {
    func toExport() -> CollectionExport {
        CollectionExport(
            id: id,
            name: name,
            collectionDescription: collectionDescription,
            editDate: editDate,
            venueIDs: venues.map { $0.id },
            trailIDs: trails.map { $0.id }
        )
    }
}

// MARK: - Venue Export

struct VenueExport: Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let label: String
    let address: String?
    let notes: String?
    let createdOn: Date
    let editDate: Date
    let collectionIDs: [UUID]
    let visits: [VisitExport]
    let links: [LinkExport]

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, altitude, label, address, notes
        case createdOn, editDate, collectionIDs, visits, links
        // Backward compatibility for old field names
        case createdDate, visitIDs, linkIDs
    }

    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        label = try container.decode(String.self, forKey: .label)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        // Support both old (createdDate) and new (createdOn) field names
        if let createdOn = try? container.decode(Date.self, forKey: .createdOn) {
            self.createdOn = createdOn
        } else {
            self.createdOn = try container.decode(Date.self, forKey: .createdDate)
        }
        editDate = try container.decode(Date.self, forKey: .editDate)
        collectionIDs = try container.decode([UUID].self, forKey: .collectionIDs)
        visits = try container.decodeIfPresent([VisitExport].self, forKey: .visits) ?? []
        links = try container.decodeIfPresent([LinkExport].self, forKey: .links) ?? []
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdOn, forKey: .createdOn)
        try container.encode(editDate, forKey: .editDate)
        try container.encode(collectionIDs, forKey: .collectionIDs)
        try container.encode(visits, forKey: .visits)
        try container.encode(links, forKey: .links)
    }

    // Standard init for encoding
    init(id: UUID, latitude: Double, longitude: Double, altitude: Double?, label: String,
         address: String?, notes: String?, createdOn: Date, editDate: Date,
         collectionIDs: [UUID], visits: [VisitExport], links: [LinkExport]) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.label = label
        self.address = address
        self.notes = notes
        self.createdOn = createdOn
        self.editDate = editDate
        self.collectionIDs = collectionIDs
        self.visits = visits
        self.links = links
    }
}

extension Venue {
    func toExport() -> VenueExport {
        // Sort visits by date for export
        let sortedVisits = visits.sorted { $0.date < $1.date }

        return VenueExport(
            id: id,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            label: label,
            address: address,
            notes: notes,
            createdOn: createdOn,
            editDate: editDate,
            collectionIDs: collections.map { $0.id },
            visits: sortedVisits.map { $0.toExport() },
            links: links.map { $0.toExport() }
        )
    }
}

// MARK: - Trail Export

struct TrailExport: Codable {
    let id: UUID
    let name: String?
    let notes: String?
    let startAddress: String?
    let endAddress: String?
    let travelModeRaw: String
    let totalDistance: Double?
    let actualDuration: TimeInterval?
    let startTime: Date?
    let endTime: Date?
    let createdOn: Date
    let editDate: Date
    let hexColor: String
    let points: [TrailPointExport]
    let waypoints: [WayPointExport]
    let collectionIDs: [UUID]
    let links: [LinkExport]

    enum CodingKeys: String, CodingKey {
        case id, name, notes, startAddress, endAddress, travelModeRaw, totalDistance, actualDuration, startTime, endTime
        case createdOn, editDate, hexColor, points, waypoints, collectionIDs, links
        // Backward compatibility for old field names
        case pointIDs, waypointIDs, linkIDs
    }

    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startAddress = try container.decodeIfPresent(String.self, forKey: .startAddress)
        endAddress = try container.decodeIfPresent(String.self, forKey: .endAddress)
        travelModeRaw = try container.decode(String.self, forKey: .travelModeRaw)
        totalDistance = try container.decodeIfPresent(Double.self, forKey: .totalDistance)
        actualDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .actualDuration)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        // For backward compatibility, use editDate as createdOn if createdOn is not present
        createdOn = try container.decodeIfPresent(Date.self, forKey: .createdOn) ?? container.decode(Date.self, forKey: .editDate)
        editDate = try container.decode(Date.self, forKey: .editDate)
        hexColor = try container.decode(String.self, forKey: .hexColor)
        points = try container.decodeIfPresent([TrailPointExport].self, forKey: .points) ?? []
        waypoints = try container.decodeIfPresent([WayPointExport].self, forKey: .waypoints) ?? []
        collectionIDs = try container.decode([UUID].self, forKey: .collectionIDs)
        links = try container.decodeIfPresent([LinkExport].self, forKey: .links) ?? []
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(startAddress, forKey: .startAddress)
        try container.encodeIfPresent(endAddress, forKey: .endAddress)
        try container.encode(travelModeRaw, forKey: .travelModeRaw)
        try container.encodeIfPresent(totalDistance, forKey: .totalDistance)
        try container.encodeIfPresent(actualDuration, forKey: .actualDuration)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(createdOn, forKey: .createdOn)
        try container.encode(editDate, forKey: .editDate)
        try container.encode(hexColor, forKey: .hexColor)
        try container.encode(points, forKey: .points)
        try container.encode(waypoints, forKey: .waypoints)
        try container.encode(collectionIDs, forKey: .collectionIDs)
        try container.encode(links, forKey: .links)
    }

    // Standard init for encoding
    init(id: UUID, name: String?, notes: String?, startAddress: String?, endAddress: String?,
         travelModeRaw: String, totalDistance: Double?, actualDuration: TimeInterval?,
         startTime: Date?, endTime: Date?, createdOn: Date, editDate: Date, hexColor: String,
         points: [TrailPointExport], waypoints: [WayPointExport], collectionIDs: [UUID], links: [LinkExport]) {
        self.id = id
        self.name = name
        self.notes = notes
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.travelModeRaw = travelModeRaw
        self.totalDistance = totalDistance
        self.actualDuration = actualDuration
        self.startTime = startTime
        self.endTime = endTime
        self.createdOn = createdOn
        self.editDate = editDate
        self.hexColor = hexColor
        self.points = points
        self.waypoints = waypoints
        self.collectionIDs = collectionIDs
        self.links = links
    }
}

extension Trail {
    func toExport() -> TrailExport {
        // Sort points by timestamp for export
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        // Sort waypoints by visit time for export
        let sortedWaypoints = waypoints.sorted { $0.visitTime < $1.visitTime }

        return TrailExport(
            id: id,
            name: name,
            notes: notes,
            startAddress: startAddress,
            endAddress: endAddress,
            travelModeRaw: "walking",  // Default for backward compatibility
            totalDistance: totalDistance,
            actualDuration: actualDuration,
            startTime: startTime,
            endTime: endTime,
            createdOn: createdOn,
            editDate: editDate,
            hexColor: hexColor,
            points: sortedPoints.map { $0.toExport() },
            waypoints: sortedWaypoints.map { $0.toExport() },
            collectionIDs: collections.map { $0.id },
            links: links.map { $0.toExport() }
        )
    }
}

// MARK: - TrailPoint Export

struct TrailPointExport: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date
    let speed: Double?
    let course: Double?
    let horizontalAccuracy: Double?
}

extension TrailPoint {
    func toExport() -> TrailPointExport {
        TrailPointExport(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            timestamp: timestamp,
            speed: speed,
            course: course,
            horizontalAccuracy: horizontalAccuracy
        )
    }
}

// MARK: - WayPoint Export

struct WayPointExport: Codable {
    let label: String
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let visitTime: Date
}

extension WayPoint {
    func toExport() -> WayPointExport {
        WayPointExport(
            label: label,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            visitTime: visitTime
        )
    }
}

// MARK: - Visit Export

struct VisitExport: Codable {
    let date: Date
    let note: String?
}

extension Visit {
    func toExport() -> VisitExport {
        VisitExport(
            date: date,
            note: note
        )
    }
}

// MARK: - Link Export

struct LinkExport: Codable {
    let name: String?
    let url: String?
}

extension Link {
    func toExport() -> LinkExport {
        LinkExport(
            name: name,
            url: url
        )
    }
}
