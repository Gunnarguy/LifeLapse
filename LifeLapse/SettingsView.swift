//  Views/SettingsView.swift
import SwiftUI
import Photos

struct SettingsView: View {
    var store: EventStore
    @State private var exportProgress: Double = 0
    @State private var showingDateRangePicker = false
    @State private var importStartDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var importEndDate = Date()
    @State private var showingPhotoImportAlert = false
    @State private var photoCount = 0
    @State private var syncStatus: (synced: Int, total: Int) = (0, 0)

    var body: some View {
        Form {
            Section("Cloud Sync") {
                NavigationLink("CloudKit Status") {
                    CloudKitStatusView()
                }
            }
            
            Section("Photos Import") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Available Photos")
                        Spacer()
                        Text("\(photoCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = store.getLastPhotoSyncDate() {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    if syncStatus.total > 0 {
                        HStack {
                            Text("iCloud Sync")
                            Spacer()
                            Text("\(syncStatus.synced)/\(syncStatus.total)")
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(syncStatus.synced), total: Double(syncStatus.total))
                            .tint(syncStatus.synced == syncStatus.total ? .green : .blue)
                    }
                }
                
                if store.isImportingPhotos {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Importing Photos...")
                            Spacer()
                            Text("\(Int(store.photosImportProgress * 100))%")
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: store.photosImportProgress)
                            .tint(.blue)
                    }
                } else {
                    // Smart sync option - only import new photos
                    if store.hasNewPhotosCached {
                        Button("Sync New Photos") {
                            Task {
                                await store.importNewPhotos()
                                updatePhotoInfo()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Button("Import All Photos from iCloud") {
                        showingPhotoImportAlert = true
                    }
                    .disabled(photoCount == 0)
                    
                    Button("Import Photos from Date Range") {
                        showingDateRangePicker = true
                    }
                    .disabled(photoCount == 0)
                }
                
                if let error = store.photosImportError {
                    Text("Import Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section("Import") {
                Button("Scan Health Achievements") { 
                    Task { await store.importHealthAchievements() } 
                }
            }
            Section("Export") {
                Button("Generate 60 s Video") {
                    Task {
                        for await pct in VideoExporter.export(events: store.events) {
                            exportProgress = pct
                        }
                    }
                }
                if exportProgress > 0 && exportProgress < 1 {
                    ProgressView(value: exportProgress)
                }
            }
            Section("Debug") {
                Button("Inject Mock Data") {
                    DemoData.seed(into: store)
                }.tint(.orange)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            updatePhotoInfo()
        }
        .refreshable {
            updatePhotoInfo()
        }
        .alert("Import All Photos", isPresented: $showingPhotoImportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Import") {
                Task {
                    await store.importAllPhotos()
                    updatePhotoInfo()
                }
            }
        } message: {
            Text("This will import all \(photoCount) photos from your iCloud Photos library. This may take some time and will create timeline events for each photo.")
        }
        .sheet(isPresented: $showingDateRangePicker) {
            NavigationView {
                Form {
                    Section("Date Range") {
                        DatePicker("Start Date", selection: $importStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $importEndDate, displayedComponents: .date)
                    }
                    
                    Section {
                        Button("Import Photos") {
                            Task {
                                await store.importPhotos(from: importStartDate, to: importEndDate)
                                updatePhotoInfo()
                            }
                            showingDateRangePicker = false
                        }
                        .disabled(importStartDate > importEndDate)
                    }
                }
                .navigationTitle("Select Date Range")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingDateRangePicker = false
                        }
                    }
                }
            }
        }
    }
    
    /// Update photo count and sync status
    /// Update photo count and sync status
    private func updatePhotoInfo() {
        Task {
            photoCount = store.getAvailablePhotosCount()
            syncStatus = store.getPhotosSyncStatus()
            await store.updateNewPhotosStatus()
        }
    }
}