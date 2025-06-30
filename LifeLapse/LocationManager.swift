import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    // Published properties to communicate with SwiftUI:
    @Published var region: MKCoordinateRegion
    @Published var lastLocation: CLLocationCoordinate2D? = nil
    
    private var hasCenteredOnUser: Bool = false  // track if we've centered the map already
    
    override init() {
        // Set an initial region (Apple Park in Cupertino as a default view)
        self.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                                         span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // high accuracy data
        
        // Request permission if not determined; if already authorized, start updating
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        // (If denied or restricted, we do nothing and the map will remain at the default region)
    }
    
    // CLLocationManagerDelegate method – called when user changes authorization status
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // Permission granted, start receiving location updates
            locationManager.startUpdatingLocation()
        }
        // (Handle .denied/.restricted if needed – e.g., we could alert the user – not implemented here)
    }
    
    // CLLocationManagerDelegate method – called when new location data is available
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        lastLocation = newLocation.coordinate  // save the latest location
        
        // If we haven't set the map region to user location yet, do it once:
        if !hasCenteredOnUser {
            region = MKCoordinateRegion(center: newLocation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            hasCenteredOnUser = true
        }
        // Note: We continue to update `lastLocation` on every update, but the map region is only set on first update (or when user taps the recenter button).
    }
    
    // CLLocationManagerDelegate method – called if location updates fail (e.g., no permission, error)
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
        // We could handle errors here (e.g., notify user), but for now we simply log them.
    }
}