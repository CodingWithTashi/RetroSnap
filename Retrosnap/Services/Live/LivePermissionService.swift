import AVFoundation
import Foundation
import Observation
import Photos

/// The system's permission prompts and what the user answered.
@Observable
final class LivePermissionService: PermissionServicing {
    private(set) var photoLibraryAccess: PhotoLibraryAccess

    @ObservationIgnored private let settings: any SettingsStoring

    init(settings: any SettingsStoring) {
        self.settings = settings
        photoLibraryAccess = Self.currentAccess(settings)
    }

    private static func currentAccess(_ settings: any SettingsStoring) -> PhotoLibraryAccess {
        access(system: PHPhotoLibrary.authorizationStatus(for: .addOnly), hasDeclined: settings.hasDeclinedPhotoLibrary)
    }

    /// The system's answer about adding to Photos, with the app's own "Not now" standing in until it is asked.
    static func access(system: PHAuthorizationStatus, hasDeclined: Bool) -> PhotoLibraryAccess {
        switch system {
        case .authorized, .limited: .granted
        case .denied, .restricted: .denied
        case .notDetermined: hasDeclined ? .denied : .notDetermined
        @unknown default: .denied
        }
    }

    func requestCameraAccess(completion: @escaping @MainActor () -> Void) {
        request(.video, completion: completion)
    }

    /// Shows iOS's own prompt for the camera or the microphone if it has never been answered.
    /// The completion runs once there is an answer, at once when there already was one.
    private func request(_ media: AVMediaType, completion: @escaping @MainActor () -> Void) {
        guard AVCaptureDevice.authorizationStatus(for: media) == .notDetermined else {
            completion()
            return
        }
        Task {
            _ = await AVCaptureDevice.requestAccess(for: media)
            completion()
        }
    }

    func requestPhotoLibraryAccess(completion: @escaping @MainActor () -> Void) {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined:
            Task {
                _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                refresh()
                completion()
            }
        case .denied, .restricted:
            openSettings()
            completion()
        default:
            refresh()
            completion()
        }
    }

    func declinePhotoLibraryAccess() {
        settings.hasDeclinedPhotoLibrary = true
        refresh()
    }

    func requestMicrophoneAccess(completion: @escaping @MainActor () -> Void) {
        request(.audio, completion: completion)
    }

    func refresh() {
        photoLibraryAccess = Self.currentAccess(settings)
    }

    func openSettings() {
        SystemSettings.open()
    }
}
