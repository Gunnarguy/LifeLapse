//
//  Event.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import Foundation
import SwiftData
import CoreLocation
import MapKit

/// Core data model representing a life event with associated metadata
@Model
final class Event: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var type: EventType = EventType.micro
    var title: String = ""
    var subtitle: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var userWeight: Double = 0.0
    var engagement: Int = 0
    var favorite: Bool = false
    var assetLocalID: String? = nil
    var significance: Double = 0.0

    init(id: UUID = UUID(),
         date: Date = Date.now,
         type: EventType,
         title: String,
         subtitle: String? = nil,
         coordinate: CLLocationCoordinate2D? = nil,
         userWeight: Double = 0.0,
         engagement: Int = 0,
         favorite: Bool = false,
         assetLocalID: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.latitude = coordinate?.latitude
        self.longitude = coordinate?.longitude
        self.userWeight = userWeight
        self.engagement = engagement
        self.favorite = favorite
        self.assetLocalID = assetLocalID
        self.significance = 0.0     // filled post‑save
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return .init(latitude: lat, longitude: lon)
    }
}
