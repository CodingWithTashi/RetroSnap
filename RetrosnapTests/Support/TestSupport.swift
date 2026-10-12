import Foundation
@testable import Retrosnap

/// Records feedback instead of buzzing or clicking.
@MainActor
final class FeedbackSpy: FeedbackProviding {
    private(set) var haptics: [HapticKind] = []
    private(set) var clicks = 0
    private(set) var hapticPrepareCount = 0
    private(set) var clickPrepareCount = 0

    func prepareHaptics() {
        hapticPrepareCount += 1
    }

    func prepareClick() {
        clickPrepareCount += 1
    }

    func haptic(_ kind: HapticKind) {
        haptics.append(kind)
    }

    func shutterClick() {
        clicks += 1
    }
}

/// A fully mocked app for view-model tests: virtual time, in-memory services, a camera router.
@MainActor
struct TestWorld {
    let scheduler = ManualScheduler()
    let clock = FixedClock.design
    let photos: MockPhotoStore
    let camera: MockCameraService
    /// Photos access is already given, as for someone who finished onboarding with "Allow Photos".
    let permissions = MockPermissionService(photoLibraryAccess: .granted)
    let storage = MockStorageMonitor()
    let settings = InMemorySettingsStore()
    let feedbackSpy = FeedbackSpy()
    let feedback: FeedbackCenter
    let exporter = MockPhotoExporter()
    let location = MockLocationService()
    let clipPlayer = ClipPlayerSpy()
    let printing = MockPhotoPrinter()
    let saver: PhotosSaver
    let router: AppRouter
    let toasts: ToastCenter
    /// Stands in for the system share sheet by naming it, as the prototype does.
    let sharing: MockPhotoSharer

    init(photos seed: [Photo]? = nil, path: [Route] = []) {
        photos = MockPhotoStore(photos: seed ?? SeedData.photos(clock: clock))
        camera = MockCameraService(clock: clock)
        feedback = FeedbackCenter(output: feedbackSpy, settings: settings)
        router = AppRouter(root: .camera, path: path)
        toasts = ToastCenter(scheduler: scheduler)
        saver = PhotosSaver(exporter: exporter, permissions: permissions, settings: settings, toasts: toasts)
        sharing = MockPhotoSharer(toasts: toasts)
    }

    func photo(_ id: String, camera: CameraStyle = .film, video seconds: Int? = nil) -> Photo {
        Photo(id: id, image: .photo(1011), camera: camera, capturedAt: clock.now, videoSeconds: seconds)
    }
}
