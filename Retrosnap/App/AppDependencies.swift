import Foundation

/// The composition root: every service, the router and the long-lived view models.
/// The app runs on the live services. Debug builds can also start from a launch scenario, which may swap
/// in the in-memory mocks; none of that is compiled into a release build.
final class AppDependencies {
    /// Everything that differs between a live launch and a mocked one.
    struct Services {
        let clock: any DateProviding
        let photos: any PhotoStoring
        let camera: any CameraServicing
        let permissions: any PermissionServicing
        let storage: any StorageMonitoring
        let settings: any SettingsStoring
        let location: any LocationProviding
        let exporter: any PhotoExporting
        let clipPlayer: any ClipPlaying
        let sharing: any PhotoSharing
        let printing: any PhotoPrinting
        /// Decodes the library's files for the screen; nil while the library is in memory.
        let imageLoader: PhotoImageLoader?
        /// The camera's frames for the viewfinder; nil while the camera shows a still scene.
        let viewfinder: FrameFeed?
        /// The frame the viewfinder showed as the shutter last fired; nil while the camera shows a still scene.
        let shotPreview: FrameFeed?
    }

    /// Starting states other than the ordinary ones, for the design's static boards. An ordinary launch has none.
    struct Boards {
        var camera = CameraViewModel.Preset()
        var isProcessing = false
        var tool = EditTool.effect
        var editPreset: PhotoAdjustments?
        var collageStep = 1
        var collagePicks: [Photo.ID] = []
    }

    let config: AppConfig
    let services: Services
    let scheduler: any Scheduling
    let saver: PhotosSaver
    let feedback: FeedbackCenter
    let router: AppRouter
    let toasts: ToastCenter
    let dayLabeler: DayLabeler
    let onboarding: OnboardingViewModel
    /// The camera is the permanent root, so its view model lives as long as the app.
    let cameraViewModel: CameraViewModel
    private let boards: Boards

    /// The app as it ships: live services, opening where the user left off.
    convenience init() {
        let scheduler = TaskScheduler()
        let toasts = ToastCenter(scheduler: scheduler)
        let services = Services.live(scheduler: scheduler, toasts: toasts)
        self.init(
            services: services, scheduler: scheduler, toasts: toasts,
            router: AppRouter(hasCompletedOnboarding: services.settings.hasCompletedOnboarding)
        )
    }

    init(
        services: Services,
        scheduler: any Scheduling,
        toasts: ToastCenter,
        router: AppRouter,
        config: AppConfig = AppConfig(),
        boards: Boards = Boards()
    ) {
        self.config = config
        self.services = services
        self.scheduler = scheduler
        self.toasts = toasts
        self.router = router
        self.boards = boards

        dayLabeler = DayLabeler(clock: services.clock)
        saver = PhotosSaver(
            exporter: services.exporter, permissions: services.permissions, settings: services.settings, toasts: toasts
        )
        feedback = FeedbackCenter(output: SystemFeedback(), settings: services.settings)
        onboarding = OnboardingViewModel(router: router, permissions: services.permissions, settings: services.settings)
        cameraViewModel = CameraViewModel(
            config: config, photos: services.photos, camera: services.camera, permissions: services.permissions,
            storage: services.storage, settings: services.settings, feedback: feedback, saver: saver,
            location: services.location, router: router, toasts: toasts, scheduler: scheduler, preset: boards.camera
        )
    }

    // MARK: Per-screen view models

    func makeResultViewModel(photoID: Photo.ID) -> ResultViewModel {
        ResultViewModel(
            photoID: photoID, photos: services.photos, saver: saver, sharing: services.sharing, router: router,
            toasts: toasts, scheduler: scheduler, dayLabeler: dayLabeler, isProcessing: boards.isProcessing
        )
    }

    func makeGalleryViewModel() -> GalleryViewModel {
        GalleryViewModel(photos: services.photos, router: router, dayLabeler: dayLabeler)
    }

    func makeViewerViewModel(photoID: Photo.ID) -> ViewerViewModel {
        ViewerViewModel(
            photoID: photoID, photos: services.photos, player: services.clipPlayer, sharing: services.sharing,
            router: router, toasts: toasts, dayLabeler: dayLabeler
        )
    }

    func makeEditViewModel(photoID: Photo.ID) -> EditViewModel {
        EditViewModel(
            photoID: photoID, photos: services.photos, router: router, toasts: toasts, dayLabeler: dayLabeler,
            tool: boards.tool, preset: boards.editPreset
        )
    }

    func makePrintViewModel(photoID: Photo.ID) -> PrintViewModel {
        PrintViewModel(
            photoID: photoID, photos: services.photos, printing: services.printing, router: router, toasts: toasts,
            feedback: feedback, dayLabeler: dayLabeler
        )
    }

    func makeCollageViewModel(seedID: Photo.ID?) -> CollageViewModel {
        CollageViewModel(
            seedID: seedID, photos: services.photos, exporter: services.exporter, saver: saver,
            sharing: services.sharing, router: router, toasts: toasts, feedback: feedback,
            startStep: boards.collageStep, boardPicks: boards.collagePicks
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settings: services.settings, storage: services.storage, location: services.location,
            permissions: services.permissions, saver: saver, links: config.links,
            openLink: { ExternalLink.open($0, completion: $1) }, router: router, toasts: toasts
        )
    }
}

extension AppDependencies.Services {
    /// The real thing: the library on disk, settings in the user defaults, the device's camera and iOS's own prompts.
    static func live(scheduler: any Scheduling, toasts: ToastCenter) -> AppDependencies.Services {
        let folder = PhotoLibraryFolder.standard
        let clock = SystemClock()
        let settings = UserDefaultsSettingsStore()
        let loader = PhotoImageLoader(folder: folder)
        let exporter = PhotoExporter(folder: folder, renderer: try? LookRenderer(), clock: clock)

        #if DEBUG && targetEnvironment(simulator)
        // The simulator has no camera: the still scene stands in for the sensor and is filed like a real shot.
        let camera = MockCameraService(clock: clock, library: folder)
        let viewfinder: FrameFeed? = nil
        let shotPreview: FrameFeed? = nil
        #else
        let camera = LiveCameraService(clock: clock, folder: folder, loader: loader)
        let viewfinder: FrameFeed? = camera.feed
        let shotPreview: FrameFeed? = camera.shotFeed
        #endif

        return AppDependencies.Services(
            clock: clock,
            photos: DiskPhotoStore(
                folder: folder, scheduler: scheduler, undoWindow: ToastCenter.displayDuration + .seconds(1)
            ),
            camera: camera,
            permissions: LivePermissionService(settings: settings),
            storage: LiveStorageMonitor(folder: folder),
            settings: settings,
            location: LiveLocationService(),
            exporter: exporter,
            clipPlayer: ClipPlayer(folder: folder),
            sharing: PhotoShareSheet(exporter: exporter, toasts: toasts),
            printing: AirPrinter(exporter: exporter, settings: settings),
            imageLoader: loader,
            viewfinder: viewfinder,
            shotPreview: shotPreview
        )
    }
}
