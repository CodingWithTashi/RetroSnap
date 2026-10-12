#if DEBUG
import Foundation

extension AppDependencies {
    #if targetEnvironment(simulator)
    private static let isSimulator = true
    #else
    private static let isSimulator = false
    #endif

    /// A debug launch. The scenario decides whether the services are live or mocked, where the app opens,
    /// and which of the design's static boards it is posed as.
    convenience init(scenario: LaunchScenario) {
        let scheduler = TaskScheduler()
        let toasts = ToastCenter(scheduler: scheduler)
        let boards = Boards(
            camera: CameraViewModel.Preset(
                isStripOpen: scenario.sheet,
                mode: scenario.variant == .videoMode ? .video : .photo,
                recordedSeconds: scenario.variant == .recording ? 12 : nil,
                isPosed: scenario.variant == .capture
            ),
            isProcessing: scenario.variant == .processing,
            tool: scenario.tool ?? .effect,
            editPreset: scenario.editPreset,
            collageStep: scenario.collageStep,
            collagePicks: SeedData.arrangeBoardPicks
        )

        guard scenario.runsLive(onSimulator: Self.isSimulator) else {
            let services = Services.mock(scenario, toasts: toasts)
            let navigation = scenario.navigation(firstPhotoID: services.photos.photos.first?.id)
            self.init(
                services: services, scheduler: scheduler, toasts: toasts,
                router: AppRouter(root: navigation.root, path: navigation.path), config: scenario.config, boards: boards
            )
            if scenario.variant == .saved {
                toasts.show("Saved to Photos")
            }
            return
        }

        if scenario.liveData == .fresh {
            Self.wipeLiveData()
        }
        let services = Services.live(scheduler: scheduler, toasts: toasts)
        let router: AppRouter
        if scenario.screen == nil {
            router = AppRouter(hasCompletedOnboarding: services.settings.hasCompletedOnboarding)
        } else {
            let navigation = scenario.navigation(firstPhotoID: services.photos.photos.first?.id)
            router = AppRouter(root: navigation.root, path: navigation.path)
        }
        self.init(
            services: services, scheduler: scheduler, toasts: toasts, router: router,
            config: scenario.config, boards: boards
        )
    }

    /// Forgets saved settings and photos, so a live launch starts as a first launch does.
    private static func wipeLiveData() {
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        try? FileManager.default.removeItem(at: PhotoLibraryFolder.standard.url)
    }
}

extension AppDependencies.Services {
    /// In-memory stand-ins, set up as the scenario asks: the prototype's 13 photos, a camera that sees a still
    /// scene, and permissions that are granted the moment they are asked for.
    static func mock(_ scenario: LaunchScenario, toasts: ToastCenter) -> AppDependencies.Services {
        let clock = FixedClock.design

        var seed = scenario.variant == .empty ? [] : SeedData.photos(clock: clock)
        if scenario.variant == .video, !seed.isEmpty {
            seed[0] = SeedData.sampleVideo(clock: clock)
        }

        let availability: CameraAvailability = switch scenario.variant {
        case .denied: .denied
        case .unavailable: .busy
        default: .ready
        }

        // A scenario that opens past onboarding behaves as if both prompts were answered.
        let startsInApp = scenario.navigation(firstPhotoID: nil).root == .camera
        let access: PhotoLibraryAccess = scenario.variant == .libDenied ? .denied : (startsInApp ? .granted : .notDetermined)

        let settings = InMemorySettingsStore()
        settings.lastCamera = scenario.camera ?? .film
        settings.hasSeenCameraIntro = startsInApp && !scenario.firstRun
        settings.hasTakenFirstPhoto = startsInApp

        return AppDependencies.Services(
            clock: clock,
            photos: MockPhotoStore(photos: seed),
            camera: MockCameraService(clock: clock, availability: availability),
            permissions: MockPermissionService(photoLibraryAccess: access),
            storage: MockStorageMonitor(isLow: scenario.variant == .lowStorage),
            settings: settings,
            location: MockLocationService(),
            exporter: MockPhotoExporter(),
            clipPlayer: MockClipPlayer(),
            sharing: MockPhotoSharer(toasts: toasts),
            printing: MockPhotoPrinter(),
            imageLoader: nil,
            viewfinder: nil,
            shotPreview: nil
        )
    }
}
#endif
