//
//  EditEventView.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/30/25.
//

import SwiftUI
import PhotosUI
import MapKit

/// A view to edit an existing event's details.
struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    let store: EventStore
    
    // The event being edited.
    @State var event: Event
    
    // State for the form fields.
    @State private var title: String
    @State private var details: String
    @State private var location: String
    @State private var selectedDate: Date
    @State private var selectedType: EventType
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition
    @State private var pinCoordinate: CLLocationCoordinate2D?
    
    // Initializer to populate state from the event.
    init(store: EventStore, event: Event) {
        self.store = store
        _event = State(initialValue: event)
        _title = State(initialValue: event.title)
        _details = State(initialValue: event.details ?? "")
        _location = State(initialValue: event.location)
        _selectedDate = State(initialValue: event.date)
        _selectedType = State(initialValue: event.type)
        _selectedPhotoData = State(initialValue: event.photoData)
        
        if let lat = event.latitude, let lon = event.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            _pinCoordinate = State(initialValue: coordinate)
            let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            _position = State(initialValue: .region(region))
        } else {
            _position = State(initialValue: .automatic)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Event Title", text: $title)
                    TextField("Description", text: $details)
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section(header: Text("Location")) {
                    TextField("Address", text: $location, onCommit: geocodeAddress)
                        .padding(.bottom, 4)
                    
                    MapReader { proxy in
                        Map(position: $position) {
                            if let coordinate = pinCoordinate {
                                Marker("", coordinate: coordinate)
                            }
                        }
                        .onTapGesture { position in
                            if let coordinate = proxy.convert(position, from: .local) {
                                setPin(at: coordinate)
                            }
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(8)
                }
                
                Section(header: Text("Event Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Photo")) {
                    if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Label("Select a new photo", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    updateEvent()
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
            .onAppear {
                if pinCoordinate == nil {
                    position = .region(locationManager.region)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedPhotoData = data
                    }
                }
            }
        }
    }
    
    /// Updates the event in the store with the new details.
    private func updateEvent() {
        var updatedEvent = event
        updatedEvent.title = title
        updatedEvent.details = details
        updatedEvent.location = location
        updatedEvent.date = selectedDate
        updatedEvent.type = selectedType
        updatedEvent.photoData = selectedPhotoData
        
        if let coordinate = pinCoordinate {
            updatedEvent.latitude = coordinate.latitude
            updatedEvent.longitude = coordinate.longitude
        }
        
        store.updateEvent(updatedEvent)
    }
    
    private func getAnnotations() -> [IdentifiableCoordinate] {
        if let coordinate = pinCoordinate {
            return [IdentifiableCoordinate(coordinate: coordinate)]
        } else {
            return []
        }
    }
    
    private func setPin(at coordinate: CLLocationCoordinate2D) {
        pinCoordinate = coordinate
        reverseGeocode(coordinate: coordinate)
    }
    
    private func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let placemark = placemarks?.first, let coordinate = placemark.location?.coordinate {
                pinCoordinate = coordinate
                position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let locationPoint = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(locationPoint) { placemarks, error in
            if let placemark = placemarks?.first {
                self.location = placemark.name ?? placemark.locality ?? placemark.country ?? "Unknown Location"
            }
        }
    }
}

struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
