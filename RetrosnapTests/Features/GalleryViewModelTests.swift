import Testing
@testable import Retrosnap

@MainActor
struct GalleryViewModelTests {

    private func make(_ world: TestWorld) -> GalleryViewModel {
        GalleryViewModel(
            photos: world.photos, settings: world.settings, importer: world.importer, router: world.router,
            toasts: world.toasts, dayLabeler: DayLabeler(clock: world.clock)
        )
    }

    @Test func groupsPhotosByDayNewestFirst() {
        let vm = make(TestWorld(path: [.gallery]))
        #expect(vm.sections.map(\.title) == ["Today", "Yesterday", "October 4"])
        #expect(vm.sections.map(\.countText) == ["4", "5", "4"])
        #expect(vm.sections[0].photos.map(\.id) == ["s1", "s2", "s3", "s4"])
        #expect(vm.sections[2].photos.map(\.id) == ["s10", "s11", "s12", "s13"])
        #expect(!vm.isEmpty)
    }

    @Test func aNewShotLeadsToday() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        world.photos.add(world.camera.capturePhoto(style: .digicam, facing: .back))
        #expect(vm.sections[0].countText == "5")
        #expect(vm.sections[0].photos.first?.camera == .digicam)
    }

    @Test func daysWithNoPhotosLeftDisappear() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        for id in ["s1", "s2", "s3", "s4"] {
            world.photos.delete(id: id)
        }
        #expect(vm.sections.map(\.title) == ["Yesterday", "October 4"])
    }

    @Test func cameraPillIsQuietWhenThereArePhotos() {
        let vm = make(TestWorld(path: [.gallery]))
        #expect(vm.actionTitle == "Camera")
        #expect(!vm.isActionPrimary)
    }

    @Test func emptyGalleryPromotesTakingAPhoto() {
        let vm = make(TestWorld(photos: [], path: [.gallery]))
        #expect(vm.isEmpty)
        #expect(vm.sections.isEmpty)
        #expect(vm.actionTitle == "Take a photo")
        #expect(vm.isActionPrimary)
    }

    @Test func openingAPhotoPushesTheViewer() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        vm.open(vm.sections[1].photos[2])
        #expect(world.router.path == [.gallery, .viewer("s7")])
    }

    @Test func closeAndCameraPillBothReturnToTheCamera() {
        let world = TestWorld(path: [.gallery])
        make(world).closeTapped()
        #expect(world.router.path.isEmpty)

        let other = TestWorld(path: [.gallery])
        make(other).cameraTapped()
        #expect(other.router.path.isEmpty)
    }

    @Test func settingsOpensFromTheGallery() {
        let world = TestWorld(path: [.gallery])
        make(world).settingsTapped()
        #expect(world.router.path == [.gallery, .settings])
    }

    @Test func tilesDescribeThemselvesForVoiceOver() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        #expect(vm.accessibilityLabel(for: world.photos.photos[0]) == "D Classic photo, Today")
        let clip = world.camera.finishRecording(seconds: 5, style: .camcorder, facing: .back)
        #expect(vm.accessibilityLabel(for: clip) == "Camcorder video, Today")
        var collage = world.photo("collage")
        collage.isCollage = true
        #expect(vm.accessibilityLabel(for: collage) == "Collage, Today")
    }

    // MARK: Bringing in a picture from the library

    @Test func addOpensThePickerAndThePickGoesToDevelopOnTheCurrentCamera() {
        let world = TestWorld(path: [.gallery])
        world.settings.lastCamera = .digicam
        let vm = make(world)
        vm.addTapped()
        #expect(world.importer.pickCount == 1)
        #expect(world.router.path == [.gallery])

        world.importer.deliver(.imported(world.draft("d1")))
        var expected = world.draft("d1")
        expected.camera = .digicam
        #expect(world.router.path == [.gallery, .develop(expected)])
        #expect(world.importer.discarded.isEmpty)
    }

    @Test func aPickThatIsCalledOffChangesNothing() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        vm.addTapped()
        world.importer.deliver(.cancelled)
        #expect(world.router.path == [.gallery])
        #expect(world.toasts.current == nil)
    }

    @Test func aPickThatCannotBeOpenedSaysSo() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        vm.addTapped()
        world.importer.deliver(.failed)
        #expect(world.router.path == [.gallery])
        #expect(world.toasts.current?.text == "Couldn’t open that photo or video")
    }

    @Test func thePickIsNotAskedForTwiceWhileOneIsOnItsWayIn() {
        let world = TestWorld(path: [.gallery])
        let vm = make(world)
        #expect(!vm.isImporting)
        #expect(vm.addLabel == "Add from your library")
        world.importer.isImporting = true
        #expect(vm.isImporting)
        #expect(vm.addLabel == "Opening your pick")
        vm.addTapped()
        #expect(world.importer.pickCount == 0)
    }
}
