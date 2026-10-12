import Foundation

protocol SettingsStoring: AnyObject {
    var saveToPhotos: Bool { get set }
    var shutterSound: Bool { get set }
    var haptics: Bool { get set }
    var videoQuality: String { get }
    var versionText: String { get }
    /// The camera the app opens on.
    var lastCamera: CameraStyle { get set }
    /// The first-launch camera strip has been dismissed.
    var hasSeenCameraIntro: Bool { get set }
    /// The result screen has already taught where photos go.
    var hasTakenFirstPhoto: Bool { get set }
}
