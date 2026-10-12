import Foundation
import Observation

/// In-memory photo library.
@Observable
final class MockPhotoStore: PhotoStoring {
    private(set) var photos: [Photo]

    init(photos: [Photo]) {
        self.photos = photos
    }

    func photo(id: Photo.ID) -> Photo? {
        photos.first { $0.id == id }
    }

    func add(_ photo: Photo) {
        photos.insert(photo, at: 0)
    }

    @discardableResult
    func delete(id: Photo.ID) -> DeletedPhoto? {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
        let photo = photos.remove(at: index)
        let olderNeighbor = index < photos.count ? photos[index].id : nil
        return DeletedPhoto(photo: photo, index: index, olderNeighborID: olderNeighbor)
    }

    func restore(_ deleted: DeletedPhoto) {
        guard !photos.contains(where: { $0.id == deleted.photo.id }) else { return }
        let neighborIndex = deleted.olderNeighborID.flatMap { id in photos.firstIndex { $0.id == id } }
        let fallback = deleted.olderNeighborID == nil ? photos.count : min(deleted.index, photos.count)
        photos.insert(deleted.photo, at: neighborIndex ?? fallback)
    }

    func setAdjustments(_ adjustments: PhotoAdjustments, for id: Photo.ID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].adjustments = adjustments
    }
}

/// A camera that "sees" one still scene per lens.
@Observable
final class MockCameraService: CameraServicing {
    private(set) var availability: CameraAvailability

    @ObservationIgnored private let clock: any DateProviding
    @ObservationIgnored private var shotCount = 0

    init(clock: any DateProviding, availability: CameraAvailability = .ready) {
        self.clock = clock
        self.availability = availability
    }

    func scene(for facing: CameraFacing) -> SampleImage {
        facing == .back ? .sceneBack : .sceneFront
    }

    func capturePhoto(style: CameraStyle, facing: CameraFacing) -> Photo {
        shotCount += 1
        return Photo(id: "p\(shotCount)", image: scene(for: facing), camera: style, capturedAt: clock.now, isJustCaptured: true)
    }

    func finishRecording(seconds: Int, style: CameraStyle, facing: CameraFacing) -> Photo {
        shotCount += 1
        return Photo(
            id: "v\(shotCount)", image: scene(for: facing), camera: style, capturedAt: clock.now,
            isJustCaptured: true, videoSeconds: seconds
        )
    }

    func recover() {
        availability = .ready
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

    func requestCameraAccess() {
        hasRequestedCameraAccess = true
    }

    func requestPhotoLibraryAccess() {
        photoLibraryAccess = .granted
    }

    func declinePhotoLibraryAccess() {
        photoLibraryAccess = .denied
    }
}

@Observable
final class MockStorageMonitor: StorageMonitoring {
    var isLow: Bool
    let photosLeft = 40
    let usedText = "1.2 GB"

    init(isLow: Bool = false) {
        self.isLow = isLow
    }
}

/// Settings that last for one launch.
@Observable
final class InMemorySettingsStore: SettingsStoring {
    var saveToPhotos = true
    var shutterSound = true
    var haptics = true
    let videoQuality = "1080p"
    let versionText = "Version 1.0"
    var lastCamera = CameraStyle.film
    var hasSeenCameraIntro = false
    var hasTakenFirstPhoto = false
}
