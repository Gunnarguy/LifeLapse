//  Views/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var store: EventStore?
    @State private var timeline: TimelineVM?
    @State private var showingAddEvent = false

    var body: some View {
        Group {
            if let store, let timeline {
                ZStack {
                    TabView {
                        // Main Timeline Tab - unified view
                        TimelineView(timeline: timeline, store: store, showingAddEvent: $showingAddEvent)
                            .tabItem {
                                Label("Timeline", systemImage: "clock")
                            }

                        // Events List Tab
                        EventsListView(store: store, showingAddEvent: $showingAddEvent)
                            .tabItem {
                                Label("Events", systemImage: "list.bullet")
                            }

                        // Settings Tab
                        NavigationView {
                            SettingsView(store: store)
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                    .environment(store)
                    .ignoresSafeArea(.all, edges: .top) // Full screen for iPhone
                    .preferredColorScheme(.dark) // Better for map-based UI
                    
                    // Global import progress indicator (appears above tabs)
                    if store.isImportingPhotos {
                        VStack {
                            Spacer()
                            
                            // Compact progress bar at bottom above tab bar
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "photo.stack.fill")
                                        .foregroundColor(.blue)
                                        .symbolEffect(.pulse, options: .repeating)
                                    
                                    Text("Importing \(store.currentImportedCount) of \(store.totalPhotosToImport) photos")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(store.photosImportProgress * 100))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                        .contentTransition(.numericText())
                                }
                                
                                ProgressView(value: store.photosImportProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    .frame(height: 3)
                                    .animation(.easeInOut(duration: 0.3), value: store.photosImportProgress)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: -2)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100) // Above tab bar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.4), value: store.isImportingPhotos)
                        }
                    }
                }
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea(.all)
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            if let store {
                AddEventView(store: store)
            }
        }
        .task {
            if store == nil {
                let eventStore = EventStore(context: context)
                store = eventStore
                timeline = TimelineVM(store: eventStore)
                
                // NO DEMO DATA - clean slate for users
                SignificanceEngine.refreshScores(context: context)
                
                // Setup automatic photo sync for new photos
                Task {
                    await eventStore.photosManager.syncNewPhotosIfNeeded(into: eventStore)
                }
            }
        }
    }
}

/// Clean, unified Timeline view - full screen
struct TimelineView: View {
    let timeline: TimelineVM
    let store: EventStore
    @Binding var showingAddEvent: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen map as background
                MapOverlayView(vm: timeline)
                    .ignoresSafeArea(.all)
                
                VStack {
                    // Floating progress banner during photo import
                    if store.isImportingPhotos {
                        ImportProgressBanner(store: store)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: store.isImportingPhotos)
                    }
                    
                    Spacer()
                    
                    // Timeline rail at bottom with controls
                    VStack(spacing: 12) {
                        // Timeline rail
                        TimelineRailView(vm: timeline)
                            .frame(height: 80)
                            .padding(.horizontal, 16)
                        
                        // Controls
                        HStack(spacing: 30) {
                            // Add event button
                            Button {
                                showingAddEvent = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.green))
                            }
                            
                            // Play/pause button
                            Button {
                                timeline.togglePlay()
                            } label: {
                                Image(systemName: timeline.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.blue))
                            }
                            
                            // Events count
                            VStack {
                                Text("\(store.events.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Events")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        // Current date display
                        Text(timeline.playhead, style: .date)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40) // Extra padding for tab bar
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Empty state when no events
                if store.events.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "map")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Welcome to LifeLapse")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Add your first life event to start your timeline")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        // Photo import status
                        PhotoImportStatusView(store: store)
                            .padding(.vertical, 8)
                        
                        Button {
                            showingAddEvent = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add First Event")
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(.white)
                            .cornerRadius(25)
                        }
                    }
                    .padding(40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }
}

/// Events List view
struct EventsListView: View {
    let store: EventStore
    @Binding var showingAddEvent: Bool
    
    var body: some View {
        NavigationView {
            Group {
                if store.events.isEmpty {
                    // Empty state
                    VStack(spacing: 30) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 12) {
                            Text("No Events Yet")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Start building your life timeline by adding your first event")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            showingAddEvent = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Your First Event")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 15)
                            .background(.blue)
                            .cornerRadius(25)
                        }
                    }
                    .padding(40)
                } else {
                    // Events list
                    List {
                        ForEach(store.events.sorted { $0.date > $1.date }) { event in
                            EventRowView(event: event)
                        }
                        .onDelete(perform: deleteEvents)
                    }
                }
            }
            .navigationTitle("Your Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func deleteEvents(at offsets: IndexSet) {
        let sortedEvents = store.events.sorted { $0.date > $1.date }
        for index in offsets {
            store.delete(sortedEvents[index])
        }
    }
}

/// Floating banner showing photo import progress
struct ImportProgressBanner: View {
    let store: EventStore
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact banner
            HStack {
                Image(systemName: "photo.stack.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                    .symbolEffect(.pulse, options: .repeating)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Importing Photos")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(Int(store.photosImportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                Text("\(Int(store.photosImportProgress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 8) {
                    ProgressView(value: store.photosImportProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .scaleEffect(y: 1.5)
                    
                    if store.totalPhotosToImport > 0 {
                        HStack {
                            Text("\(store.currentImportedCount) of \(store.totalPhotosToImport) photos")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            if !store.currentImportPhase.isEmpty {
                                Text(store.currentImportPhase)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}