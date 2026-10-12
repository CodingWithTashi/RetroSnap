import CoreLocation
import Foundation
import Observation

/// The phone's position from Core Location, with when-in-use access.
@Observable
final class LiveLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private(set) var isAllowed: Bool
    private(set) var current: PhotoLocation?

    @ObservationIgnored private let manager = CLLocationManager()
    /// Waiting for the prompt to be answered.
    @ObservationIgnored private var pendingRequest: (@MainActor (Bool) -> Void)?

    override init() {
        isAllowed = Self.allows(manager.authorizationStatus)
        super.init()
        manager.delegate = self
        // A photo needs the neighbourhood, not the doorstep.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    func requestAccess(completion: @escaping @MainActor (Bool) -> Void) {
        guard manager.authorizationStatus == .notDetermined else {
            completion(isAllowed)
            return
        }
        pendingRequest = completion
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard isAllowed else { return }
        manager.startUpdatingLocation()
    }

    /// The fix is dropped too, so a later shot is never tagged with where the phone used to be.
    func stop() {
        manager.stopUpdatingLocation()
        current = nil
    }

    private static func allows(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        isAllowed = Self.allows(manager.authorizationStatus)
        guard manager.authorizationStatus != .notDetermined, let pendingRequest else { return }
        self.pendingRequest = nil
        pendingRequest(isAllowed)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last, fix.horizontalAccuracy >= 0 else { return }
        current = PhotoLocation(
            latitude: fix.coordinate.latitude,
            longitude: fix.coordinate.longitude,
            altitude: fix.verticalAccuracy >= 0 ? fix.altitude : nil
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        current = nil
    }
}
