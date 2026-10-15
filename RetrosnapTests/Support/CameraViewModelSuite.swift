@testable import Retrosnap

/// What the camera view model's suites share: a world to build the view model in, and the two ways to build it.
@MainActor
protocol CameraViewModelSuite {
    var world: TestWorld { get }
}

extension CameraViewModelSuite {
    /// A camera in `world`, or in `other` where a test needs a world of its own.
    func make(
        in other: TestWorld? = nil, config: AppConfig = AppConfig(), preset: CameraViewModel.Preset = .init(),
        camera: (any CameraServicing)? = nil, permissions: (any PermissionServicing)? = nil,
        location: (any LocationProviding)? = nil, storage: (any StorageMonitoring)? = nil
    ) -> CameraViewModel {
        let w = other ?? world
        return CameraViewModel(
            config: config, photos: w.photos, camera: camera ?? w.camera,
            permissions: permissions ?? w.permissions,
            storage: storage ?? w.storage, settings: w.settings, feedback: w.feedback, saver: w.saver,
            location: location ?? w.location,
            router: w.router, toasts: w.toasts, scheduler: w.scheduler, preset: preset
        )
    }

    /// A camera for someone who has been here before: no first-run strip, first photo already taken.
    func returning(
        config: AppConfig = AppConfig(), preset: CameraViewModel.Preset = .init(),
        camera: (any CameraServicing)? = nil, permissions: (any PermissionServicing)? = nil,
        location: (any LocationProviding)? = nil, storage: (any StorageMonitoring)? = nil
    ) -> CameraViewModel {
        world.settings.hasSeenCameraIntro = true
        world.settings.hasTakenFirstPhoto = true
        return make(
            config: config, preset: preset, camera: camera, permissions: permissions, location: location,
            storage: storage
        )
    }
}
