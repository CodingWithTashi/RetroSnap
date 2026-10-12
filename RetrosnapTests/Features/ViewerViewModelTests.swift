import Testing
@testable import Retrosnap

@MainActor
struct ViewerViewModelTests {
    private let world = TestWorld(path: [.gallery, .viewer("s2")])

    private func make(_ id: Photo.ID = "s2", sharing: (any PhotoSharing)? = nil) -> ViewerViewModel {
        ViewerViewModel(
            photoID: id, photos: world.photos, player: world.clipPlayer, sharing: sharing ?? world.sharing,
            router: world.router, toasts: world.toasts,
            dayLabeler: DayLabeler(clock: world.clock)
        )
    }

    /// A recorded clip in the library, with its movie on file.
    private func recordedClip() -> Photo {
        var clip = world.photo("clip", camera: .camcorder, video: 12)
        clip.videoFile = "clip.mov"
        world.photos.add(clip)
        return clip
    }

    @Test func opensOnThePhotoThatWasTapped() {
        let vm = make()
        #expect(vm.photo?.id == "s2")
        #expect(vm.title == "Today")
        #expect(vm.subtitle == "Disposable")
        #expect(!vm.isInstant)
    }

    @Test func swipingLeftGoesToTheNextPhotoAndRightGoesBack() {
        let vm = make()
        vm.swiped(.left)
        #expect(vm.photo?.id == "s3")
        #expect(vm.isInstant)
        vm.swiped(.right)
        vm.swiped(.right)
        #expect(vm.photo?.id == "s1")
    }

    @Test func pagingStopsAtBothEnds() {
        let first = make("s1")
        first.swiped(.right)
        #expect(first.photo?.id == "s1")

        let last = make("s13")
        last.swiped(.left)
        #expect(last.photo?.id == "s13")
    }

    @Test func titleFollowsThePhotoOnScreen() {
        let vm = make("s4")
        #expect(vm.subtitle == "Camcorder")
        vm.swiped(.left)
        #expect(vm.title == "Yesterday")
        #expect(vm.subtitle == "35mm Film")
    }

    @Test func videosSaySoInTheSubtitle() {
        let clip = world.camera.finishRecording(seconds: 24, style: .camcorder, facing: .back)
        world.photos.add(clip)
        #expect(make(clip.id).subtitle == "Camcorder · Video")
    }

    // MARK: Playing a clip

    @Test func aClipShowsItsFirstFrameAndItsLengthUntilItIsPlayed() {
        let clip = recordedClip()
        let vm = make(clip.id)
        #expect(vm.picture == clip.image)
        #expect(vm.badgeText == "0:12")
        #expect(!world.clipPlayer.isPlaying)
    }

    @Test func tappingAClipPlaysItInPlaceAndTappingAgainPauses() {
        let vm = make(recordedClip().id)
        vm.photoTapped()
        #expect(world.clipPlayer.playedFiles == ["clip.mov"])
        #expect(vm.picture == .live)
        #expect(vm.badgeText == nil)

        vm.photoTapped()
        #expect(!world.clipPlayer.isPlaying)
        // Paused on the frame it reached, with the badge back to say it can go on.
        #expect(vm.picture == .live)
        #expect(vm.badgeText == "0:12")

        vm.photoTapped()
        #expect(world.clipPlayer.isPlaying)
        #expect(world.clipPlayer.playedFiles == ["clip.mov", "clip.mov"])
    }

    @Test func aClipThatPlaysToItsEndGoesBackToItsFirstFrame() {
        let clip = recordedClip()
        let vm = make(clip.id)
        vm.photoTapped()
        world.clipPlayer.finish()
        #expect(vm.picture == clip.image)
        #expect(vm.badgeText == "0:12")
    }

    @Test func tappingAPhotoPlaysNothing() {
        let vm = make()
        vm.photoTapped()
        #expect(world.clipPlayer.playedFiles.isEmpty)
        #expect(vm.picture == .photo(237))
        #expect(vm.badgeText == nil)
    }

    @Test func aClipWithoutAMovieOnFileCannotBePlayed() {
        let clip = world.photo("sample", camera: .camcorder, video: 24)
        world.photos.add(clip)
        let vm = make(clip.id)
        vm.photoTapped()
        #expect(world.clipPlayer.playedFiles.isEmpty)
        #expect(vm.badgeText == "0:24")
    }

    @Test func swipingToAnotherPhotoStopsTheClip() {
        let vm = make(recordedClip().id)
        vm.photoTapped()
        vm.swiped(.left)
        #expect(!world.clipPlayer.isPlaying)
        #expect(world.clipPlayer.openFile == nil)
        #expect(vm.photo?.id == "s1")
        #expect(vm.picture == .photo(1011))
    }

    @Test func leavingTheViewerStopsTheClip() {
        let back = make(recordedClip().id)
        back.photoTapped()
        back.backTapped()
        #expect(world.clipPlayer.openFile == nil)

        let edit = make("clip")
        edit.photoTapped()
        edit.perform(.edit)
        #expect(world.clipPlayer.openFile == nil)
    }

    @Test func aCollageIsNamedAsOneInsteadOfByACamera() {
        var collage = world.photo("collage")
        collage.isCollage = true
        world.photos.add(collage)
        #expect(make("collage").subtitle == "Collage")
    }

    @Test func backPopsToTheGallery() {
        make().backTapped()
        #expect(world.router.path == [.gallery])
    }

    @Test func actionsApplyToThePhotoOnScreenAfterPaging() {
        let vm = make()
        vm.swiped(.left)
        vm.perform(.edit)
        #expect(world.router.path == [.gallery, .viewer("s2"), .edit("s3")])
        world.router.back()
        vm.perform(.print)
        #expect(world.router.topRoute == .print("s3"))
        world.router.back()
        vm.perform(.collage)
        #expect(world.router.topRoute == .collage(seed: "s3"))
    }

    @Test func shareIsAPlaceholderToast() {
        make().perform(.share)
        #expect(world.toasts.current?.text == "Share sheet opens here")
        #expect(world.router.path == [.gallery, .viewer("s2")])
    }

    @Test func shareHandsThePhotoOnScreenToTheShareSheet() {
        let sheet = ShareSpy()
        let vm = make(sharing: sheet)
        vm.perform(.share)
        vm.swiped(.left)
        vm.perform(.share)
        #expect(sheet.sharedIDs == ["s2", "s3"])
        #expect(world.router.path == [.gallery, .viewer("s2")])
    }

    @Test func deleteGoesBackToTheGalleryAndUndoRestoresThePosition() {
        let vm = make()
        vm.perform(.delete)
        #expect(world.photos.photo(id: "s2") == nil)
        #expect(world.router.path == [.gallery])
        #expect(world.toasts.current?.text == "Photo deleted")
        #expect(world.toasts.current?.actionTitle == "Undo")

        world.toasts.performAction()
        #expect(world.photos.photos.prefix(3).map(\.id) == ["s1", "s2", "s3"])
    }

    @Test func stampUsesThePhotosDate() {
        #expect(make("s1").stamp?.date == "'26 10 11")
        #expect(make("s5").stamp?.date == "'26 10 10")
    }
}
