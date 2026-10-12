import Testing
@testable import Retrosnap

@MainActor
struct ViewerViewModelTests {
    private let world = TestWorld(path: [.gallery, .viewer("s2")])

    private func make(_ id: Photo.ID = "s2") -> ViewerViewModel {
        ViewerViewModel(
            photoID: id, photos: world.photos, router: world.router, toasts: world.toasts,
            dayLabeler: DayLabeler(clock: world.clock)
        )
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
