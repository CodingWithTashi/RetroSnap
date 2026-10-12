import Photos
import Testing
@testable import Retrosnap

/// How the system's answer and the app's own "Not now" combine into what the app shows.
@MainActor
struct LivePermissionServiceTests {

    @Test func addingToPhotosIsAllowedOnceTheSystemSaysSo() {
        #expect(LivePermissionService.access(system: .authorized, hasDeclined: false) == .granted)
        #expect(LivePermissionService.access(system: .limited, hasDeclined: false) == .granted)
    }

    @Test func aSystemNoShowsAsDenied() {
        #expect(LivePermissionService.access(system: .denied, hasDeclined: false) == .denied)
        #expect(LivePermissionService.access(system: .restricted, hasDeclined: false) == .denied)
    }

    @Test func beforeAnyAnswerNothingIsDecided() {
        #expect(LivePermissionService.access(system: .notDetermined, hasDeclined: false) == .notDetermined)
    }

    @Test func notNowCountsAsDeniedUntilTheSystemIsAsked() {
        #expect(LivePermissionService.access(system: .notDetermined, hasDeclined: true) == .denied)
    }

    @Test func aLaterYesInSettingsOverridesNotNow() {
        #expect(LivePermissionService.access(system: .authorized, hasDeclined: true) == .granted)
    }
}
