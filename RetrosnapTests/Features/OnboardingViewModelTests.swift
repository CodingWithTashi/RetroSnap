import Testing
@testable import Retrosnap

@MainActor
struct OnboardingViewModelTests {
    private let router: AppRouter
    private let permissions = MockPermissionService()
    private let settings = InMemorySettingsStore()
    private let viewModel: OnboardingViewModel

    init() {
        router = AppRouter()
        viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
    }

    @Test func theCameraStepCountsTheLineup() {
        #expect(CameraStyle.allCases.count == 13)
        #expect(viewModel.chooseCameraDetail == "13 looks. One tap to switch.")
    }

    @Test func continueWalksWelcomeThenHowItWorksThenCameraPermission() {
        viewModel.continueTapped()
        #expect(router.root == .onboarding(.howItWorks))
        viewModel.continueTapped()
        #expect(router.root == .onboarding(.cameraPermission))
    }

    @Test func continueDoesNotSkipAPermissionStep() {
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.continueTapped()
        #expect(router.root == .onboarding(.cameraPermission))
    }

    @Test func allowCameraAsksForTheCameraAndMovesToPhotos() {
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.allowTapped()
        #expect(permissions.hasRequestedCameraAccess)
        #expect(router.root == .onboarding(.photosPermission))
        #expect(permissions.photoLibraryAccess == .notDetermined)
    }

    @Test func allowPhotosGrantsAccessAndOpensTheCamera() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.allowTapped()
        #expect(permissions.photoLibraryAccess == .granted)
        #expect(router.root == .camera)
        #expect(router.path.isEmpty)
    }

    @Test func notNowStillOpensTheCameraWithPhotosAccessOff() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.notNowTapped()
        #expect(permissions.photoLibraryAccess == .denied)
        #expect(router.root == .camera)
    }

    @Test func onboardingIsNotFinishedUntilThePhotosStepIsAnswered() {
        viewModel.continueTapped()
        viewModel.continueTapped()
        viewModel.allowTapped()
        #expect(router.root == .onboarding(.photosPermission))
        #expect(!settings.hasCompletedOnboarding)
    }

    @Test func allowingPhotosFinishesOnboardingForGood() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.allowTapped()
        #expect(settings.hasCompletedOnboarding)
    }

    @Test func notNowFinishesOnboardingForGoodToo() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.notNowTapped()
        #expect(settings.hasCompletedOnboarding)
    }

    // MARK: Real prompts take time

    @Test func thePhotosScreenWaitsForTheCameraPromptToBeAnswered() {
        let spy = PermissionSpy()
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: spy, settings: settings)
        viewModel.allowTapped()
        #expect(spy.cameraRequestCount == 1)
        #expect(router.root == .onboarding(.cameraPermission))

        spy.answerCameraPrompt()
        #expect(router.root == .onboarding(.photosPermission))
    }

    @Test func aSecondTapWhileThePromptIsUpAsksNothingMore() {
        let spy = PermissionSpy()
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: spy, settings: settings)
        viewModel.allowTapped()
        viewModel.allowTapped()
        #expect(spy.cameraRequestCount == 1)

        spy.answerCameraPrompt()
        #expect(router.root == .onboarding(.photosPermission))
        #expect(spy.photoLibraryRequestCount == 0)
    }

    @Test func theCameraOpensOnceThePhotosPromptIsAnswered() {
        let spy = PermissionSpy()
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: spy, settings: settings)
        viewModel.allowTapped()
        #expect(spy.photoLibraryRequestCount == 1)
        #expect(router.root == .onboarding(.photosPermission))
        #expect(!settings.hasCompletedOnboarding)

        spy.answerPhotoLibraryPrompt(.denied)
        #expect(router.root == .camera)
        #expect(settings.hasCompletedOnboarding)
    }

    @Test func notNowIsIgnoredWhileThePhotosPromptIsUp() {
        let spy = PermissionSpy()
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: spy, settings: settings)
        viewModel.allowTapped()
        viewModel.notNowTapped()
        #expect(router.root == .onboarding(.photosPermission))
        #expect(spy.photoLibraryAccess == .notDetermined)
    }

    @Test func notNowIsOnlyOfferedForPhotos() {
        #expect(!viewModel.permission(for: .cameraPermission).offersNotNow)
        #expect(viewModel.permission(for: .photosPermission).offersNotNow)
    }

    @Test func notNowDoesNothingOnTheCameraStep() {
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions, settings: settings)
        viewModel.notNowTapped()
        #expect(router.root == .onboarding(.cameraPermission))
        #expect(permissions.photoLibraryAccess == .notDetermined)
    }

    @Test func permissionCopyMatchesTheDesign() {
        let camera = viewModel.permission(for: .cameraPermission)
        #expect(camera.title == "Allow camera access")
        #expect(camera.message == "RetroSnap uses your camera\nto show the vintage look live\nand take your photos.")
        #expect(camera.actionTitle == "Allow Camera")
        #expect(camera.icon == .camera)

        let photos = viewModel.permission(for: .photosPermission)
        #expect(photos.title == "Save to your photos")
        #expect(photos.message == "Every shot is saved to your photo\nlibrary automatically. Nothing\nis ever uploaded.")
        #expect(photos.actionTitle == "Allow Photos")
        #expect(photos.icon == .photos)
    }
}
