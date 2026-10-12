#if DEBUG
import Foundation
import Observation
import UIKit

/// In-memory photo library.
@Observable
final class MockPhotoStore: PhotoStoring {
    private var list: PhotoList

    init(photos: [Photo]) {
        list = PhotoList(photos)
    }

    var photos: [Photo] {
        list.photos
    }

    func photo(id: Photo.ID) -> Photo? {
        list.photo(id: id)
    }

    func add(_ photo: Photo) {
        list.add(photo)
    }

    @discardableResult
    func delete(id: Photo.ID) -> DeletedPhoto? {
        list.delete(id: id)
    }

    func restore(_ deleted: DeletedPhoto) {
        list.restore(deleted)
    }

    func setAdjustments(_ adjustments: PhotoAdjustments, for id: Photo.ID) {
        list.setAdjustments(adjustments, for: id)
    }
}

/// A camera that "sees" one still scene per lens and delivers its shots at once.
/// Given a library folder, it files each shot there as a real picture, the way the device camera does.
@Observable
final class MockCameraService: CameraServicing {
    private(set) var availability: CameraAvailability
    let playsSystemShutterSound = false
    /// A still scene is swapped for the other at once.
    let isSwitching = false
    /// One lens, like the phone the simulator stands in for.
    private(set) var zoom = CameraZoom(factor: 1, range: 1...5, stops: [1, 2])

    @ObservationIgnored private let clock: any DateProviding
    @ObservationIgnored private let library: PhotoLibraryFolder?
    @ObservationIgnored private var facing = CameraFacing.back
    /// What the clip being recorded was started with.
    @ObservationIgnored private var recording: Shot?

    init(clock: any DateProviding, availability: CameraAvailability = .ready, library: PhotoLibraryFolder? = nil) {
        self.clock = clock
        self.availability = availability
        self.library = library
    }

    func scene(for facing: CameraFacing) -> PhotoImage {
        facing == .back ? .sceneBack : .sceneFront
    }

    func start(facing: CameraFacing, mode: CaptureMode) {
        guard facing != self.facing else { return }
        self.facing = facing
        zoom.factor = 1
    }

    func stop() {}

    func setZoom(_ factor: Double, smoothly: Bool) {
        zoom.factor = zoom.clamped(factor)
    }

    func capturePhoto(_ shot: Shot, completion: @escaping @MainActor (Photo?) -> Void) {
        var photo = capturePhoto(style: shot.style, facing: shot.facing)
        photo.location = shot.location
        completion(photo)
    }

    func startRecording(_ shot: Shot) {
        recording = shot
    }

    func finishRecording(seconds: Int, completion: @escaping @MainActor (Photo?) -> Void) {
        guard let shot = recording else {
            completion(nil)
            return
        }
        recording = nil
        var clip = finishRecording(seconds: seconds, style: shot.style, facing: shot.facing)
        clip.location = shot.location
        completion(clip)
    }

    func recover(completion: @escaping @MainActor () -> Void) {
        availability = .ready
        completion()
    }

    /// The photo this camera takes, without waiting.
    func capturePhoto(style: CameraStyle, facing: CameraFacing) -> Photo {
        let id = UUID().uuidString
        return Photo(id: id, image: shot(of: facing, id: id), camera: style, capturedAt: clock.now, isJustCaptured: true)
    }

    /// The clip this camera records, without waiting.
    func finishRecording(seconds: Int, style: CameraStyle, facing: CameraFacing) -> Photo {
        Photo(
            id: UUID().uuidString, image: scene(for: facing), camera: style, capturedAt: clock.now,
            isJustCaptured: true, videoSeconds: seconds
        )
    }

    /// The scene itself, or a copy of it filed in the library when there is one.
    private func shot(of facing: CameraFacing, id: Photo.ID) -> PhotoImage {
        let scene = scene(for: facing)
        guard let library, case .sample(let sample) = scene,
              let original = UIImage(named: sample.full)?.jpegData(compressionQuality: 0.95),
              let filed = try? library.store(original: original, id: id, fileExtension: "jpg")
        else { return scene }
        return filed
    }
}

/// A player with nothing to play: the mock library's clips are stills.
final class MockClipPlayer: ClipPlaying {
    let frames = FrameFeed()
    let openFile: String? = nil
    let isPlaying = false

    func play(_ videoFile: String) {}

    func pause() {}

    func stop() {}
}

/// An exporter that only remembers what it was asked to save.
@Observable
final class MockPhotoExporter: PhotoExporting {
    private(set) var savedIDs: [Photo.ID] = []
    var progress: [Photo.ID: Double] = [:]

    func saveToPhotos(_ photo: Photo, completion: @escaping @MainActor (Bool) -> Void) {
        savedIDs.append(photo.id)
        completion(true)
    }

    func export(_ photo: Photo, completion: @escaping @MainActor (URL?) -> Void) {
        completion(nil)
    }

    func exportPrint(_ job: PrintJob, completion: @escaping @MainActor (URL?) -> Void) {
        completion(nil)
    }

    /// The first photo stands in for the finished collage.
    func makeCollage(_ collage: Collage, completion: @escaping @MainActor (Photo?) -> Void) {
        guard let first = collage.photos.first else {
            completion(nil)
            return
        }
        completion(Photo(
            id: UUID().uuidString, image: first.image, camera: first.camera,
            capturedAt: collage.photos.map(\.capturedAt).max() ?? first.capturedAt,
            adjustments: .original, isCollage: true
        ))
    }

    func exportCollage(_ collage: Collage, completion: @escaping @MainActor (URL?) -> Void) {
        completion(nil)
    }
}

/// The prototype's printer: always there, and every job reaches it at once.
final class MockPhotoPrinter: PhotoPrinting {
    let printerName: String? = "Living Room Printer"
    let paperName = "Glossy photo"

    func print(_ job: PrintJob, completion: @escaping @MainActor (PrintOutcome) -> Void) {
        completion(.sent)
    }

    func choosePrinter() {}
}

/// Stands in for the system share sheet by naming it, as the prototype does.
final class MockPhotoSharer: PhotoSharing {
    private let toasts: ToastCenter

    init(toasts: ToastCenter) {
        self.toasts = toasts
    }

    func share(_ photo: Photo) {
        toasts.show("Share sheet opens here")
    }

    func share(_ collage: Collage) {
        toasts.show("Share sheet opens here")
    }
}

/// Permissions that are granted the moment they are asked for.
@Observable
final class MockPermissionService: PermissionServicing {
    private(set) var photoLibraryAccess: PhotoLibraryAccess
    private(set) var hasRequestedCameraAccess = false

    init(photoLibraryAccess: PhotoLibraryAccess = .notDetermined) {
        self.photoLibraryAccess = photoLibraryAccess
    }

    func requestCameraAccess(completion: @escaping @MainActor () -> Void) {
        hasRequestedCameraAccess = true
        completion()
    }

    func requestPhotoLibraryAccess(completion: @escaping @MainActor () -> Void) {
        photoLibraryAccess = .granted
        completion()
    }

    func declinePhotoLibraryAccess() {
        photoLibraryAccess = .denied
    }

    func requestMicrophoneAccess(completion: @escaping @MainActor () -> Void) {
        completion()
    }

    func refresh() {}

    func openSettings() {}
}

/// Location that is allowed as soon as it is asked for and never has a fix.
@Observable
final class MockLocationService: LocationProviding {
    private(set) var isAllowed = false
    let current: PhotoLocation? = nil

    func requestAccess(completion: @escaping @MainActor (Bool) -> Void) {
        isAllowed = true
        completion(true)
    }

    func start() {}

    func stop() {}
}

@Observable
final class MockStorageMonitor: StorageMonitoring {
    var isLow: Bool
    let photosLeft = 40
    let usedText = "1.2 GB"

    init(isLow: Bool = false) {
        self.isLow = isLow
    }

    func refresh() {}
}

/// Settings that last for one launch.
@Observable
final class InMemorySettingsStore: SettingsStoring {
    var saveToPhotos = true
    var locationOnPhotos = false
    var shutterSound = true
    var haptics = true
    let videoQuality = "1080p"
    let versionText = "Version 1.0"
    var printer: SavedPrinter?
    var lastCamera = CameraStyle.film
    var flash = FlashMode.auto
    var isTimerOn = false
    var hasCompletedOnboarding = false
    var hasDeclinedPhotoLibrary = false
    var hasSeenCameraIntro = false
    var hasTakenFirstPhoto = false
}
#endif
