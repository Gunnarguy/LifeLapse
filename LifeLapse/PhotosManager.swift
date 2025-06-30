//
//  PhotosManager.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//
//  Enhanced PhotosManager for comprehensive iCloud Photos integration
//  
//  Features:
//  - Full iCloud Photos history import
//  - Intelligent photo metadata extraction and categorization
//  - Duplicate prevention with asset ID tracking  
//  - Incremental sync for new photos only
//  - Progress tracking and error handling
//  - Automatic background sync capabilities
//  - iCloud sync status monitoring
//

import Foundation
import Photos
import CoreLocation
import SwiftData

/// Manager for accessing and importing iCloud Photos into timeline events
/// Handles full photo library history, incremental syncs, and smart categorization
@Observable
final class PhotosManager: NSObject {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var importProgress: Double = 0.0
    var isImporting: Bool = false
    var lastImportError: String?
    
    // Track last sync to avoid re-importing
    private var importedAssetIDs: Set<String> = []
    
    override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        loadSyncState()
    }
    
    /// Request permission to access photo library
    @MainActor
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status == .authorized || status == .limited
    }
    
    /// Import all photos from iCloud Photos library as timeline events
    @MainActor
    func importAllPhotos(into store: EventStore) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            lastImportError = "Photo library access not granted"
            return
        }
        
        isImporting = true
        importProgress = 0.0
        lastImportError = nil
        
        // Fetch all photos sorted by creation date
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.includeHiddenAssets = false
        
        // Only import photos that haven't been imported yet
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = allPhotos.count
        
        print("📸 Found \(totalCount) photos total, checking for new ones...")
        
        var importedCount = 0
        var skippedCount = 0
        var batchEvents: [Event] = []
        let batchSize = 50 // Process in batches to avoid memory issues
        
        allPhotos.enumerateObjects { asset, index, _ in
            // Skip if already imported
            if self.isAssetImported(asset.localIdentifier) {
                skippedCount += 1
            } else {
                // Create event from photo asset
                if let event = self.createEventFromAsset(asset) {
                    batchEvents.append(event)
                    self.markAssetImported(asset.localIdentifier)
                }
            }
            
            // Process batch when full or at end
            if batchEvents.count >= batchSize || index == totalCount - 1 {
                // Add events to store on main thread
                Task { @MainActor in
                    for event in batchEvents {
                        store.add(event)
                    }
                    importedCount += batchEvents.count
                    self.importProgress = Double(index + 1) / Double(totalCount)
                    print("📸 Processed \(index + 1)/\(totalCount) photos (\(importedCount) new, \(skippedCount) skipped)")
                }
                batchEvents.removeAll()
            }
        }
        
        isImporting = false
        importProgress = 1.0
        UserDefaults.standard.set(Date(), forKey: "PhotosLastSyncDate")
        print("📸 Successfully processed \(totalCount) photos (\(importedCount) new imports, \(skippedCount) already imported)")
        saveSyncState()
    }
    
    /// Import only photos from a specific date range
    @MainActor
    func importPhotos(from startDate: Date, to endDate: Date, into store: EventStore) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            lastImportError = "Photo library access not granted"
            return
        }
        
        isImporting = true
        importProgress = 0.0
        lastImportError = nil
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let photos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = photos.count
        
        print("📸 Found \(totalCount) photos in date range to import")
        
        var importedCount = 0
        
        photos.enumerateObjects { asset, index, _ in
            if let event = self.createEventFromAsset(asset) {
                Task { @MainActor in
                    store.add(event)
                    importedCount += 1
                    self.importProgress = Double(importedCount) / Double(totalCount)
                }
            }
        }
        
        isImporting = false
        importProgress = 1.0
        print("📸 Successfully imported \(importedCount) photos from date range")
    }
    
    /// Import only new photos since last sync
    @MainActor
    func importNewPhotos(into store: EventStore) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            lastImportError = "Photo library access not granted"
            return
        }
        
        guard await hasNewPhotosSinceLastSync() else {
            print("📸 No new photos since last sync")
            return
        }
        
        isImporting = true
        importProgress = 0.0
        lastImportError = nil
        
        // Fetch photos since last sync
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.includeHiddenAssets = false
        
        // Only get photos newer than last sync
        if let lastSync = UserDefaults.standard.object(forKey: "PhotosLastSyncDate") as? Date {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastSync as NSDate)
        }
        
        let newPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = newPhotos.count
        
        print("📸 Found \(totalCount) new photos to import")
        
        var importedCount = 0
        var batchEvents: [Event] = []
        let batchSize = 50
        
        newPhotos.enumerateObjects { asset, index, _ in
            // Skip if somehow already imported
            if !self.isAssetImported(asset.localIdentifier) {
                if let event = self.createEventFromAsset(asset) {
                    batchEvents.append(event)
                    self.markAssetImported(asset.localIdentifier)
                }
            }
            
            // Process batch when full or at end
            if batchEvents.count >= batchSize || index == totalCount - 1 {
                Task { @MainActor in
                    for event in batchEvents {
                        store.add(event)
                    }
                    importedCount += batchEvents.count
                    self.importProgress = Double(index + 1) / Double(totalCount)
                    print("📸 Imported \(importedCount)/\(totalCount) new photos")
                }
                batchEvents.removeAll()
            }
        }
        
        isImporting = false
        importProgress = 1.0
        UserDefaults.standard.set(Date(), forKey: "PhotosLastSyncDate")
        print("📸 Successfully imported \(importedCount) new photos")
        saveSyncState()
    }
    
    /// Create an Event from a PHAsset
    private func createEventFromAsset(_ asset: PHAsset) -> Event? {
        guard let creationDate = asset.creationDate else {
            return nil
        }
        
        // Extract location if available
        var coordinate: CLLocationCoordinate2D?
        if let location = asset.location {
            coordinate = location.coordinate
        }
        
        // Generate title based on photo metadata
        let title = generatePhotoTitle(for: asset)
        let subtitle = generatePhotoSubtitle(for: asset)
        
        // Determine event type based on photo characteristics
        let eventType = determineEventType(for: asset)
        
        // Calculate user weight based on photo characteristics
        let userWeight = calculatePhotoWeight(for: asset)
        
        return Event(
            date: creationDate,
            type: eventType,
            title: title,
            subtitle: subtitle,
            coordinate: coordinate,
            userWeight: userWeight,
            engagement: 0, // Can be updated later based on views/interactions
            favorite: asset.isFavorite,
            assetLocalID: asset.localIdentifier
        )
    }
    
    /// Generate a meaningful title for a photo event
    private func generatePhotoTitle(for asset: PHAsset) -> String {
        let creationDate = asset.creationDate ?? Date()
        let calendar = Calendar.current
        
        // Check for special photo types first
        if asset.representsBurst {
            return "Burst Photo Series"
        }
        
        // Check for screenshot
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return "Screenshot"
        }
        
        // Check for panorama
        if asset.mediaSubtypes.contains(.photoPanorama) {
            return "Panoramic View"
        }
        
        // Check for portrait mode
        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            return "Portrait Photo"
        }
        
        // Check for Live Photo
        if asset.mediaSubtypes.contains(.photoLive) {
            return "Live Photo"
        }
        
        // Check for HDR
        if asset.mediaSubtypes.contains(.photoHDR) {
            return "HDR Photo"
        }
        
        // Generate contextual title based on time and characteristics
        let hour = calendar.component(.hour, from: creationDate)
        let dayOfWeek = calendar.component(.weekday, from: creationDate)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7 // Sunday or Saturday
        
        // Check if photo has location for travel context
        let hasLocation = asset.location != nil
        let isFavorite = asset.isFavorite
        
        // Generate title based on context
        if isFavorite {
            return "Favorite Memory"
        } else if hasLocation && isWeekend {
            switch hour {
            case 6..<10:
                return "Weekend Morning Adventure"
            case 10..<14:
                return "Weekend Outing"
            case 14..<18:
                return "Weekend Afternoon"
            case 18..<22:
                return "Weekend Evening"
            default:
                return "Weekend Night"
            }
        } else if hasLocation {
            switch hour {
            case 6..<10:
                return "Morning Journey"
            case 10..<14:
                return "Midday Adventure"
            case 14..<18:
                return "Afternoon Exploration"
            case 18..<22:
                return "Evening Out"
            default:
                return "Night Adventure"
            }
        } else {
            // Default time-based titles for photos without location
            switch hour {
            case 5..<10:
                return "Morning Moment"
            case 10..<12:
                return "Late Morning"
            case 12..<14:
                return "Midday Capture"
            case 14..<17:
                return "Afternoon Photo"
            case 17..<20:
                return "Evening Light"
            case 20..<22:
                return "Evening Moment"
            default:
                return "Night Photo"
            }
        }
    }
    
    /// Generate subtitle with additional context and metadata
    private func generatePhotoSubtitle(for asset: PHAsset) -> String? {
        var components: [String] = []
        let creationDate = asset.creationDate ?? Date()
        let dateFormatter = DateFormatter()
        
        // Add formatted date
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        components.append(dateFormatter.string(from: creationDate))
        
        // Add location context if available
        if let location = asset.location {
            let lat = String(format: "%.4f", location.coordinate.latitude)
            let lon = String(format: "%.4f", location.coordinate.longitude)
            components.append("📍 \(lat), \(lon)")
        }
        
        // Add photo characteristics
        if asset.isFavorite {
            components.append("⭐ Favorite")
        }
        
        if asset.mediaSubtypes.contains(.photoHDR) {
            components.append("HDR")
        }
        
        if asset.mediaSubtypes.contains(.photoLive) {
            components.append("Live")
        }
        
        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            components.append("Portrait")
        }
        
        if asset.mediaSubtypes.contains(.photoPanorama) {
            components.append("Panorama")
        }
        
        // Add camera info if available
        let resources = PHAssetResource.assetResources(for: asset)
        if let originalResource = resources.first(where: { $0.type == .photo }) {
            if let filename = originalResource.originalFilename.components(separatedBy: ".").first {
                // Extract potential camera model from filename patterns
                if filename.hasPrefix("IMG_") {
                    components.append("📷 iPhone")
                } else if filename.hasPrefix("DSC") {
                    components.append("📷 Camera")
                }
            }
        }
        
        // Add file size context for quality indication
        if asset.pixelWidth > 4000 && asset.pixelHeight > 3000 {
            components.append("🔍 High-res")
        }
        
        // Add dimensions for reference
        components.append("\(asset.pixelWidth)×\(asset.pixelHeight)")
        
        return components.isEmpty ? nil : components.joined(separator: " • ")
    }
    
    /// Determine appropriate event type based on photo characteristics
    private func determineEventType(for asset: PHAsset) -> EventType {
        // Screenshots are typically micro events
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return .micro
        }
        
        // Favorites are more significant
        if asset.isFavorite {
            return .photo // Use photo type for important photos
        }
        
        // Panoramas and portraits suggest more intentional photography
        if asset.mediaSubtypes.contains(.photoPanorama) || 
           asset.mediaSubtypes.contains(.photoDepthEffect) {
            return .photo
        }
        
        // Burst photos are usually micro moments
        if asset.representsBurst {
            return .micro
        }
        
        // Default to photo type
        return .photo
    }
    
    /// Calculate weight based on photo importance indicators
    private func calculatePhotoWeight(for asset: PHAsset) -> Double {
        var weight = 0.0
        
        // Base weight for photos
        weight += 0.3
        
        // Increase weight for favorites
        if asset.isFavorite {
            weight += 0.4
        }
        
        // Increase weight for special photo types
        if asset.mediaSubtypes.contains(.photoPanorama) ||
           asset.mediaSubtypes.contains(.photoDepthEffect) {
            weight += 0.2
        }
        
        // Decrease weight for screenshots
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            weight -= 0.2
        }
        
        // Decrease weight for burst photos
        if asset.representsBurst {
            weight -= 0.1
        }
        
        // Increase weight if has location
        if asset.location != nil {
            weight += 0.1
        }
        
        return max(0.0, min(1.0, weight))
    }
    
    /// Get the count of photos in the library
    func getPhotoCount() -> Int {
        let fetchOptions = PHFetchOptions()
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return allPhotos.count
    }
    
    /// Check if there are iCloud photos still syncing
    func getCloudSyncStatus() -> (synced: Int, total: Int) {
        let fetchOptions = PHFetchOptions()
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var syncedCount = 0
        let totalCount = allPhotos.count
        
        allPhotos.enumerateObjects { asset, _, _ in
            // Check if photo is fully downloaded
            let resources = PHAssetResource.assetResources(for: asset)
            let hasOriginal = resources.contains { $0.type == .photo }
            if hasOriginal {
                syncedCount += 1
            }
        }
        
        return (synced: syncedCount, total: totalCount)
    }
    
    // MARK: - Sync State Management
    
    /// Load sync state from UserDefaults
    private func loadSyncState() {
        if let importedIDs = UserDefaults.standard.array(forKey: "ImportedAssetIDs") as? [String] {
            importedAssetIDs = Set(importedIDs)
        }
    }
    
    /// Save sync state to UserDefaults
    private func saveSyncState() {
        UserDefaults.standard.set(Array(importedAssetIDs), forKey: "ImportedAssetIDs")
    }
    
    /// Mark an asset as imported
    private func markAssetImported(_ assetID: String) {
        importedAssetIDs.insert(assetID)
        // Keep only recent 10,000 IDs to prevent memory bloat
        if importedAssetIDs.count > 10000 {
            let sortedIDs = Array(importedAssetIDs).prefix(5000)
            importedAssetIDs = Set(sortedIDs)
        }
    }
    
    /// Check if asset has already been imported
    private func isAssetImported(_ assetID: String) -> Bool {
        return importedAssetIDs.contains(assetID)
    }
    
    /// Check for new photos since last sync
    @MainActor
    func hasNewPhotosSinceLastSync() async -> Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: "PhotosLastSyncDate") as? Date else { return true }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastSync as NSDate)
        fetchOptions.includeHiddenAssets = false
        
        let newPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return newPhotos.count > 0
    }
    
    // MARK: - Background Sync
    
    /// Setup automatic background sync for new photos
    func setupAutoSync(for store: EventStore) {
        // Check for new photos every hour when app is active
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                // Only sync if we have permission and there are new photos
                let hasAccess = await self.requestPhotoLibraryAccess()
                let hasNewPhotos = await self.hasNewPhotosSinceLastSync()
                if hasAccess && hasNewPhotos {
                    print("📸 Auto-syncing new photos...")
                    await self.importNewPhotos(into: store)
                }
            }
        }
    }
    
    /// Manual trigger for checking and syncing new photos
    @MainActor
    func syncNewPhotosIfNeeded(into store: EventStore) async {
        guard await requestPhotoLibraryAccess() else { return }
        
        if await hasNewPhotosSinceLastSync() {
            await importNewPhotos(into: store)
        } else {
            print("📸 No new photos to sync")
        }
    }
    
    // MARK: - Public Properties
    
    /// Last sync date for external access
    var lastSyncDate: Date? {
        return UserDefaults.standard.object(forKey: "PhotosLastSyncDate") as? Date
    }
}
