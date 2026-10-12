import Testing
@testable import Retrosnap

@MainActor
struct OnboardingViewModelTests {
    private let router: AppRouter
    private let permissions = MockPermissionService()
    private let viewModel: OnboardingViewModel

    init() {
        router = AppRouter()
        viewModel = OnboardingViewModel(router: router, permissions: permissions)
    }

    @Test func continueWalksWelcomeThenHowItWorksThenCameraPermission() {
        viewModel.continueTapped()
        #expect(router.root == .onboarding(.howItWorks))
        viewModel.continueTapped()
        #expect(router.root == .onboarding(.cameraPermission))
    }

    @Test func continueDoesNotSkipAPermissionStep() {
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions)
        viewModel.continueTapped()
        #expect(router.root == .onboarding(.cameraPermission))
    }

    @Test func allowCameraAsksForTheCameraAndMovesToPhotos() {
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions)
        viewModel.allowTapped()
        #expect(permissions.hasRequestedCameraAccess)
        #expect(router.root == .onboarding(.photosPermission))
        #expect(permissions.photoLibraryAccess == .notDetermined)
    }

    @Test func allowPhotosGrantsAccessAndOpensTheCamera() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions)
        viewModel.allowTapped()
        #expect(permissions.photoLibraryAccess == .granted)
        #expect(router.root == .camera)
        #expect(router.path.isEmpty)
    }

    @Test func notNowStillOpensTheCameraWithPhotosAccessOff() {
        let router = AppRouter(root: .onboarding(.photosPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions)
        viewModel.notNowTapped()
        #expect(permissions.photoLibraryAccess == .denied)
        #expect(router.root == .camera)
    }

    @Test func notNowIsOnlyOfferedForPhotos() {
        #expect(!viewModel.permission(for: .cameraPermission).offersNotNow)
        #expect(viewModel.permission(for: .photosPermission).offersNotNow)
    }

    @Test func notNowDoesNothingOnTheCameraStep() {
        let router = AppRouter(root: .onboarding(.cameraPermission))
        let viewModel = OnboardingViewModel(router: router, permissions: permissions)
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
