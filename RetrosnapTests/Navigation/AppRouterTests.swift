import Testing
@testable import Retrosnap

@MainActor
struct AppRouterTests {

    private func cameraRouter(_ path: [Route] = []) -> AppRouter {
        AppRouter(root: .camera, path: path)
    }

    // MARK: Onboarding

    @Test func startsAtWelcomeWithNothingOnTheStack() {
        let router = AppRouter()
        #expect(router.root == .onboarding(.welcome))
        #expect(router.path.isEmpty)
    }

    @Test func aLaunchBeforeOnboardingIsFinishedStartsAtWelcome() {
        let router = AppRouter(hasCompletedOnboarding: false)
        #expect(router.root == .onboarding(.welcome))
        #expect(router.path.isEmpty)
    }

    @Test func aLaunchAfterOnboardingOpensOnTheCamera() {
        let router = AppRouter(hasCompletedOnboarding: true)
        #expect(router.root == .camera)
        #expect(router.path.isEmpty)
    }

    @Test func onboardingAdvancesOneStepAtATimeAndStopsAtTheLast() {
        let router = AppRouter()
        router.advanceOnboarding()
        #expect(router.root == .onboarding(.howItWorks))
        router.advanceOnboarding()
        #expect(router.root == .onboarding(.cameraPermission))
        router.advanceOnboarding()
        #expect(router.root == .onboarding(.photosPermission))
        router.advanceOnboarding()
        #expect(router.root == .onboarding(.photosPermission))
    }

    @Test func finishingOnboardingLandsOnTheCameraWithAnEmptyStack() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        router.finishOnboarding()
        #expect(router.root == .camera)
        #expect(router.path.isEmpty)
    }

    @Test func nothingCanBePushedDuringOnboarding() {
        let router = AppRouter()
        router.push(.gallery)
        #expect(router.path.isEmpty)
        #expect(router.showResult("p1") == false)
        #expect(router.path.isEmpty)
    }

    @Test func advancingAfterOnboardingDoesNothing() {
        let router = cameraRouter()
        router.advanceOnboarding()
        #expect(router.root == .camera)
    }

    // MARK: Push and back

    @Test func pushAppends() {
        let router = cameraRouter()
        router.push(.gallery)
        router.push(.viewer("s1"))
        #expect(router.path == [.gallery, .viewer("s1")])
    }

    @Test func pushingTheScreenAlreadyOnTopIsIgnored() {
        let router = cameraRouter([.gallery])
        router.push(.gallery)
        #expect(router.path == [.gallery])
    }

    @Test func backDropsTheTopScreen() {
        let router = cameraRouter([.gallery, .viewer("s1"), .edit("s1")])
        router.back()
        #expect(router.path == [.gallery, .viewer("s1")])
    }

    @Test func backOnTheCameraDoesNothing() {
        let router = cameraRouter()
        router.back()
        #expect(router.path.isEmpty)
    }

    // MARK: Jumps

    @Test func returnToCameraClearsTheStack() {
        let router = cameraRouter([.gallery, .viewer("s1"), .print("s1")])
        router.returnToCamera()
        #expect(router.path.isEmpty)
    }

    @Test func returnToGalleryPopsBackToTheGalleryAlreadyOpen() {
        let router = cameraRouter([.gallery, .viewer("s1"), .collage(seed: "s1")])
        router.returnToGallery()
        #expect(router.path == [.gallery])
    }

    @Test func returnToGalleryOpensItWhenTheFlowStartedFromResult() {
        let router = cameraRouter([.result("p1"), .collage(seed: "p1")])
        router.returnToGallery()
        #expect(router.path == [.gallery])
    }

    @Test func returnToGalleryFromTheCameraOpensIt() {
        let router = cameraRouter()
        router.returnToGallery()
        #expect(router.path == [.gallery])
    }

    // MARK: Result hand-off after capture

    @Test func showResultOpensTheResultFromTheCamera() {
        let router = cameraRouter()
        #expect(router.showResult("p1"))
        #expect(router.path == [.result("p1")])
    }

    @Test func showResultIsDroppedOnceTheUserHasLeftTheCamera() {
        let router = cameraRouter([.gallery])
        #expect(router.showResult("p1") == false)
        #expect(router.path == [.gallery])
    }

    @Test func topRouteTracksTheStack() {
        let router = cameraRouter()
        #expect(router.topRoute == nil)
        router.push(.gallery)
        router.push(.settings)
        #expect(router.topRoute == .settings)
    }
}
