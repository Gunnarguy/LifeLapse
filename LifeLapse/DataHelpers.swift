//
//  DataHelpers.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import Foundation
import SwiftData

/// Helpers for safer data operations that avoid Core Data crashes
enum DataHelpers {
    
    /// Safely fetch events within a date range without using predicates
    /// This avoids the Core Data crash with date predicates
    static func fetchEventsInDateRange(
        _ startDate: Date,
        _ endDate: Date,
        from context: ModelContext
    ) -> [Event] {
        do {
            // Fetch all events and filter in memory to avoid Core Data date predicate issues
            let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date)])
            let allEvents = try context.fetch(descriptor)
            
            return allEvents.filter { event in
                event.date >= startDate && event.date <= endDate
            }
        } catch {
            print("DataHelpers.fetchEventsInDateRange failed: \(error)")
            return []
        }
    }
    
    /// Safely fetch all events with error handling
    static func fetchAllEvents(from context: ModelContext) -> [Event] {
        do {
            let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date)])
            return try context.fetch(descriptor)
        } catch {
            print("DataHelpers.fetchAllEvents failed: \(error)")
            return []
        }
    }
    
    /// Safe event creation with validation
    static func createEvent(
        type: EventType,
        title: String,
        date: Date = Date.now,
        subtitle: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil,
        in context: ModelContext
    ) -> Event? {
        let event = Event(
            date: date,
            type: type,
            title: title,
            subtitle: subtitle,
            coordinate: coordinate
        )
        
        do {
            context.insert(event)
            try context.save()
            return event
        } catch {
            print("DataHelpers.createEvent failed: \(error)")
            return nil
        }
    }
    
    /// Safe context save operation
    static func saveContext(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            print("DataHelpers.saveContext failed: \(error)")
            return false
        }
    }
}

import CoreLocation
