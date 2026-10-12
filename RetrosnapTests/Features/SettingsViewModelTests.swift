import Testing
@testable import Retrosnap

@MainActor
struct SettingsViewModelTests {
    private let world = TestWorld(path: [.gallery, .settings])

    private func make() -> SettingsViewModel {
        SettingsViewModel(settings: world.settings, storage: world.storage, router: world.router, toasts: world.toasts)
    }

    @Test func rowsAreGroupedAsInTheDesign() {
        let groups = make().groups
        #expect(groups.map { $0.map(\.label) } == [
            ["Save to Photos", "Video quality"],
            ["Shutter sound", "Haptics"],
            ["Storage"],
            ["Privacy", "Help", "About"],
        ])
    }

    @Test func valueRowsShowTheirValues() {
        let rows = make().groups.flatMap { $0 }
        func value(_ label: String) -> String? {
            if case .link(let value)? = rows.first(where: { $0.label == label })?.kind { value } else { nil }
        }
        #expect(value("Video quality") == "1080p")
        #expect(value("Storage") == "1.2 GB")
        #expect(value("Privacy") == "")
        #expect(value("About") == "Version 1.0")
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

    @Test func tappingAValueRowNamesItInAToast() {
        let vm = make()
        vm.linkTapped("Privacy")
        #expect(world.toasts.current?.text == "Privacy")
        #expect(world.router.path == [.gallery, .settings])
    }

    @Test func backReturnsToTheGallery() {
        make().backTapped()
        #expect(world.router.path == [.gallery])
    }

    @Test func footerStatesThePromise() {
        #expect(make().footer == "Free forever. No accounts, no ads.\nYour photos never leave your phone.")
    }
}
