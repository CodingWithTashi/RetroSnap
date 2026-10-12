import Foundation

nonisolated enum PhotoLibraryAccess: Hashable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// The system's permission prompts. A prompt is answered later, so requests finish through completions;
/// the mock answers at once.
protocol PermissionServicing: AnyObject {
    /// Whether shots may be added to the Photos library. "Not now" counts as denied.
    var photoLibraryAccess: PhotoLibraryAccess { get }
    /// Shows the camera prompt if it has never been answered. The completion runs once there is an answer, either way.
    func requestCameraAccess(completion: @escaping @MainActor () -> Void)
    /// Asks to add to the Photos library. Once the system prompt has been refused only Settings can change
    /// the answer, so this opens Settings instead. The completion runs once there is nothing more to wait for.
    func requestPhotoLibraryAccess(completion: @escaping @MainActor () -> Void)
    /// "Not now": photos stay inside the app until access is given.
    func declinePhotoLibraryAccess()
    /// Shows the microphone prompt if it has never been answered. The completion runs once there is an answer;
    /// without access, video records silently.
    func requestMicrophoneAccess(completion: @escaping @MainActor () -> Void)
    /// Reads the answers again: they can change in Settings while the app is away.
    func refresh()
    /// Opens the app's page in Settings, the only place a refused prompt can be changed.
    func openSettings()
}
