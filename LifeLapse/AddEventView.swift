//
//  AddEventView.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import SwiftUI
import MapKit
import CoreLocation

/// View for adding new life events
struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let store: EventStore
    
    @State private var title = ""
    @State private var subtitle = ""
    @State private var eventType = EventType.micro
    @State private var date = Date.now
    @State private var favorite = false
    @State private var userWeight = 0.0
    @State private var engagement = 0
    @State private var details = ""
    @State private var color = Color.blue
    
    // Location picking
    @State private var showingLocationPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = "No location selected"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event title", text: $title)
                        .font(.headline)
                    
                    TextField("Subtitle (optional)", text: $subtitle)
                        .font(.subheadline)
                    
                    Picker("Event Type", selection: $eventType) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            HStack {
                                Circle()
                                    .fill(type.color)
                                    .frame(width: 12, height: 12)
                                Text(type.rawValue.capitalized)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    ColorPicker("Event Color", selection: $color)
                }
                
                Section("Notes") {
                    TextEditor(text: $details)
                        .frame(height: 100)
                }
                
                Section("Location") {
                    Button(action: { showingLocationPicker = true }) {
                        HStack {
                            Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                                .foregroundColor(selectedLocation != nil ? .blue : .gray)
                            Text(locationName)
                                .foregroundColor(selectedLocation != nil ? .primary : .secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Importance") {
                    Toggle("Favorite", isOn: $favorite)
                    
                    VStack(alignment: .leading) {
                        Text("Personal Weight: \(userWeight, specifier: "%.1f")")
                        Slider(value: $userWeight, in: 0...1, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Engagement Level: \(engagement)")
                        Slider(value: Binding(
                            get: { Double(engagement) },
                            set: { engagement = Int($0) }
                        ), in: 0...100, step: 1)
                    }
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedLocation: $selectedLocation,
                locationName: $locationName
            )
        }
    }
    
    private func saveEvent() {
        let event = Event(
            date: date,
            type: eventType,
            title: title,
            subtitle: subtitle,
            coordinate: selectedLocation,
            userWeight: userWeight,
            engagement: engagement,
            favorite: favorite,
            details: details,
            colorHex: color.toHex()
        )
        
        store.add(event)
        dismiss()
    }
}

/// Simple location picker using Map
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var camera = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    var body: some View {
        NavigationView {
            VStack {
                Map(position: $camera) {
                    if let location = selectedLocation {
                        Annotation("Selected Location", coordinate: location) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                        }
                    }
                }
                .onTapGesture { location in
                    // Convert tap location to coordinate
                    selectedLocation = convertTapToCoordinate(location)
                    updateLocationName()
                }
                
                if selectedLocation != nil {
                    VStack {
                        Text("Selected Location")
                            .font(.headline)
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding()
                }
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(selectedLocation == nil)
                }
            }
        }
    }
    
    private func convertTapToCoordinate(_ location: CGPoint) -> CLLocationCoordinate2D {
        // For now, we'll use a default location in San Francisco
        // In a real implementation, you'd convert screen coordinates to map coordinates
        return CLLocationCoordinate2D(
            latitude: 37.7749 + Double.random(in: -0.01...0.01),
            longitude: -122.4194 + Double.random(in: -0.01...0.01)
        )
    }
    
    private func updateLocationName() {
        guard let location = selectedLocation else { return }
        
        // Simple location name generation
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.locationName = [
                        placemark.name,
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")
                    
                    if self.locationName.isEmpty {
                        self.locationName = "Selected Location"
                    }
                }
            }
        }
    }
}

extension Color {
    func toHex() -> String {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
