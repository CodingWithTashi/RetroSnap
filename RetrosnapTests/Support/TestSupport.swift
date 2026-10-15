import Foundation
@testable import Retrosnap

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
    let importer = ImporterSpy()
    let saver: PhotosSaver
    let dayLabeler: DayLabeler
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
        dayLabeler = DayLabeler(clock: clock)
    }

    func photo(_ id: String, camera: CameraStyle = .film, video seconds: Int? = nil) -> Photo {
        Photo.fixture(id, camera: camera, at: clock.now, video: seconds)
    }

    /// A saver on this world's services, with Photos access as given and this world's exporter unless another is.
    func makeSaver(access: PhotoLibraryAccess, exporter: (any PhotoExporting)? = nil) -> PhotosSaver {
        PhotosSaver(
            exporter: exporter ?? self.exporter, permissions: MockPermissionService(photoLibraryAccess: access),
            settings: settings, toasts: toasts
        )
    }

    /// A pick from the library as the importer hands it over: filed, not yet in the library, on no camera in particular.
    func draft(_ id: String, camera: CameraStyle = .film, video seconds: Int? = nil) -> Photo {
        Photo(
            id: id, image: .photo(1015), camera: camera, capturedAt: clock.now, isJustCaptured: true,
            videoSeconds: seconds, videoFile: seconds == nil ? nil : "\(id).mov"
        )
    }
}
