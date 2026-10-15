import Testing
@testable import Retrosnap

@MainActor
struct DevelopViewModelTests {
    private let world: TestWorld
    private let draft: Photo

    init() {
        let world = TestWorld()
        draft = world.draft("d1")
        world.router.push(.gallery)
        world.router.push(.develop(draft))
        self.world = world
    }

    private func make(_ draft: Photo? = nil) -> DevelopViewModel {
        DevelopViewModel(
            draft: draft ?? self.draft, photos: world.photos, saver: world.saver, importer: world.importer,
            player: world.clipPlayer, feedback: world.feedback, router: world.router, toasts: world.toasts,
            scheduler: world.scheduler, dayLabeler: world.dayLabeler
        )
    }

    // MARK: Opening state

    @Test func opensOnThePicksCameraWithTheChip() {
        let vm = make()
        #expect(vm.style == .film)
        #expect(vm.draft == draft)
        #expect(vm.isChipVisible)
        #expect(!vm.isStripVisible)
        #expect(!vm.isVideo)
        #expect(vm.kindTitle == "Photo")
        #expect(vm.shutterLabel == "Develop photo")
        #expect(vm.chipLabel == "Camera: D Classic. Change camera")
        #expect(vm.pictureLabel == "Photo from your library, D Classic")
        #expect(vm.stripTitle == "D Classic")
        #expect(vm.stripSubtitle == "True, gently warm colour and a red date in the corner.")
        #expect(vm.stamp.date == "'26 10 11")
        #expect(vm.picture == draft.image)
        #expect(vm.badgeText == nil)
        #expect(!vm.isDeveloping)
    }

    @Test func aClipSaysWhatItIsAndHowLong() {
        let vm = make(world.draft("v1", camera: .camcorder, video: 24))
        #expect(vm.isVideo)
        #expect(vm.kindTitle == "Video 0:24")
        #expect(vm.shutterLabel == "Develop video")
        #expect(vm.badgeText == "")
        #expect(vm.pictureLabel == "Video 0:24 from your library, Camcorder")
    }

    // MARK: Choosing a camera

    @Test func theChipOpensTheStripAndAPickFoldsItAway() {
        let vm = make()
        vm.chipTapped()
        #expect(vm.isStripVisible)
        #expect(!vm.isChipVisible)
        #expect(world.feedbackSpy.haptics == [.tick])

        vm.pick(.digicam)
        #expect(vm.style == .digicam)
        #expect(vm.draft.camera == .digicam)
        #expect(!vm.isStripVisible)
        #expect(vm.styleChangeCount == 1)
        #expect(world.feedbackSpy.haptics == [.tick, .soft])
    }

    @Test func pickingTheCameraAlreadyOnOnlyFoldsTheStrip() {
        let vm = make()
        vm.chipTapped()
        vm.pick(.film)
        #expect(!vm.isStripVisible)
        #expect(vm.styleChangeCount == 0)
    }

    @Test func closingTheStripLeavesTheCameraAlone() {
        let vm = make()
        vm.chipTapped()
        vm.closeStripTapped()
        #expect(!vm.isStripVisible)
        #expect(vm.style == .film)
    }

    @Test func swipingStepsThroughTheCamerasAndWraps() {
        let vm = make()
        vm.pictureSwiped(.left)
        #expect(vm.style == .disposable)
        vm.pictureSwiped(.right)
        #expect(vm.style == .film)
        vm.pictureSwiped(.right)
        #expect(vm.style == CameraStyle.allCases.last)
        #expect(vm.styleChangeCount == 3)
    }

    @Test func aTapOnThePictureFoldsTheStripAway() {
        let vm = make()
        vm.chipTapped()
        vm.pictureTapped()
        #expect(!vm.isStripVisible)
    }

    // MARK: Playing a clip

    @Test func aTapPlaysAClipWhereItSitsAndAnotherPausesIt() {
        let vm = make(world.draft("v1", camera: .camcorder, video: 24))
        vm.pictureTapped()
        #expect(world.clipPlayer.playedFiles == ["v1.mov"])
        #expect(vm.picture == .live)
        #expect(vm.badgeText == nil)

        vm.pictureTapped()
        #expect(!world.clipPlayer.isPlaying)
        #expect(vm.picture == .live)
        #expect(vm.badgeText == "")

        vm.pictureTapped()
        #expect(world.clipPlayer.playedFiles == ["v1.mov", "v1.mov"])
    }

    @Test func aTapOnAPhotoPlaysNothing() {
        let vm = make()
        vm.pictureTapped()
        #expect(world.clipPlayer.playedFiles.isEmpty)
    }

    @Test func leavingStopsTheClip() {
        let vm = make(world.draft("v1", camera: .camcorder, video: 24))
        vm.pictureTapped()
        vm.disappeared()
        #expect(world.clipPlayer.openFile == nil)
    }

    // MARK: Developing

    @Test func theShutterFilesThePickWithItsLookAndOpensTheResultAfterTheFlash() {
        let vm = make()
        vm.pick(.slide)
        vm.shutterPressed()
        vm.shutterTapped()

        #expect(vm.isDeveloping)
        #expect(vm.shutterCount == 1)
        #expect(world.feedbackSpy.haptics.last == .firm)
        #expect(world.feedbackSpy.clicks == 1)
        #expect(world.feedbackSpy.clickPrepareCount == 1)
        let filed = world.photos.photos.first
        #expect(filed?.id == "d1")
        #expect(filed?.camera == .slide)
        #expect(filed?.isJustCaptured == true)
        #expect(world.exporter.savedIDs == ["d1"])
        #expect(world.router.path == [.gallery, .develop(draft)])

        world.scheduler.advance(by: .milliseconds(419))
        #expect(world.router.path == [.gallery, .develop(draft)])
        world.scheduler.advance(by: .milliseconds(1))
        #expect(world.router.path == [.gallery, .result("d1")])
    }

    @Test func theShutterFiresOnce() {
        let vm = make()
        vm.shutterTapped()
        vm.shutterTapped()
        #expect(vm.shutterCount == 1)
        #expect(world.photos.photos.filter { $0.id == "d1" }.count == 1)
    }

    @Test func theShutterStopsAClipThatIsPlaying() {
        let vm = make(world.draft("v1", camera: .camcorder, video: 24))
        vm.pictureTapped()
        vm.shutterTapped()
        #expect(world.clipPlayer.openFile == nil)
        #expect(world.photos.photos.first?.videoFile == "v1.mov")
    }

    @Test func nothingChangesOnceTheShutterHasFired() {
        let vm = make()
        vm.shutterTapped()
        vm.chipTapped()
        #expect(!vm.isStripVisible)
        vm.pick(.camcorder)
        vm.pictureSwiped(.left)
        #expect(vm.style == .film)
        vm.cancelTapped()
        vm.chooseAnotherTapped()
        #expect(world.router.path == [.gallery, .develop(draft)])
        #expect(world.importer.pickCount == 0)
        #expect(world.importer.discarded.isEmpty)
    }

    @Test func theShutterWaitsWhileAnotherPickIsOnItsWayIn() {
        let vm = make()
        world.importer.isImporting = true
        #expect(vm.isImporting)
        vm.shutterTapped()
        #expect(!vm.isDeveloping)
        #expect(world.photos.photo(id: "d1") == nil)
    }

    // MARK: Leaving, or starting over

    @Test func cancelThrowsThePickAwayAndGoesBackToThePhotos() {
        let vm = make()
        vm.cancelTapped()
        #expect(world.importer.discarded == [draft])
        #expect(world.router.path == [.gallery])
        #expect(world.photos.photo(id: "d1") == nil)
    }

    @Test func chooseAnotherSwapsThePickAndKeepsTheCamera() {
        let vm = make()
        vm.pick(.camcorder)
        vm.chooseAnotherTapped()
        #expect(world.importer.pickCount == 1)

        world.importer.deliver(.imported(world.draft("d2")))
        #expect(vm.draft.id == "d2")
        #expect(vm.style == .camcorder)
        #expect(world.importer.discarded.map(\.id) == ["d1"])
        #expect(world.router.path == [.gallery, .develop(draft)])
    }

    @Test func aSecondPickCalledOffOrFailedKeepsTheFirst() {
        let vm = make()
        vm.chooseAnotherTapped()
        world.importer.deliver(.cancelled)
        #expect(vm.draft.id == "d1")
        #expect(world.importer.discarded.isEmpty)

        vm.chooseAnotherTapped()
        world.importer.deliver(.failed)
        #expect(vm.draft.id == "d1")
        #expect(world.toasts.current?.text == "Couldn’t open that photo or video")
    }

    @Test func chooseAnotherStopsAClipThatIsPlaying() {
        let vm = make(world.draft("v1", camera: .camcorder, video: 24))
        vm.pictureTapped()
        vm.chooseAnotherTapped()
        #expect(world.clipPlayer.openFile == nil)
        #expect(vm.picture == vm.draft.image)
    }
}
