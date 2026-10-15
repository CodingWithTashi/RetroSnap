#if DEBUG
import Foundation
import Observation

/// Permissions that are granted the moment they are asked for.
@Observable
final class MockPermissionService: PermissionServicing {
    private(set) var photoLibraryAccess: PhotoLibraryAccess
    private(set) var hasRequestedCameraAccess = false

    init(photoLibraryAccess: PhotoLibraryAccess = .notDetermined) {
        self.photoLibraryAccess = photoLibraryAccess
    }

    func requestCameraAccess(completion: @escaping @MainActor () -> Void) {
        hasRequestedCameraAccess = true
        completion()
    }

    func requestPhotoLibraryAccess(completion: @escaping @MainActor () -> Void) {
        photoLibraryAccess = .granted
        completion()
    }

    func declinePhotoLibraryAccess() {
        photoLibraryAccess = .denied
    }

    func requestMicrophoneAccess(completion: @escaping @MainActor () -> Void) {
        completion()
    }

    func refresh() {}

    func openSettings() {}
}
#endif
