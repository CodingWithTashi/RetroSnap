import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct CollageViewModelTests {
    private let world = TestWorld(path: [.gallery, .viewer("s1"), .collage(seed: "s1")])

    private func make(
        seed: Photo.ID? = "s1", step: Int = 1, exporter: (any PhotoExporting)? = nil,
        saver: PhotosSaver? = nil, sharing: (any PhotoSharing)? = nil
    ) -> CollageViewModel {
        CollageViewModel(
            seedID: seed, photos: world.photos, exporter: exporter ?? world.exporter, saver: saver ?? world.saver,
            sharing: sharing ?? world.sharing, router: world.router, toasts: world.toasts,
            feedback: world.feedback, startStep: step, boardPicks: SeedData.arrangeBoardPicks
        )
    }

    // MARK: Step 1, layout

    @Test func startsOnLayoutWithTheCurrentPhotoPrePicked() {
        let vm = make()
        #expect(vm.step == .layout)
        #expect(vm.template == .feature)
        #expect(vm.pickedIDs == ["s1"])
        #expect(vm.border == .cream)
        #expect(vm.title == "Choose a layout")
        #expect(vm.subtitle == "Step 1 of 3")
        #expect(vm.actionTitle == "Choose 3 photos")
        #expect(vm.isActionEnabled)
    }

    @Test func aVideoIsNotPrePicked() {
        let clip = world.camera.finishRecording(seconds: 3, style: .camcorder, facing: .back)
        world.photos.add(clip)
        #expect(make(seed: clip.id).pickedIDs.isEmpty)
        #expect(make(seed: nil).pickedIDs.isEmpty)
        #expect(make(seed: "missing").pickedIDs.isEmpty)
    }

    @Test func templatesMatchTheDesign() {
        #expect(CollageTemplate.allCases.map(\.label) == ["Feature", "Stacked", "Side by side", "Grid", "Photo strip", "Trio"])
        #expect(CollageTemplate.allCases.map(\.photoCount) == [3, 2, 2, 4, 4, 3])
        #expect(CollageTemplate.feature.cells == [
            CGRect(x: 0, y: 0, width: 100, height: 60),
            CGRect(x: 0, y: 60, width: 50, height: 40),
            CGRect(x: 50, y: 60, width: 50, height: 40),
        ])
        #expect(CollageTemplate.allCases.allSatisfy { $0.cells.count == $0.photoCount })
    }

    @Test func actionTitleFollowsTheTemplate() {
        let vm = make()
        vm.select(.grid)
        #expect(vm.actionTitle == "Choose 4 photos")
        vm.select(.stacked)
        #expect(vm.actionTitle == "Choose 2 photos")
    }

    @Test func aSmallerTemplateDropsTheExtraPicks() {
        let vm = make()
        vm.actionTapped()
        vm.togglePick("s2")
        vm.togglePick("s3")
        vm.backTapped()
        vm.select(.stacked)
        #expect(vm.pickedIDs == ["s1", "s2"])
    }

    // MARK: Step 2, picking

    @Test func pickingNumbersPhotosInOrderUpToTheTemplatesCount() {
        let vm = make()
        vm.actionTapped()
        #expect(vm.step == .pick)
        #expect(vm.title == "Choose 3 photos")
        #expect(vm.subtitle == "Step 2 of 3")
        #expect(vm.actionTitle == "1 of 3 selected")
        #expect(!vm.isActionEnabled)

        vm.togglePick("s5")
        vm.togglePick("s3")
        vm.togglePick("s9")
        #expect(vm.pickedIDs == ["s1", "s5", "s3"])
        #expect(vm.pickNumber(for: "s5") == 2)
        #expect(vm.pickNumber(for: "s9") == nil)
        #expect(vm.actionTitle == "Next")
        #expect(vm.isActionEnabled)
    }

    @Test func unpickingRenumbersTheRest() {
        let vm = make()
        vm.actionTapped()
        vm.togglePick("s5")
        vm.togglePick("s3")
        vm.togglePick("s1")
        #expect(vm.pickedIDs == ["s5", "s3"])
        #expect(vm.pickNumber(for: "s3") == 2)
        #expect(vm.actionTitle == "2 of 3 selected")
    }

    @Test func cannotLeaveThePickStepUntilEnoughArePicked() {
        let vm = make()
        vm.actionTapped()
        vm.actionTapped()
        #expect(vm.step == .pick)
    }

    @Test func videosAreNotOffered() {
        let clip = world.camera.finishRecording(seconds: 3, style: .camcorder, facing: .back)
        world.photos.add(clip)
        let vm = make()
        #expect(vm.candidates.count == 13)
        #expect(!vm.candidates.contains { $0.id == clip.id })
    }

    // MARK: Step 3, arranging

    private func arranged(
        exporter: (any PhotoExporting)? = nil, saver: PhotosSaver? = nil, sharing: (any PhotoSharing)? = nil
    ) -> CollageViewModel {
        let vm = make(exporter: exporter, saver: saver, sharing: sharing)
        vm.actionTapped()
        vm.togglePick("s3")
        vm.togglePick("s2")
        vm.actionTapped()
        return vm
    }

    @Test func arrangeShowsThePicksInTemplateOrder() {
        let vm = arranged()
        #expect(vm.step == .arrange)
        #expect(vm.title == "Arrange")
        #expect(vm.subtitle == "Step 3 of 3")
        #expect(vm.actionTitle == "Save collage")
        #expect(vm.arrangedPhotos.map(\.id) == ["s1", "s3", "s2"])
        #expect(vm.hint == "Tap two photos to swap them")
    }

    @Test func tappingTwoPhotosSwapsThem() {
        let vm = arranged()
        vm.cellTapped(0)
        #expect(vm.swapSelection == 0)
        #expect(vm.hint == "Now tap where it should go")
        vm.cellTapped(2)
        #expect(vm.arrangedPhotos.map(\.id) == ["s2", "s3", "s1"])
        #expect(vm.swapSelection == nil)
        #expect(vm.hint == "Tap two photos to swap them")
        #expect(world.feedbackSpy.haptics.last == .soft)
    }

    @Test func tappingTheSamePhotoTwiceJustDeselects() {
        let vm = arranged()
        vm.cellTapped(1)
        vm.cellTapped(1)
        #expect(vm.swapSelection == nil)
        #expect(vm.arrangedPhotos.map(\.id) == ["s1", "s3", "s2"])
    }

    @Test func borderChoicesAndFrameMetrics() {
        let vm = arranged()
        #expect(CollageBorder.allCases.map(\.label) == ["Cream", "Black", "No border"])
        #expect(vm.frameInset == 10)
        #expect(vm.cellGap == 4)
        vm.select(.none)
        #expect(vm.border == .none)
        #expect(vm.frameInset == 0)
        #expect(vm.cellGap == 0)
        #expect(vm.frameSize == CGSize(width: 300, height: 400))
    }

    @Test func photoStripIsTallAndNarrow() {
        let vm = make()
        vm.select(.strip)
        #expect(vm.frameSize.width == 170)
        #expect(abs(vm.frameSize.height - 459) < 0.01)
    }

    @Test func saveReturnsToTheGalleryAndConfirms() {
        let vm = arranged()
        vm.actionTapped()
        #expect(world.router.path == [.gallery])
        #expect(world.toasts.current?.text == "Collage saved to Photos")
        #expect(world.feedbackSpy.haptics.last == .firm)
    }

    @Test func saveFromAResultOpensTheGallery() {
        let world = TestWorld(path: [.result("s1"), .collage(seed: "s1")])
        let vm = CollageViewModel(
            seedID: "s1", photos: world.photos, exporter: world.exporter, saver: world.saver, sharing: world.sharing,
            router: world.router, toasts: world.toasts, feedback: world.feedback, startStep: 3,
            boardPicks: SeedData.arrangeBoardPicks
        )
        vm.actionTapped()
        #expect(world.router.path == [.gallery])
    }

    // MARK: A real collage

    @Test func savingFilesTheCollageInTheLibraryAndSendsItToPhotos() throws {
        let vm = arranged()
        vm.select(.black)
        vm.actionTapped()
        let collage = try #require(world.photos.photos.first)
        #expect(world.photos.photos.count == 14)
        #expect(collage.isCollage)
        #expect(world.exporter.savedIDs == [collage.id])
    }

    @Test func theCollageIsMadeFromTheArrangementOnScreen() throws {
        let exporter = ExporterSpy()
        let vm = arranged(exporter: exporter)
        vm.cellTapped(0)
        vm.cellTapped(2)
        vm.select(.none)
        vm.actionTapped()
        let collage = try #require(exporter.collages.first)
        #expect(collage.template == .feature)
        #expect(collage.border == .none)
        #expect(collage.photos.map(\.id) == ["s2", "s3", "s1"])
    }

    @Test func theScreenStaysUntilTheCollageIsMade() {
        let exporter = ExporterSpy()
        let vm = arranged(exporter: exporter)
        vm.actionTapped()
        vm.actionTapped()
        #expect(exporter.collages.count == 1)
        #expect(world.router.topRoute == .collage(seed: "s1"))
        #expect(world.toasts.current == nil)

        var made = world.photo("collage")
        made.isCollage = true
        exporter.deliver(made)
        #expect(world.photos.photos.first?.id == "collage")
        #expect(world.router.path == [.gallery])
        #expect(world.toasts.current?.text == "Collage saved to Photos")
    }

    @Test func aCollageThatCouldNotBeMadeSaysSoAndStaysOnTheScreen() {
        let exporter = ExporterSpy()
        let vm = arranged(exporter: exporter)
        vm.actionTapped()
        exporter.deliver(nil)
        #expect(world.photos.photos.count == 13)
        #expect(world.router.topRoute == .collage(seed: "s1"))
        #expect(world.toasts.current?.text == "Couldn’t save the collage")

        vm.actionTapped()
        #expect(exporter.collages.count == 2)
    }

    @Test func aCollageKeptInsideTheAppSaysSo() {
        let inApp = PhotosSaver(
            exporter: world.exporter, permissions: MockPermissionService(photoLibraryAccess: .denied),
            settings: world.settings, toasts: world.toasts
        )
        let vm = arranged(saver: inApp)
        vm.actionTapped()
        #expect(world.photos.photos.count == 14)
        #expect(world.exporter.savedIDs.isEmpty)
        #expect(world.toasts.current?.text == "Collage saved in RetroSnap")
    }

    @Test func shareHandsTheArrangementToTheShareSheet() throws {
        let sheet = ShareSpy()
        let vm = arranged(sharing: sheet)
        vm.shareTapped()
        let collage = try #require(sheet.sharedCollages.first)
        #expect(collage.photos.map(\.id) == ["s1", "s3", "s2"])
        #expect(world.photos.photos.count == 13)
    }

    @Test func aSavedCollageCanGoIntoAnotherOne() {
        var collage = world.photo("collage")
        collage.isCollage = true
        world.photos.add(collage)
        #expect(make().candidates.contains { $0.id == "collage" })
    }

    @Test func shareIsAPlaceholderToast() {
        arranged().shareTapped()
        #expect(world.toasts.current?.text == "Share sheet opens here")
    }

    // MARK: Back

    @Test func backStepsDownThenLeaves() {
        let vm = arranged()
        vm.cellTapped(0)
        vm.backTapped()
        #expect(vm.step == .pick)
        #expect(vm.swapSelection == nil)
        vm.backTapped()
        #expect(vm.step == .layout)
        vm.backTapped()
        #expect(world.router.path == [.gallery, .viewer("s1")])
    }

    @Test func arrangeBoardPresetStartsWithThreePhotosPicked() {
        let vm = make(step: 3)
        #expect(vm.step == .arrange)
        #expect(vm.arrangedPhotos.map(\.id) == ["s1", "s3", "s2"])
    }
}
