import Foundation

/// The composition root: every service, the router and the long-lived view models.
/// In v1 all services are in-memory mocks; a launch scenario decides how they start.
final class AppDependencies {
    let scenario: LaunchScenario
    let config: AppConfig
    let clock: any DateProviding
    let scheduler: any Scheduling
    let photos: any PhotoStoring
    let camera: any CameraServicing
    let permissions: any PermissionServicing
    let storage: any StorageMonitoring
    let settings: any SettingsStoring
    let feedback: FeedbackCenter
    let router: AppRouter
    let toasts: ToastCenter
    let dayLabeler: DayLabeler
    let onboarding: OnboardingViewModel
    /// The camera is the permanent root, so its view model lives as long as the app.
    let cameraViewModel: CameraViewModel

    init(scenario: LaunchScenario = LaunchScenario()) {
        self.scenario = scenario
        config = scenario.config

        let clock = FixedClock.design
        self.clock = clock
        dayLabeler = DayLabeler(clock: clock)
        scheduler = TaskScheduler()

        var seed = scenario.variant == .empty ? [] : SeedData.photos(clock: clock)
        if scenario.variant == .video, !seed.isEmpty {
            seed[0] = SeedData.sampleVideo(clock: clock)
        }
        let photos = MockPhotoStore(photos: seed)
        self.photos = photos

        let availability: CameraAvailability = switch scenario.variant {
        case .denied: .denied
        case .unavailable: .busy
        default: .ready
        }
        camera = MockCameraService(clock: clock, availability: availability)

        // A scenario that opens past onboarding behaves as if both prompts were answered.
        let startsInApp = scenario.navigation(firstPhotoID: nil).root == .camera
        let access: PhotoLibraryAccess = scenario.variant == .libDenied ? .denied : (startsInApp ? .granted : .notDetermined)
        permissions = MockPermissionService(photoLibraryAccess: access)
        storage = MockStorageMonitor(isLow: scenario.variant == .lowStorage)

        let settings = InMemorySettingsStore()
        settings.lastCamera = scenario.camera ?? .film
        settings.hasSeenCameraIntro = startsInApp && !scenario.firstRun
        settings.hasTakenFirstPhoto = startsInApp
        self.settings = settings

        feedback = FeedbackCenter(output: SystemFeedback(), settings: settings)

        let navigation = scenario.navigation(firstPhotoID: photos.photos.first?.id)
        router = AppRouter(root: navigation.root, path: navigation.path)
        toasts = ToastCenter(scheduler: scheduler)
        onboarding = OnboardingViewModel(router: router, permissions: permissions)
        cameraViewModel = CameraViewModel(
            config: config, photos: photos, camera: camera, permissions: permissions, storage: storage,
            settings: settings, feedback: feedback, router: router, toasts: toasts, scheduler: scheduler,
            preset: CameraViewModel.Preset(
                isStripOpen: scenario.sheet,
                mode: scenario.variant == .videoMode ? .video : .photo,
                recordedSeconds: scenario.variant == .recording ? 12 : nil,
                isPosed: scenario.variant == .capture
            )
        )
        if scenario.variant == .saved {
            toasts.show("Saved to Photos")
        }
    }

    // MARK: Per-screen view models

    func makeResultViewModel(photoID: Photo.ID) -> ResultViewModel {
        ResultViewModel(
            photoID: photoID, photos: photos, router: router, toasts: toasts, scheduler: scheduler,
            dayLabeler: dayLabeler, isProcessing: scenario.variant == .processing
        )
    }

    func makeGalleryViewModel() -> GalleryViewModel {
        GalleryViewModel(photos: photos, router: router, dayLabeler: dayLabeler)
    }

    func makeViewerViewModel(photoID: Photo.ID) -> ViewerViewModel {
        ViewerViewModel(photoID: photoID, photos: photos, router: router, toasts: toasts, dayLabeler: dayLabeler)
    }

    func makeEditViewModel(photoID: Photo.ID) -> EditViewModel {
        EditViewModel(
            photoID: photoID, photos: photos, router: router, toasts: toasts, dayLabeler: dayLabeler,
            tool: scenario.tool ?? .effect, preset: scenario.editPreset
        )
    }

    func makePrintViewModel(photoID: Photo.ID) -> PrintViewModel {
        PrintViewModel(
            photoID: photoID, photos: photos, router: router, toasts: toasts, feedback: feedback, dayLabeler: dayLabeler
        )
    }

    func makeCollageViewModel(seedID: Photo.ID?) -> CollageViewModel {
        CollageViewModel(
            seedID: seedID, photos: photos, router: router, toasts: toasts, feedback: feedback,
            startStep: scenario.collageStep
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(settings: settings, storage: storage, router: router, toasts: toasts)
    }
}
