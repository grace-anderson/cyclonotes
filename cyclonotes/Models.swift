//
//  Models.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit

@Model
final class Ride {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var activity: String?

    @Relationship(deleteRule: .cascade) var points: [RoutePoint]
    @Relationship(deleteRule: .cascade) var notes: [RideNote]
    @Relationship(deleteRule: .cascade) var photos: [RidePhoto]

    init(
        id: UUID = UUID(),
        title: String = "Untitled Ride",
        startedAt: Date = .now,
        endedAt: Date? = nil,
        distanceMeters: Double = 0,
        activity: String? = nil,
        points: [RoutePoint] = [],
        notes: [RideNote] = [],
        photos: [RidePhoto] = []
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.activity = activity
        self.points = points
        self.notes = notes
        self.photos = photos
    }

    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    var avgSpeedMps: Double { duration > 0 ? distanceMeters / duration : 0 }

    var coordinateBounds: MKCoordinateRegion? {
        let coords = points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        guard let first = coords.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.005, (maxLon - minLon) * 1.5)
        )
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat)/2, longitude: (minLon + maxLon)/2),
            span: span
        )
    }
}

@Model
final class RoutePoint {
    var timestamp: Date
    var lat: Double
    var lon: Double
    var speedMps: Double

    init(timestamp: Date = .now, lat: Double, lon: Double, speedMps: Double = 0) {
        self.timestamp = timestamp
        self.lat = lat
        self.lon = lon
        self.speedMps = speedMps
    }
}

@Model
final class RideNote {
    var timestamp: Date
    var text: String
    var lat: Double?
    var lon: Double?

    init(timestamp: Date = .now, text: String, lat: Double? = nil, lon: Double? = nil) {
        self.timestamp = timestamp
        self.text = text
        self.lat = lat
        self.lon = lon
    }
}

@Model
final class RidePhoto {
    var timestamp: Date
    var imageData: Data
    var lat: Double?
    var lon: Double?

    init(timestamp: Date = .now, imageData: Data, lat: Double? = nil, lon: Double? = nil) {
        self.timestamp = timestamp
        self.imageData = imageData
        self.lat = lat
        self.lon = lon
    }
}
