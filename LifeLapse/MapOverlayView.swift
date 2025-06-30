//  Views/MapOverlayView.swift
import SwiftUI
import MapKit
import SwiftData

struct MapOverlayView: View {
    var vm: TimelineVM
    @Environment(\.modelContext) private var context
    @State private var camera = MapCameraPosition.region(
        MKCoordinateRegion(center: .init(latitude: 38.0, longitude: -97.0),
                           span: .init(latitudeDelta: 60, longitudeDelta: 60))
    )

    var body: some View {
        Map(position: $camera) {
            ForEach(eventsToShow(), id: \.id) { ev in
                if let coord = ev.coordinate {
                    Annotation(ev.title, coordinate: coord) {
                        ZStack {
                            Circle()
                                .fill(ev.type.color.opacity(0.3))
                                .frame(width: 30, height: 30)
                            Circle()
                                .fill(ev.type.color)
                                .frame(width: 12, height: 12)
                            
                            if ev.favorite {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(1 + ev.significance * 0.5) // Bigger for more significant events
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onAppear { focusOnPlayhead() }
        .onChange(of: vm.playhead) { _, _ in
            focusOnPlayhead()
        }
        .animation(.easeOut(duration: 0.8), value: vm.playhead)
    }

    private func eventsToShow() -> [Event] {
        // Show all events, not just those in a time window
        return DataHelpers.fetchAllEvents(from: context)
    }

    private func focusOnPlayhead() {
        let events = eventsToShow()
        guard !events.isEmpty else { 
            // Show world view when no events
            withAnimation(.easeInOut(duration: 1.0)) {
                camera = .region(MKCoordinateRegion(
                    center: .init(latitude: 39.8283, longitude: -98.5795), // Center of USA
                    span: .init(latitudeDelta: 50, longitudeDelta: 50)
                ))
            }
            return 
        }
        
        // Find bounds of all events with coordinates
        let coordinates = events.compactMap { $0.coordinate }
        guard !coordinates.isEmpty else { return }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.1, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.1, (maxLon - minLon) * 1.3)
        )
        
        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}