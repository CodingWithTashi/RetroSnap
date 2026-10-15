import Foundation
import Testing
@testable import Retrosnap

@MainActor
struct SettingsViewModelTests {
    private let world = TestWorld(path: [.gallery, .settings])
    private let privacy = URL(string: "https://example.com/privacy")!
    private let help = URL(string: "mailto:help@example.com?subject=RetroSnap")!

    /// Remembers the addresses the view model asked to have opened, and says whether anything opened them.
    private final class Opened {
        var urls: [URL] = []
        var succeeds = true
    }

    private let opened = Opened()

    private func make(
        location: (any LocationProviding)? = nil, permissions: (any PermissionServicing)? = nil,
        storage: (any StorageMonitoring)? = nil, links: AppLinks? = nil
    ) -> SettingsViewModel {
        // The saver sees the same permissions as the screen, as it does in the app.
        let permissions = permissions ?? world.permissions
        return SettingsViewModel(
            settings: world.settings, storage: storage ?? world.storage, location: location ?? world.location,
            permissions: permissions,
            saver: PhotosSaver(
                exporter: world.exporter, permissions: permissions, settings: world.settings, toasts: world.toasts
            ),
            links: links ?? AppLinks(privacyPolicy: privacy, support: help),
            openLink: { [opened] url, completion in
                opened.urls.append(url)
                completion(opened.succeeds)
            },
            router: world.router, toasts: world.toasts
        )
    }

    @Test func rowsAreGroupedAsInTheDesign() {
        let groups = make().groups
        #expect(groups.map { $0.map(\.label) } == [
            ["Save to Photos", "Location on photos", "Video quality"],
            ["Shutter sound", "Haptics"],
            ["Storage"],
            ["Privacy", "Help", "About"],
        ])
    }

    @Test func valueRowsShowTheirValues() {
        let rows = make().groups.flatMap { $0 }
        func value(_ label: String) -> String? {
            if case .value(let value)? = rows.first(where: { $0.label == label })?.kind { value } else { nil }
        }
        #expect(value("Video quality") == "1080p")
        #expect(value("Storage") == "1.2 GB")
        #expect(value("About") == "Version 1.0")
    }

    @Test func privacyAndHelpLeadOutOfTheApp() {
        let rows = make().groups.flatMap { $0 }
        #expect(rows.first { $0.label == "Privacy" }?.kind == .link(privacy))
        #expect(rows.first { $0.label == "Help" }?.kind == .link(help))
    }

    @Test func aRowWithNowhereToLeadIsNotShown() {
        let none = make(links: AppLinks(privacyPolicy: nil, support: nil)).groups
        #expect(none.last?.map(\.label) == ["About"])

        let helpOnly = make(links: AppLinks(privacyPolicy: nil, support: help)).groups
        #expect(helpOnly.last?.map(\.label) == ["Help", "About"])
    }

    @Test func togglesStartOnAndWriteThrough() {
        let vm = make()
        #expect(vm.isOn(.saveToPhotos) && vm.isOn(.shutterSound) && vm.isOn(.haptics))

        vm.toggle(.shutterSound)
        #expect(!world.settings.shutterSound)
        #expect(!vm.isOn(.shutterSound))

        vm.toggle(.haptics)
        vm.toggle(.saveToPhotos)
        #expect(!world.settings.haptics)
        #expect(!world.settings.saveToPhotos)

        vm.toggle(.haptics)
        #expect(world.settings.haptics)
    }

    // MARK: Save to Photos

    @Test func theSaveSwitchShowsOffWhilePhotosAccessIsMissing() {
        let vm = make(permissions: PermissionSpy(photoLibraryAccess: .denied))
        #expect(world.settings.saveToPhotos)
        #expect(!vm.isOn(.saveToPhotos))
    }

    @Test func turningSavingOnWithoutAccessAsksForIt() {
        let permissions = PermissionSpy(photoLibraryAccess: .denied)
        let vm = make(permissions: permissions)
        vm.toggle(.saveToPhotos)
        #expect(world.settings.saveToPhotos)
        #expect(permissions.photoLibraryRequestCount == 1)

        permissions.answerPhotoLibraryPrompt(.granted)
        #expect(vm.isOn(.saveToPhotos))
    }

    @Test func turningSavingOffAsksNothing() {
        let permissions = PermissionSpy(photoLibraryAccess: .granted)
        let vm = make(permissions: permissions)
        vm.toggle(.saveToPhotos)
        #expect(!world.settings.saveToPhotos)
        #expect(!vm.isOn(.saveToPhotos))
        #expect(permissions.photoLibraryRequestCount == 0)

        vm.toggle(.saveToPhotos)
        #expect(vm.isOn(.saveToPhotos))
        #expect(permissions.photoLibraryRequestCount == 0)
    }

    // MARK: Storage

    @Test func storageIsMeasuredWhenSettingsOpens() {
        let storage = StorageSpy()
        storage.usedText = "356 MB"
        let vm = make(storage: storage)
        #expect(storage.refreshCount == 0)
        vm.appeared()
        #expect(storage.refreshCount == 1)
        let rows = vm.groups.flatMap { $0 }
        #expect(rows.first { $0.label == "Storage" }?.kind == .value("356 MB"))
    }

    // MARK: Location on photos

    @Test func locationIsOffUntilItIsTurnedOn() {
        let location = LocationSpy(isAllowed: true)
        let vm = make(location: location)
        #expect(!vm.isOn(.locationOnPhotos))
        #expect(!world.settings.locationOnPhotos)
        #expect(location.requestCount == 0)
    }

    @Test func turningLocationOnAsksForAccessFirst() {
        let location = LocationSpy()
        let vm = make(location: location)
        vm.toggle(.locationOnPhotos)
        #expect(location.requestCount == 1)
        #expect(!vm.isOn(.locationOnPhotos))

        location.answerPrompt(true)
        #expect(world.settings.locationOnPhotos)
        #expect(vm.isOn(.locationOnPhotos))
        #expect(world.toasts.current == nil)
    }

    @Test func aRefusalLeavesLocationOffAndOffersSettings() {
        let location = LocationSpy()
        let permissions = PermissionSpy()
        let vm = make(location: location, permissions: permissions)
        vm.toggle(.locationOnPhotos)
        location.answerPrompt(false)

        #expect(!world.settings.locationOnPhotos)
        #expect(!vm.isOn(.locationOnPhotos))
        #expect(world.toasts.current?.text == "Location access is off")
        #expect(world.toasts.current?.actionTitle == "Settings")

        world.toasts.performAction()
        #expect(permissions.openSettingsCount == 1)
    }

    @Test func turningLocationOffAsksNothing() {
        world.settings.locationOnPhotos = true
        let location = LocationSpy(isAllowed: true)
        let vm = make(location: location)
        #expect(vm.isOn(.locationOnPhotos))

        vm.toggle(.locationOnPhotos)
        #expect(!world.settings.locationOnPhotos)
        #expect(!vm.isOn(.locationOnPhotos))
        #expect(location.requestCount == 0)
    }

    @Test func theSwitchShowsOffOnceAccessIsTakenAwayInSettings() {
        world.settings.locationOnPhotos = true
        let location = LocationSpy(isAllowed: false)
        let vm = make(location: location)
        #expect(!vm.isOn(.locationOnPhotos))

        // Tapping it asks again instead of turning the setting off.
        vm.toggle(.locationOnPhotos)
        #expect(location.requestCount == 1)
        #expect(world.settings.locationOnPhotos)
    }

    @Test func tappingALinkOpensItAndStaysInSettings() {
        let vm = make()
        vm.linkTapped(privacy)
        #expect(opened.urls == [privacy])
        #expect(world.toasts.current == nil)
        #expect(world.router.path == [.gallery, .settings])
    }

    @Test func anEmailThatCannotBeStartedShowsTheAddressToWriteTo() {
        opened.succeeds = false
        make().linkTapped(help)
        #expect(world.toasts.current?.text == "Write to help@example.com")
    }

    @Test func aPageThatCannotBeOpenedSaysSo() {
        opened.succeeds = false
        make().linkTapped(privacy)
        #expect(world.toasts.current?.text == "Couldn’t open the page")
    }

    @Test func theReleasedAppHasBothLinks() {
        #expect(AppLinks.released.privacyPolicy?.host() == "kharagedition.github.io")
        #expect(AppLinks.released.support?.scheme == "mailto")
    }

    @Test func backReturnsToTheGallery() {
        make().backTapped()
        #expect(world.router.path == [.gallery])
    }

    @Test func footerStatesThePromise() {
        #expect(make().footer == "Free forever. No accounts, no ads.\nYour photos never leave your phone.")
    }
}
