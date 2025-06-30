//
//  CloudKitManager.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import CloudKit
import SwiftData
import Foundation

/// Manager for CloudKit operations with robust error handling
/// 
/// Note: This app now starts with local storage only to avoid CloudKit startup issues.
/// CloudKit integration can be enabled later once the app is running and CloudKit status is verified.
@Observable
final class CloudKitManager {
    private let container: CKContainer
    var isCloudKitAvailable: Bool = false
    var cloudKitError: String?
    
    init() {
        // Use the container identifier from entitlements
        self.container = CKContainer(identifier: "iCloud.Gunndamental.LifeLapse")
        Task {
            await checkCloudKitStatus()
        }
    }
    
    /// Check if CloudKit is available and properly configured
    @MainActor
    func checkCloudKitStatus() async {
        do {
            // Check account status first
            let accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                // Try to fetch user record to verify container configuration
                _ = try await container.userRecordID()
                isCloudKitAvailable = true
                cloudKitError = nil
                print("✅ CloudKit is available and properly configured")
                
            case .noAccount:
                isCloudKitAvailable = false
                cloudKitError = "No iCloud account configured on this device"
                print("⚠️ No iCloud account available")
                
            case .couldNotDetermine:
                isCloudKitAvailable = false
                cloudKitError = "Could not determine iCloud account status"
                print("⚠️ Could not determine iCloud status")
                
            case .restricted:
                isCloudKitAvailable = false
                cloudKitError = "iCloud access is restricted"
                print("⚠️ iCloud access restricted")
                
            case .temporarilyUnavailable:
                isCloudKitAvailable = false
                cloudKitError = "iCloud is temporarily unavailable"
                print("⚠️ iCloud temporarily unavailable")
                
            @unknown default:
                isCloudKitAvailable = false
                cloudKitError = "Unknown iCloud account status"
                print("⚠️ Unknown iCloud status")
            }
            
        } catch let error as CKError {
            isCloudKitAvailable = false
            
            switch error.code {
            case .badContainer:
                cloudKitError = "CloudKit container not properly configured in Developer Console"
                print("❌ CloudKit container configuration error: \(error.localizedDescription)")
                
            case .networkFailure:
                cloudKitError = "Network connection required for CloudKit"
                print("❌ CloudKit network error: \(error.localizedDescription)")
                
            default:
                cloudKitError = "CloudKit error: \(error.localizedDescription)"
                print("❌ CloudKit error: \(error)")
            }
            
        } catch {
            isCloudKitAvailable = false
            cloudKitError = "Unexpected error: \(error.localizedDescription)"
            print("❌ Unexpected CloudKit error: \(error)")
        }
    }
    
    /// Create a SwiftData ModelContainer with appropriate CloudKit configuration
    static func createModelContainer(schema: Schema) -> ModelContainer {
        // Always use local storage first to avoid CloudKit startup issues
        // CloudKit can be enabled later if needed
        
        print("🔧 Creating ModelContainer with local storage...")
        
        do {
            let localConfig = ModelConfiguration.localOnly(schema: schema)
            let container = try ModelContainer(for: schema, configurations: [localConfig])
            print("✅ Local ModelContainer created successfully")
            return container
        } catch {
            print("⚠️ Local storage failed, trying in-memory: \(error)")
            
            // Final fallback to in-memory storage
            do {
                let memoryConfig = ModelConfiguration.inMemoryOnly(schema: schema)
                let container = try ModelContainer(for: schema, configurations: [memoryConfig])
                print("⚠️ Using in-memory storage as fallback")
                return container
            } catch {
                fatalError("❌ Failed to create any ModelContainer: \(error)")
            }
        }
    }
    
    /// Create a CloudKit-enabled container (call this later if CloudKit is available)
    static func createCloudKitContainer(schema: Schema) -> ModelContainer? {
        guard let cloudConfig = ModelConfiguration.cloudKit(
            schema: schema, 
            containerIdentifier: "iCloud.Gunndamental.LifeLapse"
        ) else {
            return nil
        }
        
        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("✅ CloudKit ModelContainer created successfully")
            return container
        } catch {
            print("❌ CloudKit ModelContainer failed: \(error)")
            return nil
        }
    }
}
