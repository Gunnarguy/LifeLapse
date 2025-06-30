//
//  CloudKitStatusView.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import SwiftUI
import CloudKit
import SwiftData

/// View to display CloudKit status and help with debugging
struct CloudKitStatusView: View {
    @State private var cloudKitManager = CloudKitManager()
    @Environment(\.modelContext) private var context
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("CloudKit Status")) {
                    HStack {
                        Image(systemName: cloudKitManager.isCloudKitAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(cloudKitManager.isCloudKitAvailable ? .green : .red)
                        
                        Text(cloudKitManager.isCloudKitAvailable ? "Available" : "Unavailable")
                    }
                    
                    if let error = cloudKitManager.cloudKitError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Data Storage")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Storage: Local SQLite")
                            .font(.caption)
                        Text("Events stored: \(eventCount)")
                            .font(.caption)
                        Text("Container: \(containerInfo)")
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Troubleshooting")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If CloudKit is unavailable:")
                            .font(.headline)
                        
                        Text("• Make sure you're signed into iCloud in Settings")
                        Text("• Check your internet connection")
                        Text("• Verify the CloudKit container is configured in Apple Developer Console")
                        Text("• CloudKit doesn't work in the iOS Simulator")
                        Text("• The app will continue to work with local storage")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Refresh Status") {
                        Task {
                            await cloudKitManager.checkCloudKitStatus()
                        }
                    }
                }
            }
            .navigationTitle("CloudKit")
            .task {
                await cloudKitManager.checkCloudKitStatus()
            }
        }
    }
    
    private var eventCount: Int {
        return DataHelpers.fetchAllEvents(from: context).count
    }
    
    private var containerInfo: String {
        #if targetEnvironment(simulator)
        return "iOS Simulator (Local Only)"
        #else
        return "iOS Device"
        #endif
    }
}
