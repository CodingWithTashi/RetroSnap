import Testing
@testable import Retrosnap

@MainActor
struct EditViewModelTests {
    private let world = TestWorld(path: [.gallery, .viewer("s1"), .edit("s1")])

    private func make(_ id: Photo.ID = "s1", tool: EditTool = .effect, preset: PhotoAdjustments? = nil) -> EditViewModel {
        EditViewModel(
            photoID: id, photos: world.photos, router: world.router, toasts: world.toasts,
            dayLabeler: world.dayLabeler, tool: tool, preset: preset
        )
    }

    @Test func startsOnEffectWithThePhotosSavedEdits() {
        var saved = PhotoAdjustments.neutral
        saved.grain = 80
        world.photos.setAdjustments(saved, for: "s1")
        let vm = make()
        #expect(vm.tool == .effect)
        #expect(vm.draft == saved)
        #expect(vm.displayed == saved)
        #expect(vm.value == 100)
    }

    @Test func toolsAreTheFivePlainLanguageSliders() {
        #expect(EditTool.allCases.map(\.label) == ["Effect", "Grain", "Light", "Contrast", "Warmth"])
        #expect(EditTool.effect.range == 0...100)
        #expect(EditTool.grain.range == 0...100)
        #expect(EditTool.light.range == -50...50)
        #expect(EditTool.contrast.range == -50...50)
        #expect(EditTool.warmth.range == -50...50)
    }

    @Test func sliderChangesOnlyTheSelectedTool() {
        let vm = make()
        vm.select(.warmth)
        vm.sliderValue = 18
        #expect(vm.draft.warmth == 18)
        #expect(vm.draft.intensity == 100)
        vm.select(.grain)
        vm.sliderValue = 64
        #expect(vm.draft == PhotoAdjustments(intensity: 100, grain: 64, exposure: 0, contrast: 0, warmth: 18))
    }

    @Test func sliderRoundsAndStaysInRange() {
        let vm = make()
        vm.select(.light)
        vm.sliderValue = 12.6
        #expect(vm.value == 13)
        vm.sliderValue = 400
        #expect(vm.value == 50)
        vm.sliderValue = -400
        #expect(vm.value == -50)
        vm.select(.effect)
        vm.sliderValue = -5
        #expect(vm.value == 0)
    }

    @Test func valueTextShowsAPlusOnlyOnCentredSliders() {
        let vm = make()
        #expect(vm.valueText == "100")
        vm.select(.warmth)
        #expect(vm.valueText == "0")
        vm.sliderValue = 18
        #expect(vm.valueText == "+18")
        vm.sliderValue = -20
        #expect(vm.valueText == "-20")
    }

    @Test func holdingShowsTheOriginalWithoutLosingTheDraft() {
        let vm = make()
        vm.select(.warmth)
        vm.sliderValue = 30
        vm.compareBegan()
        #expect(vm.isComparing)
        #expect(vm.displayed == .original)
        #expect(vm.draft.warmth == 30)
        vm.compareEnded()
        #expect(!vm.isComparing)
        #expect(vm.displayed.warmth == 30)
    }

    @Test func resetReturnsEverySliderToItsDefault() {
        let vm = make(preset: PhotoAdjustments(intensity: 40, grain: 64, exposure: 5, contrast: -5, warmth: 18))
        vm.resetTapped()
        #expect(vm.draft == .neutral)
    }

    @Test func cancelDiscardsTheDraft() {
        let vm = make()
        vm.select(.grain)
        vm.sliderValue = 90
        vm.cancelTapped()
        #expect(world.photos.photo(id: "s1")?.adjustments == .neutral)
        #expect(world.router.path == [.gallery, .viewer("s1")])
        #expect(world.toasts.current == nil)
    }

    @Test func doneSavesTheDraftAndConfirms() {
        let vm = make()
        vm.select(.grain)
        vm.sliderValue = 90
        vm.doneTapped()
        #expect(world.photos.photo(id: "s1")?.adjustments.grain == 90)
        #expect(world.router.path == [.gallery, .viewer("s1")])
        #expect(world.toasts.current?.text == "Edits saved")
    }

    @Test func editBoardPresetOpensOnWarmth() {
        let vm = make(tool: .warmth, preset: PhotoAdjustments(intensity: 100, grain: 64, exposure: 0, contrast: 0, warmth: 18))
        #expect(vm.tool == .warmth)
        #expect(vm.valueText == "+18")
        #expect(vm.draft.grain == 64)
    }

    @Test func instantPhotosKeepTheirFrame() {
        #expect(make("s3").isInstant)
        #expect(!make().isInstant)
    }
}
