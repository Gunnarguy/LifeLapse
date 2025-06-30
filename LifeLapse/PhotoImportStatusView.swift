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
    @State private var importStartTime: Date?
    @State private var currentTime = Date()
    @State private var timer: Timer?
    @State private var showingCompletionMessage = false
    @State private var importedCount = 0
    @State private var totalCount = 0
    
    var body: some View {
        Group {
            if store.isImportingPhotos {
                // Enhanced progress view with more details
                VStack(spacing: 12) {
                    // Header with animated icon
                    HStack {
                        Image(systemName: "photo.stack.fill")
                            .foregroundColor(.blue)
                            .font(.title)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Importing Photos")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(store.currentImportPhase.isEmpty ? "Processing your photo library..." : store.currentImportPhase)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    
                    // Progress details
                    VStack(spacing: 8) {
                        // Progress percentage and count
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(Int(store.photosImportProgress * 100))% Complete")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                if store.totalPhotosToImport > 0 {
                                    Text("\(store.currentImportedCount) of \(store.totalPhotosToImport) photos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if importedCount > 0 && totalCount > 0 {
                                    Text("\(importedCount) of \(totalCount) photos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(store.photosImportProgress * 100))%")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .contentTransition(.numericText())
                                
                                if let startTime = importStartTime {
                                    Text(timeElapsedString(from: startTime, to: currentTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        
                        // Enhanced progress bar with gradient
                        VStack(spacing: 4) {
                            ProgressView(value: store.photosImportProgress)
                                .progressViewStyle(GradientProgressViewStyle())
                                .frame(height: 8)
                                .animation(.easeInOut(duration: 0.5), value: store.photosImportProgress)
                            
                            // Estimated time remaining
                            if let startTime = importStartTime, store.photosImportProgress > 0.05 {
                                let elapsed = currentTime.timeIntervalSince(startTime)
                                let estimatedTotal = elapsed / store.photosImportProgress
                                let remaining = max(0, estimatedTotal - elapsed)
                                
                                HStack {
                                    Text("Estimated time remaining:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(formatTimeRemaining(remaining))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                    
                    // Important notice
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Please keep the app open during import")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
                .onAppear {
                    importStartTime = Date()
                    // Start timer for live updates
                    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        currentTime = Date()
                    }
                }
                .onDisappear {
                    importStartTime = nil
                    timer?.invalidate()
                    timer = nil
                }
                .onChange(of: store.isImportingPhotos) { _, isImporting in
                    if !isImporting && store.photosImportProgress >= 1.0 {
                        // Show completion message briefly
                        showingCompletionMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showingCompletionMessage = false
                        }
                    }
                }
            } else if showingCompletionMessage {
                // Show completion message
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("Photos imported successfully!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
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
    
    /// Calculate and format elapsed time since import started
    private func timeElapsedString(from startTime: Date, to currentTime: Date = Date()) -> String {
        let elapsed = currentTime.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Format time remaining in a user-friendly way
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

/// Custom gradient progress view style for enhanced visual feedback
struct GradientProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0.0
        
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(height: 8)
                
                // Progress fill with gradient
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                // Animated shimmer effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 8)
                    .offset(x: (geometry.size.width + 50) * progress - 50)
                    .opacity(progress > 0 && progress < 1 ? 1 : 0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: progress)
            }
        }
    }
}
