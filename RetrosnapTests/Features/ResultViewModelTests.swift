import Testing
@testable import Retrosnap

@MainActor
struct ResultViewModelTests {
    private let world: TestWorld
    private let fresh: Photo

    init() {
        let world = TestWorld()
        fresh = world.camera.capturePhoto(style: .film, facing: .back)
        world.photos.add(fresh)
        world.router.showResult(fresh.id)
        self.world = world
    }

    private func make(
        _ id: Photo.ID? = nil, isProcessing: Bool = false, saver: PhotosSaver? = nil, sharing: (any PhotoSharing)? = nil
    ) -> ResultViewModel {
        ResultViewModel(
            photoID: id ?? fresh.id, photos: world.photos, saver: saver ?? world.saver,
            sharing: sharing ?? world.sharing, router: world.router,
            toasts: world.toasts, scheduler: world.scheduler, dayLabeler: DayLabeler(clock: world.clock),
            isProcessing: isProcessing
        )
    }

    @Test func developsForNineHundredMilliseconds() {
        let vm = make()
        vm.appeared()
        #expect(vm.isDeveloping)
        #expect(vm.statusText == "Developing…")
        world.scheduler.advance(by: .milliseconds(899))
        #expect(vm.isDeveloping)
        world.scheduler.advance(by: .milliseconds(1))
        #expect(!vm.isDeveloping)
        #expect(vm.statusText == "Saved to Photos")
    }

    @Test func appearingAgainDoesNotRestartDeveloping() {
        let vm = make()
        vm.appeared()
        world.scheduler.advance(by: .seconds(1))
        vm.appeared()
        #expect(!vm.isDeveloping)
        #expect(world.scheduler.pendingCount == 0)
    }

    @Test func processingBoardNeverFinishes() {
        let vm = make(isProcessing: true)
        vm.appeared()
        world.scheduler.advance(by: .seconds(10))
        #expect(vm.isDeveloping)
        #expect(vm.isProcessing)
    }

    @Test func aClipBeingBakedShowsItsProgressUntilItIsDone() {
        let vm = make()
        world.exporter.progress[fresh.id] = 0.3
        vm.appeared()
        world.scheduler.advance(by: .seconds(2))
        #expect(vm.isProcessing)
        #expect(vm.processingProgress == 0.3)
        #expect(vm.isDeveloping)
        #expect(vm.statusText == "Developing…")

        world.exporter.progress[fresh.id] = nil
        #expect(!vm.isProcessing)
        #expect(!vm.isDeveloping)
        #expect(vm.statusText == "Saved to Photos")
    }

    @Test func aPhotoIsNeverShownAsProcessing() {
        let vm = make()
        #expect(!vm.isProcessing)
        #expect(vm.processingProgress == nil)
    }

    @Test func theProcessingBoardIsStuckPartWay() {
        #expect(make(isProcessing: true).processingProgress == 0.62)
    }

    @Test func metaLineNamesTheCameraAndWhen() {
        #expect(make().metaText == "35mm Film · Just now")
        #expect(make("s3").metaText == "Instant · Today")
        #expect(make("s10").metaText == "Camcorder · October 4")
        #expect(make("missing").metaText == "")
    }

    @Test func instantPhotosAreShownAsFramedPrints() {
        #expect(make("s3").isInstant)
        #expect(!make().isInstant)
    }

    @Test func stampUsesThePhotosDate() {
        #expect(make().stamp?.date == "'26 10 11")
        #expect(make("s10").stamp?.date == "'26 10 04")
    }

    @Test func takeAnotherReturnsToTheCameraAndConfirmsTheSave() {
        let vm = make()
        vm.takeAnotherTapped()
        #expect(world.router.path.isEmpty)
        #expect(world.toasts.current?.text == "Saved to Photos")
    }

    @Test func closeDoesTheSameAsTakeAnother() {
        let vm = make()
        vm.closeTapped()
        #expect(world.router.path.isEmpty)
        #expect(world.toasts.current?.text == "Saved to Photos")
    }

    @Test func aShotKeptInsideTheAppSaysSoInsteadOfPhotos() {
        let inApp = PhotosSaver(
            exporter: world.exporter, permissions: MockPermissionService(photoLibraryAccess: .denied),
            settings: world.settings, toasts: world.toasts
        )
        let vm = make(saver: inApp)
        vm.appeared()
        world.scheduler.advance(by: ResultViewModel.developTime)
        #expect(vm.statusText == "Saved in RetroSnap")

        vm.takeAnotherTapped()
        #expect(world.toasts.current?.text == "Saved in RetroSnap")
    }

    @Test func shareIsAPlaceholderToast() {
        let vm = make()
        vm.perform(.share)
        #expect(world.toasts.current?.text == "Share sheet opens here")
        #expect(world.router.path == [.result(fresh.id)])
    }

    @Test func shareHandsTheShotToTheShareSheet() {
        let sheet = ShareSpy()
        make(sharing: sheet).perform(.share)
        #expect(sheet.sharedIDs == [fresh.id])
        #expect(world.router.path == [.result(fresh.id)])
    }

    @Test func editPrintAndCollageOpenOnTopOfTheResult() {
        let vm = make()
        vm.perform(.edit)
        #expect(world.router.path == [.result(fresh.id), .edit(fresh.id)])
        world.router.back()
        vm.perform(.print)
        #expect(world.router.path == [.result(fresh.id), .print(fresh.id)])
        world.router.back()
        vm.perform(.collage)
        #expect(world.router.path == [.result(fresh.id), .collage(seed: fresh.id)])
    }

    @Test func deleteReturnsToTheCameraAndCanBeUndone() {
        let vm = make()
        vm.perform(.delete)
        #expect(world.photos.photo(id: fresh.id) == nil)
        #expect(world.router.path.isEmpty)
        #expect(world.toasts.current?.text == "Photo deleted")
        #expect(world.toasts.current?.actionTitle == "Undo")

        world.toasts.performAction()
        #expect(world.photos.photos.first?.id == fresh.id)
        #expect(world.toasts.current == nil)
    }

    @Test func actionsAreListedInTheDesignOrderWithDeleteMarkedDestructive() {
        #expect(PhotoAction.allCases.map(\.label) == ["Share", "Edit", "Print", "Collage", "Delete"])
        #expect(PhotoAction.allCases.filter(\.isDestructive) == [.delete])
    }
}
