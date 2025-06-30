//
//  SettingsView.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import SwiftUI
import SwiftData
import UIKit

/// Settings and preferences view for LifeLapse
struct SettingsView: View {
    let store: EventStore
    @State private var showingCloudKitStatus = false
    @State private var showingPhotoImportStatus = false
    @State private var showingVideoExportStatus = false
    
    var body: some View {
        NavigationView {
            Form {
                // Data Management Section
                Section("Data Management") {
                    NavigationLink {
                        CloudKitStatusView()
                    } label: {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("CloudKit Status")
                                Text("Sync settings and diagnostics")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink {
                        PhotoImportSettingsView(store: store)
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Photo Import")
                                Text("Manage photo sync and import")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Export Section
                Section("Export") {
                    NavigationLink {
                        VideoExportSettingsView(store: store)
                    } label: {
                        HStack {
                            Image(systemName: "video")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Video Export")
                                Text("Create timeline videos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Event Management Section
                Section("Events") {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("Total Events")
                            Text("\(store.events.count) events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button("Refresh Significance Scores") {
                        Task { @MainActor in
                            SignificanceEngine.refreshScores(context: store.context)
                            store.refresh()
                        }
                    }
                }
                
                // App Information Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        VStack(alignment: .leading) {
                            Text("LifeLapse")
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Detailed photo import settings view
struct PhotoImportSettingsView: View {
    let store: EventStore
    @State private var showingGlobalProgress = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    // Always show status at top for visibility
                    Section("Current Status") {
                        PhotoImportStatusView(store: store)
                    }
                    
                    Section("Import Options") {
                        VStack(spacing: 12) {
                            Button("Import All Photos") {
                                Task {
                                    // Provide immediate haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    // Show global progress overlay
                                    showingGlobalProgress = true
                                    await store.importAllPhotos()
                                    // Keep overlay visible for completion message
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        showingGlobalProgress = false
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(store.isImportingPhotos)
                            
                            Button("Sync New Photos") {
                                Task {
                                    await store.importNewPhotos()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.isImportingPhotos)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Import Tips Section
                    Section("Tips") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("For best results:")
                                    .font(.headline)
                            }
                            
                            Text("• Keep the app open during import")
                            Text("• Ensure your device is connected to power")
                            Text("• Make sure you have a good internet connection")
                            Text("• Large photo libraries may take several minutes")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if let error = store.photosImportError {
                        Section("Import Status") {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                // Full-screen progress overlay during import
                if store.isImportingPhotos || showingGlobalProgress {
                    FullScreenImportProgress(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.4), value: store.isImportingPhotos)
                }
            }
            .navigationTitle("Photo Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Full-screen import progress overlay
struct FullScreenImportProgress: View {
    let store: EventStore
    @State private var startTime = Date()
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Main progress card
                VStack(spacing: 20) {
                    // Icon and title
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Text("Importing Your Photos")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(store.currentImportPhase.isEmpty ? "Processing your photo library..." : store.currentImportPhase)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    
                    // Progress details
                    VStack(spacing: 16) {
                        // Large progress percentage
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(Int(store.photosImportProgress * 100))")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                                    .contentTransition(.numericText())
                                Text("%")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if store.totalPhotosToImport > 0 {
                                    Text("\(store.currentImportedCount) of \(store.totalPhotosToImport)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("photos processed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Processing...")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                
                                Text("Elapsed: \(timeElapsedString(from: startTime, to: currentTime))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        
                        // Progress bar
                        VStack(spacing: 8) {
                            ProgressView(value: store.photosImportProgress)
                                .progressViewStyle(EnhancedProgressViewStyle())
                                .frame(height: 12)
                                .animation(.easeInOut(duration: 0.5), value: store.photosImportProgress)
                            
                            // Time estimate
                            if store.photosImportProgress > 0.05 {
                                let elapsed = currentTime.timeIntervalSince(startTime)
                                let estimatedTotal = elapsed / store.photosImportProgress
                                let remaining = max(0, estimatedTotal - elapsed)
                                
                                HStack {
                                    Text("Estimated time remaining:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(formatTimeRemaining(remaining))
                                        .font(.caption)
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
                        Text("Please keep the app open during import for best performance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .padding(20)
        }
        .onAppear {
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    /// Format elapsed time in a user-friendly way
    private func timeElapsedString(from startTime: Date, to currentTime: Date) -> String {
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

/// Enhanced progress view style with better visual feedback
struct EnhancedProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0.0
        
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(height: 12)
                
                // Progress fill with gradient and animation
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 12)
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                // Animated shimmer effect
                if progress > 0 && progress < 1 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60, height: 12)
                        .offset(x: (geometry.size.width + 60) * progress - 60)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false), value: progress)
                }
            }
        }
    }
}

/// Video export settings and controls
struct VideoExportSettingsView: View {
    let store: EventStore
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportedVideoURL: URL?
    
    var body: some View {
        Form {
            Section("Export Options") {
                Button("Export Timeline Video") {
                    Task {
                        await exportTimelineVideo()
                    }
                }
                .disabled(isExporting || store.events.isEmpty)
                
                if isExporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Exporting video...")
                            .font(.caption)
                    }
                }
            }
            
            if let error = exportError {
                Section("Export Status") {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            if let videoURL = exportedVideoURL {
                Section("Last Export") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Video exported successfully")
                        Spacer()
                        ShareLink(item: videoURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .navigationTitle("Video Export")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Export timeline as video using the VideoExporter
    private func exportTimelineVideo() async {
        isExporting = true
        exportError = nil
        
        do {
            // For now, create a simple example with placeholder images
            // In a real implementation, you'd generate images from the timeline
            let images = await generateTimelineImages()
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoURL = documentsPath.appendingPathComponent("timeline_\(Date().timeIntervalSince1970).mov")
            
            let exporter = VideoExporter()
            let resultURL = try await exporter.export(images: images, to: videoURL)
            
            await MainActor.run {
                exportedVideoURL = resultURL
                isExporting = false
            }
        } catch {
            await MainActor.run {
                exportError = "Export failed: \(error.localizedDescription)"
                isExporting = false
            }
        }
    }
    
    /// Generate timeline images for video export
    private func generateTimelineImages() async -> [UIImage] {
        // Placeholder implementation - generate sample images
        // In a real implementation, you'd render timeline frames
        return (0..<30).compactMap { _ in
            // Create a simple colored image as placeholder
            let size = CGSize(width: 1920, height: 1080)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            UIColor.systemBlue.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image
        }
    }
}
