import Foundation
import Observation

/// Settings that survive a relaunch, kept in the user defaults.
@Observable
final class UserDefaultsSettingsStore: SettingsStoring {
    private enum Key {
        static let saveToPhotos = "saveToPhotos"
        static let locationOnPhotos = "locationOnPhotos"
        static let shutterSound = "shutterSound"
        static let haptics = "haptics"
        static let printer = "printer"
        static let lastCamera = "lastCamera"
        static let flash = "flash"
        static let isTimerOn = "isTimerOn"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasDeclinedPhotoLibrary = "hasDeclinedPhotoLibrary"
        static let hasSeenCameraIntro = "hasSeenCameraIntro"
        static let hasTakenFirstPhoto = "hasTakenFirstPhoto"
    }

    var saveToPhotos: Bool { didSet { defaults.set(saveToPhotos, forKey: Key.saveToPhotos) } }
    var locationOnPhotos: Bool { didSet { defaults.set(locationOnPhotos, forKey: Key.locationOnPhotos) } }
    var shutterSound: Bool { didSet { defaults.set(shutterSound, forKey: Key.shutterSound) } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: Key.haptics) } }
    let videoQuality = "1080p"
    let versionText: String
    var printer: SavedPrinter? { didSet { defaults.set(try? JSONEncoder().encode(printer), forKey: Key.printer) } }
    var lastCamera: CameraStyle { didSet { defaults.set(lastCamera.rawValue, forKey: Key.lastCamera) } }
    var flash: FlashMode { didSet { defaults.set(flash.rawValue, forKey: Key.flash) } }
    var isTimerOn: Bool { didSet { defaults.set(isTimerOn, forKey: Key.isTimerOn) } }
    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) } }
    var hasDeclinedPhotoLibrary: Bool { didSet { defaults.set(hasDeclinedPhotoLibrary, forKey: Key.hasDeclinedPhotoLibrary) } }
    var hasSeenCameraIntro: Bool { didSet { defaults.set(hasSeenCameraIntro, forKey: Key.hasSeenCameraIntro) } }
    var hasTakenFirstPhoto: Bool { didSet { defaults.set(hasTakenFirstPhoto, forKey: Key.hasTakenFirstPhoto) } }

    @ObservationIgnored private let defaults: UserDefaults

    /// - Parameter appVersion: The marketing version, "1.2"; read from the app bundle unless a test supplies one.
    init(
        defaults: UserDefaults = .standard,
        appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    ) {
        self.defaults = defaults
        // The three toggles are on until the user turns them off.
        saveToPhotos = defaults.object(forKey: Key.saveToPhotos) as? Bool ?? true
        shutterSound = defaults.object(forKey: Key.shutterSound) as? Bool ?? true
        haptics = defaults.object(forKey: Key.haptics) as? Bool ?? true
        locationOnPhotos = defaults.bool(forKey: Key.locationOnPhotos)
        versionText = appVersion.map { "Version \($0)" } ?? ""
        printer = defaults.data(forKey: Key.printer).flatMap { try? JSONDecoder().decode(SavedPrinter.self, from: $0) }
        lastCamera = defaults.string(forKey: Key.lastCamera).flatMap(CameraStyle.init(rawValue:)) ?? .film
        flash = defaults.string(forKey: Key.flash).flatMap(FlashMode.init(rawValue:)) ?? .auto
        isTimerOn = defaults.bool(forKey: Key.isTimerOn)
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        hasDeclinedPhotoLibrary = defaults.bool(forKey: Key.hasDeclinedPhotoLibrary)
        hasSeenCameraIntro = defaults.bool(forKey: Key.hasSeenCameraIntro)
        hasTakenFirstPhoto = defaults.bool(forKey: Key.hasTakenFirstPhoto)
    }
}
