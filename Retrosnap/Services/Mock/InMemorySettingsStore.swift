#if DEBUG
import Foundation
import Observation

/// Settings that last for one launch.
@Observable
final class InMemorySettingsStore: SettingsStoring {
    var saveToPhotos = true
    var locationOnPhotos = false
    var shutterSound = true
    var haptics = true
    let videoQuality = "1080p"
    let versionText = "Version 1.0"
    var printer: SavedPrinter?
    var lastCamera = CameraStyle.default
    var flash = FlashMode.auto
    var isTimerOn = false
    var hasCompletedOnboarding = false
    var hasDeclinedPhotoLibrary = false
    var hasSeenCameraIntro = false
    var hasTakenFirstPhoto = false
}
#endif
