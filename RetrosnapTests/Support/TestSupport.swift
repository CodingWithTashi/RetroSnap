import Foundation
@testable import Retrosnap

/// Records feedback instead of buzzing or clicking.
@MainActor
final class FeedbackSpy: FeedbackProviding {
    private(set) var haptics: [HapticKind] = []
    private(set) var clicks = 0

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
    let permissions = MockPermissionService()
    let storage = MockStorageMonitor()
    let settings = InMemorySettingsStore()
    let feedbackSpy = FeedbackSpy()
    let feedback: FeedbackCenter
    let router: AppRouter
    let toasts: ToastCenter

    init(photos seed: [Photo]? = nil, path: [Route] = []) {
        photos = MockPhotoStore(photos: seed ?? SeedData.photos(clock: clock))
        camera = MockCameraService(clock: clock)
        feedback = FeedbackCenter(output: feedbackSpy, settings: settings)
        router = AppRouter(root: .camera, path: path)
        toasts = ToastCenter(scheduler: scheduler)
    }

    func photo(_ id: String, camera: CameraStyle = .film, video seconds: Int? = nil) -> Photo {
        Photo(id: id, image: .photo(1011), camera: camera, capturedAt: clock.now, videoSeconds: seconds)
    }
}
