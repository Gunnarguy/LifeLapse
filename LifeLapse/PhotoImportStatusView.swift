//
//  PhotoImportStatusView.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import SwiftUI

/// Compact view showing photo import status and quick actions
struct PhotoImportStatusView: View {
    let store: EventStore
    @State private var photoCount = 0
    @State private var showingImportConfirmation = false
    @State private var showingSyncConfirmation = false
    @State private var hasNewPhotos = false
    
    var body: some View {
        Group {
            if store.isImportingPhotos {
                // Show import progress
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.blue)
                        Text("Importing Photos...")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(store.photosImportProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    ProgressView(value: store.photosImportProgress)
                        .tint(.blue)
                        .frame(height: 2)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if store.hasNewPhotosCached {
                // Show sync option for new photos
                Button {
                    showingSyncConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync New Photos")
                            .font(.caption)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                }
            } else if photoCount > 0 && store.events.isEmpty {
                // Show quick import option when no events exist
                Button {
                    showingImportConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Import \(photoCount) Photos")
                            .font(.caption)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onAppear {
            updatePhotoCount()
        }
        .alert("Sync New Photos", isPresented: $showingSyncConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sync") {
                Task {
                    await store.importNewPhotos()
                }
            }
        } message: {
            Text("Sync new photos from your iCloud Photos library since your last import.")
        }
        .alert("Import All Photos", isPresented: $showingImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import") {
                Task {
                    await store.importAllPhotos()
                }
            }
        } message: {
            Text("Import all \(photoCount) photos from your iCloud Photos library to create timeline events?")
        }
    }
    
    private func updatePhotoCount() {
        Task {
            photoCount = store.getAvailablePhotosCount()
            await store.updateNewPhotosStatus()
        }
    }
}
