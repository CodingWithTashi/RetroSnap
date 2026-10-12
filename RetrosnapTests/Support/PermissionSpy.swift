import Foundation
@testable import Retrosnap

/// Permissions whose prompts stay up until the test answers them, as the system's do.
@MainActor
final class PermissionSpy: PermissionServicing {
    private(set) var photoLibraryAccess: PhotoLibraryAccess
    private(set) var cameraRequestCount = 0
    private(set) var photoLibraryRequestCount = 0
    private(set) var microphoneRequestCount = 0
    private(set) var refreshCount = 0
    private(set) var openSettingsCount = 0
    private var cameraCompletion: (@MainActor () -> Void)?
    private var photoLibraryCompletion: (@MainActor () -> Void)?
    private var microphoneCompletion: (@MainActor () -> Void)?

    init(photoLibraryAccess: PhotoLibraryAccess = .notDetermined) {
        self.photoLibraryAccess = photoLibraryAccess
    }

    func requestCameraAccess(completion: @escaping @MainActor () -> Void) {
        cameraRequestCount += 1
        cameraCompletion = completion
    }

    func requestPhotoLibraryAccess(completion: @escaping @MainActor () -> Void) {
        photoLibraryRequestCount += 1
        photoLibraryCompletion = completion
    }

    func requestMicrophoneAccess(completion: @escaping @MainActor () -> Void) {
        microphoneRequestCount += 1
        microphoneCompletion = completion
    }

    func declinePhotoLibraryAccess() {
        photoLibraryAccess = .denied
    }

    func refresh() {
        refreshCount += 1
    }

    func openSettings() {
        openSettingsCount += 1
    }

    /// The camera prompt is dismissed, either way.
    func answerCameraPrompt() {
        cameraCompletion?()
        cameraCompletion = nil
    }

    /// The microphone prompt is dismissed, either way.
    func answerMicrophonePrompt() {
        microphoneCompletion?()
        microphoneCompletion = nil
    }

    /// The Photos prompt is dismissed with this answer.
    func answerPhotoLibraryPrompt(_ access: PhotoLibraryAccess) {
        photoLibraryAccess = access
        photoLibraryCompletion?()
        photoLibraryCompletion = nil
    }
}
