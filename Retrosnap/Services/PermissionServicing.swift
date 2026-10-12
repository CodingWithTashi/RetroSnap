import Foundation

nonisolated enum PhotoLibraryAccess: Hashable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// System permission prompts. In v1 the mock answers without showing one.
protocol PermissionServicing: AnyObject {
    var photoLibraryAccess: PhotoLibraryAccess { get }
    func requestCameraAccess()
    func requestPhotoLibraryAccess()
    /// "Not now": photos stay inside the app until access is given.
    func declinePhotoLibraryAccess()
}
