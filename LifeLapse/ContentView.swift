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
                .ignoresSafeArea(.all, edges: .top) // Full screen for iPhone
                .preferredColorScheme(.dark) // Better for map-based UI
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