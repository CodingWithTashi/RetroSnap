import Foundation
import Testing
@testable import Retrosnap

/// One defaults suite, emptied around every test, so nothing is left in the test host's preferences.
@Suite(.serialized)
@MainActor
final class UserDefaultsSettingsStoreTests {
    private nonisolated static let suite = "UserDefaultsSettingsStoreTests"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: Self.suite))
        defaults.removePersistentDomain(forName: Self.suite)
    }

    deinit {
        defaults.removePersistentDomain(forName: Self.suite)
    }

    /// A store as the next launch would create it.
    private func relaunched(appVersion: String? = "1.2") -> UserDefaultsSettingsStore {
        UserDefaultsSettingsStore(defaults: defaults, appVersion: appVersion)
    }

    @Test func aFirstLaunchStartsWithTheDesignDefaults() {
        let store = relaunched()
        #expect(store.saveToPhotos && store.shutterSound && store.haptics)
        #expect(!store.locationOnPhotos)
        #expect(store.lastCamera == .film)
        #expect(store.flash == .auto)
        #expect(!store.isTimerOn)
        #expect(!store.hasCompletedOnboarding)
        #expect(!store.hasDeclinedPhotoLibrary)
        #expect(!store.hasSeenCameraIntro)
        #expect(!store.hasTakenFirstPhoto)
    }

    @Test func theSettingsTogglesSurviveARelaunch() {
        let store = relaunched()
        store.saveToPhotos = false
        store.shutterSound = false
        store.haptics = false
        store.locationOnPhotos = true

        let next = relaunched()
        #expect(!next.saveToPhotos)
        #expect(!next.shutterSound)
        #expect(!next.haptics)
        #expect(next.locationOnPhotos)
    }

    @Test func theCameraFlashAndTimerSurviveARelaunch() {
        let store = relaunched()
        store.lastCamera = .camcorder
        store.flash = .off
        store.isTimerOn = true

        let next = relaunched()
        #expect(next.lastCamera == .camcorder)
        #expect(next.flash == .off)
        #expect(next.isTimerOn)
    }

    @Test func whatHasAlreadyBeenShownIsRemembered() {
        let store = relaunched()
        store.hasCompletedOnboarding = true
        store.hasSeenCameraIntro = true
        store.hasTakenFirstPhoto = true
        store.hasDeclinedPhotoLibrary = true

        let next = relaunched()
        #expect(next.hasCompletedOnboarding)
        #expect(next.hasSeenCameraIntro)
        #expect(next.hasTakenFirstPhoto)
        #expect(next.hasDeclinedPhotoLibrary)
    }

    @Test func theChosenPrinterSurvivesARelaunch() throws {
        let store = relaunched()
        #expect(store.printer == nil)
        let office = SavedPrinter(name: "Office Printer", url: try #require(URL(string: "ipp://office.local/ipp/print")))
        store.printer = office
        #expect(relaunched().printer == office)

        store.printer = nil
        #expect(relaunched().printer == nil)
    }

    @Test func aSettingTurnedBackOnIsRememberedToo() {
        let store = relaunched()
        store.haptics = false
        store.haptics = true
        #expect(relaunched().haptics)
    }

    @Test func aValueThisVersionDoesNotKnowFallsBackToTheDefault() {
        defaults.set("pinhole", forKey: "lastCamera")
        defaults.set("strobe", forKey: "flash")
        let store = relaunched()
        #expect(store.lastCamera == .film)
        #expect(store.flash == .auto)
    }

    @Test func versionComesFromTheApp() {
        #expect(relaunched(appVersion: "2.5").versionText == "Version 2.5")
        #expect(relaunched(appVersion: nil).versionText == "")
    }

    @Test func videoIsRecordedInFullHD() {
        #expect(relaunched().videoQuality == "1080p")
    }
}
