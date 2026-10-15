#if DEBUG
import Foundation
import Observation

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
#endif
