import Testing
@testable import Retrosnap

@MainActor
struct LaunchScenarioTests {

    private func scenario(_ arguments: String...) -> LaunchScenario {
        LaunchScenario(arguments: ["Retrosnap"] + arguments)
    }

    @Test func noArgumentsMeansAnOrdinaryLaunch() {
        let s = scenario()
        #expect(s == LaunchScenario())
        #expect(s.screen == nil)
        #expect(s.selector == .strip)
        #expect(s.reviewRule == .first)
        #expect(!s.isReturningUser)
    }

    @Test func readsScreenVariantAndCamera() {
        let s = scenario("-rsScreen", "gallery", "-rsVariant", "empty", "-rsCamera", "inst")
        #expect(s.screen == .gallery)
        #expect(s.variant == .empty)
        #expect(s.camera == .instant)
    }

    @Test func unknownValuesAreIgnored() {
        let s = scenario("-rsScreen", "nonsense", "-rsVariant", "??", "-rsCamera", "pinhole")
        #expect(s.screen == nil)
        #expect(s.variant == nil)
        #expect(s.camera == nil)
    }

    @Test func aFlagWithoutAValueIsIgnored() {
        #expect(scenario("-rsScreen").screen == nil)
    }

    @Test func readsThePrototypeTweaks() {
        let s = scenario("-rsSelector", "carousel", "-rsAfterCapture", "always")
        #expect(s.selector == .carousel)
        #expect(s.reviewRule == .always)
    }

    @Test func readsCameraBoardOptions() {
        let s = scenario("-rsScreen", "camera", "-rsFirstRun", "1", "-rsSheet", "1")
        #expect(s.firstRun)
        #expect(s.sheet)
    }

    @Test func readsEditAndCollageBoardOptions() {
        let s = scenario("-rsTool", "warmth", "-rsEdit", "warmth=18,grain=64", "-rsCollageStep", "3")
        #expect(s.tool == .warmth)
        #expect(s.editPreset == PhotoAdjustments(intensity: 100, grain: 64, exposure: 0, contrast: 0, warmth: 18))
        #expect(s.collageStep == 3)
    }

    @Test func collageStepIsClampedToTheThreeSteps() {
        #expect(scenario("-rsCollageStep", "9").collageStep == 3)
        #expect(scenario("-rsCollageStep", "0").collageStep == 1)
    }

    @Test func returningUserSkipsOnboarding() {
        let s = scenario("-rsScenario", "returning")
        #expect(s.isReturningUser)
        let navigation = s.navigation(firstPhotoID: "s1")
        #expect(navigation.root == .camera)
        #expect(navigation.path.isEmpty)
    }

    @Test func ordinaryLaunchStartsOnboarding() {
        let navigation = scenario().navigation(firstPhotoID: "s1")
        #expect(navigation.root == .onboarding(.welcome))
        #expect(navigation.path.isEmpty)
    }

    @Test(arguments: [
        ("welcome", AppRouter.Root.onboarding(.welcome)),
        ("how", .onboarding(.howItWorks)),
        ("permCam", .onboarding(.cameraPermission)),
        ("permLib", .onboarding(.photosPermission)),
    ])
    func onboardingScreensOpenAtTheirStep(name: String, root: AppRouter.Root) {
        let navigation = scenario("-rsScreen", name).navigation(firstPhotoID: "s1")
        #expect(navigation.root == root)
        #expect(navigation.path.isEmpty)
    }

    @Test(arguments: [
        ("camera", [Route]()),
        ("carousel", [.cameraCarousel]),
        ("result", [.result("s1")]),
        ("gallery", [.gallery]),
        ("viewer", [.gallery, .viewer("s1")]),
        ("edit", [.gallery, .viewer("s1"), .edit("s1")]),
        ("print", [.gallery, .viewer("s1"), .print("s1")]),
        ("collage", [.gallery, .viewer("s1"), .collage(seed: "s1")]),
        ("settings", [.gallery, .settings]),
    ])
    func appScreensOpenOnTopOfTheCamera(name: String, path: [Route]) {
        let navigation = scenario("-rsScreen", name).navigation(firstPhotoID: "s1")
        #expect(navigation.root == .camera)
        #expect(navigation.path == path)
    }

    @Test func aChosenPhotoIsUsedInsteadOfTheFirst() {
        let navigation = scenario("-rsScreen", "viewer", "-rsPhoto", "s3").navigation(firstPhotoID: "s1")
        #expect(navigation.path == [.gallery, .viewer("s3")])
    }

    @Test func photoScreensFallBackToTheGalleryWhenThereAreNoPhotos() {
        let navigation = scenario("-rsScreen", "viewer").navigation(firstPhotoID: nil)
        #expect(navigation.path == [.gallery])
    }
}
