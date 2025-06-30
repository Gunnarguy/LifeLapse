//  Stores/EventStore.swift
import SwiftData
import UIKit
import HealthKit
import MapKit
import Photos

@Observable
final class EventStore {
    private let modelContext: ModelContext
    private(set) var events: [Event] = []
    
    // Photos integration - make public for external access
    let photosManager = PhotosManager()

    init(context: ModelContext) {
        self.modelContext = context
        refresh()
    }
    
    /// Public access to the model context for external operations
    var context: ModelContext {
        return modelContext
    }

    func refresh() {
        events = DataHelpers.fetchAllEvents(from: modelContext)
    }

    // MARK: – CRUD
    func add(_ event: Event) {
        modelContext.insert(event)
        save()
    }

    func delete(_ event: Event) {
        modelContext.delete(event)
        save()
    }

    func updateEvent(_ event: Event) {
        // SwiftData tracks changes automatically, so we just need to save.
        save()
    }

    func save() {
        if DataHelpers.saveContext(modelContext) {
            refresh()
        }
    }

    // MARK: – Import pipelines
    
    /// Import all photos from iCloud Photos library
    func importAllPhotos() async {
        // Request permission first
        guard await photosManager.requestPhotoLibraryAccess() else {
            print("❌ Photo library access denied")
            return
        }
        
        await photosManager.importAllPhotos(into: self)
    }
    
    /// Import photos from a specific date range
    func importPhotos(from startDate: Date, to endDate: Date) async {
        guard await photosManager.requestPhotoLibraryAccess() else {
            print("❌ Photo library access denied")
            return
        }
        
        await photosManager.importPhotos(from: startDate, to: endDate, into: self)
    }
    
    /// Import only new photos since last sync (efficient incremental update)
    func importNewPhotos() async {
        guard await photosManager.requestPhotoLibraryAccess() else {
            print("❌ Photo library access denied")
            return
        }
        
        await photosManager.importNewPhotos(into: self)
    }
    
    /// Get photos import progress (0.0 to 1.0)
    var photosImportProgress: Double {
        photosManager.importProgress
    }
    
    /// Check if photos are currently being imported
    var isImportingPhotos: Bool {
        photosManager.isImporting
    }
    
    /// Get current count of imported photos during import
    var currentImportedCount: Int {
        photosManager.currentImportedCount
    }
    
    /// Get total count of photos to import
    var totalPhotosToImport: Int {
        photosManager.totalPhotosToImport
    }
    
    /// Get current import phase description
    var currentImportPhase: String {
        photosManager.currentPhase
    }
    
    /// Get last photos import error if any
    var photosImportError: String? {
        photosManager.lastImportError
    }
    
    /// Get count of photos available in library
    func getAvailablePhotosCount() -> Int {
        photosManager.getPhotoCount()
    }
    
    /// Get iCloud sync status for photos
    func getPhotosSyncStatus() -> (synced: Int, total: Int) {
        photosManager.getCloudSyncStatus()
    }
    
    /// Get last photo sync date as a formatted string
    func getLastPhotoSyncDate() -> String? {
        guard let lastSync = photosManager.lastSyncDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastSync)
    }
    
    /// Check if there are new photos available since last sync
    func hasNewPhotos() async -> Bool {
        await photosManager.hasNewPhotosSinceLastSync()
    }
    
    /// Synchronous version for UI binding - uses cached state
    private var _hasNewPhotosCached: Bool = false
    
    var hasNewPhotosCached: Bool {
        _hasNewPhotosCached
    }
    
    /// Update the cached new photos status
    func updateNewPhotosStatus() async {
        let hasNew = await hasNewPhotos()
        await MainActor.run {
            _hasNewPhotosCached = hasNew
        }
    }

    func importHealthAchievements() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // … query HKActivitySummary, convert to Event, insert …
    }

    func importPhotosHighlights() async {
        // Legacy method - now redirects to full photos import
        await importAllPhotos()
    }
}

enum DemoData {
    static func seed(into store: EventStore) {
        // Disabled - users should add their own events
        // No demo data will be created
        return
    }
}