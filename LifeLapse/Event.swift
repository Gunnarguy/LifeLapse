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
final class Event: Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var type: EventType = EventType.micro
    var title: String = ""
    var subtitle: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var location: String = ""
    var userWeight: Double = 0.0
    var engagement: Int = 0
    var favorite: Bool = false
    var assetLocalID: String? = nil
    var significance: Double = 0.0
    var details: String? = nil
    var colorHex: String? = nil
    var photoData: Data? = nil

    /// The date the event was created
    var createdDate: Date = Date.now

    /// The date the event was last modified
    var lastModifiedDate: Date = Date.now

    /// Tags associated with the event
    var tags: [String] = []

    /// Indicates whether the event is archived
    var isArchived: Bool = false

    /// Returns true if both latitude and longitude are non-nil
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }

    init(id: UUID = UUID(),
         date: Date = Date.now,
         type: EventType,
         title: String,
         subtitle: String? = nil,
         coordinate: CLLocationCoordinate2D? = nil,
         location: String = "",
         userWeight: Double = 0.0,
         engagement: Int = 0,
         favorite: Bool = false,
         assetLocalID: String? = nil,
         details: String? = nil,
         colorHex: String? = nil,
         photoData: Data? = nil,
         createdDate: Date = Date.now,
         lastModifiedDate: Date = Date.now,
         tags: [String] = [],
         isArchived: Bool = false) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.latitude = coordinate?.latitude
        self.longitude = coordinate?.longitude
        self.location = location
        self.userWeight = userWeight
        self.engagement = engagement
        self.favorite = favorite
        self.assetLocalID = assetLocalID
        self.significance = 0.0     // filled post‑save
        self.details = details
        self.colorHex = colorHex
        self.photoData = photoData
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.tags = tags
        self.isArchived = isArchived
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return .init(latitude: lat, longitude: lon)
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id &&
        lhs.date == rhs.date &&
        lhs.type == rhs.type &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.location == rhs.location &&
        lhs.userWeight == rhs.userWeight &&
        lhs.engagement == rhs.engagement &&
        lhs.favorite == rhs.favorite &&
        lhs.assetLocalID == rhs.assetLocalID &&
        lhs.significance == rhs.significance &&
        lhs.details == rhs.details &&
        lhs.colorHex == rhs.colorHex &&
        lhs.photoData == rhs.photoData &&
        lhs.createdDate == rhs.createdDate &&
        lhs.lastModifiedDate == rhs.lastModifiedDate &&
        lhs.tags == rhs.tags &&
        lhs.isArchived == rhs.isArchived
    }
}

extension Event: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case type
        case title
        case subtitle
        case latitude
        case longitude
        case location
        case userWeight
        case engagement
        case favorite
        case assetLocalID
        case significance
        case details
        case colorHex
        case photoData
        case createdDate
        case lastModifiedDate
        case tags
        case isArchived
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let date = try container.decode(Date.self, forKey: .date)
        let type = try container.decode(EventType.self, forKey: .type)
        let title = try container.decode(String.self, forKey: .title)
        let subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        let location = try container.decode(String.self, forKey: .location)
        let userWeight = try container.decode(Double.self, forKey: .userWeight)
        let engagement = try container.decode(Int.self, forKey: .engagement)
        let favorite = try container.decode(Bool.self, forKey: .favorite)
        let assetLocalID = try container.decodeIfPresent(String.self, forKey: .assetLocalID)
        let significance = try container.decode(Double.self, forKey: .significance)
        let details = try container.decodeIfPresent(String.self, forKey: .details)
        let colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        let photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        let createdDate = try container.decode(Date.self, forKey: .createdDate)
        let lastModifiedDate = try container.decode(Date.self, forKey: .lastModifiedDate)
        let tags = try container.decode([String].self, forKey: .tags)
        let isArchived = try container.decode(Bool.self, forKey: .isArchived)

        let coordinate: CLLocationCoordinate2D? = {
            if let lat = latitude, let lon = longitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }()

        self.init(id: id,
                  date: date,
                  type: type,
                  title: title,
                  subtitle: subtitle,
                  coordinate: coordinate,
                  location: location,
                  userWeight: userWeight,
                  engagement: engagement,
                  favorite: favorite,
                  assetLocalID: assetLocalID,
                  details: details,
                  colorHex: colorHex,
                  photoData: photoData,
                  createdDate: createdDate,
                  lastModifiedDate: lastModifiedDate,
                  tags: tags,
                  isArchived: isArchived)
        self.significance = significance
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(location, forKey: .location)
        try container.encode(userWeight, forKey: .userWeight)
        try container.encode(engagement, forKey: .engagement)
        try container.encode(favorite, forKey: .favorite)
        try container.encodeIfPresent(assetLocalID, forKey: .assetLocalID)
        try container.encode(significance, forKey: .significance)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(photoData, forKey: .photoData)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModifiedDate, forKey: .lastModifiedDate)
        try container.encode(tags, forKey: .tags)
        try container.encode(isArchived, forKey: .isArchived)
    }
}

// Manual Codable conformance is required due to SwiftData @Model restrictions.
