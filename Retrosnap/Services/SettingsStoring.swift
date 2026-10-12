import Foundation

protocol SettingsStoring: AnyObject {
    var saveToPhotos: Bool { get set }
    /// Tag each shot with where it was taken. Off until the user turns it on.
    var locationOnPhotos: Bool { get set }
    var shutterSound: Bool { get set }
    var haptics: Bool { get set }
    var videoQuality: String { get }
    var versionText: String { get }
    /// The printer jobs go to, once one has been chosen.
    var printer: SavedPrinter? { get set }
    /// The camera the app opens on.
    var lastCamera: CameraStyle { get set }
    var flash: FlashMode { get set }
    var isTimerOn: Bool { get set }
    /// Onboarding has been finished once and is not shown again.
    var hasCompletedOnboarding: Bool { get set }
    /// "Not now" was chosen on the Photos screen, so the system has not been asked yet.
    var hasDeclinedPhotoLibrary: Bool { get set }
    /// The first-launch camera strip has been dismissed.
    var hasSeenCameraIntro: Bool { get set }
    /// The result screen has already taught where photos go.
    var hasTakenFirstPhoto: Bool { get set }
}
