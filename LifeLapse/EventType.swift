//
//  EventType.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import Foundation
import MapKit
import SwiftUI

enum EventType: String, Codable, CaseIterable {
    case residence, job, education, vacation, photo, fitness, finance,
         relationship, medical, cultural, micro, project

    var defaultWeight: Double {
        switch self {
        case .residence: return 0.90
        case .job: return 0.85
        case .education: return 0.75
        case .vacation: return 0.70
        case .photo: return 0.40
        case .fitness: return 0.55
        case .finance: return 0.60
        case .relationship: return 0.95
        case .medical: return 0.80
        case .cultural: return 0.45
        case .micro: return 0.50
        case .project: return 0.88
        }
    }
    
    var color: Color {
        switch self {
        case .residence: return .blue
        case .job: return .green
        case .education: return .purple
        case .vacation: return .orange
        case .photo: return .yellow
        case .fitness: return .red
        case .finance: return .mint
        case .relationship: return .pink
        case .medical: return .cyan
        case .cultural: return .indigo
        case .micro: return .gray
        case .project: return .brown
        }
    }
}
