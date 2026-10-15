#if DEBUG
import Foundation

/// A picker that brings in the same picture every time, and at once.
final class MockPhotoImporter: PhotoImporting {
    let isImporting = false
    private let draft: Photo

    init(draft: Photo) {
        self.draft = draft
    }

    func pick(completion: @escaping @MainActor (ImportOutcome) -> Void) {
        completion(.imported(Photo(
            id: UUID().uuidString, image: draft.image, camera: draft.camera, capturedAt: draft.capturedAt,
            isJustCaptured: true, videoSeconds: draft.videoSeconds, videoFile: draft.videoFile, pixelSize: draft.pixelSize
        )))
    }

    func discard(_ draft: Photo) {}
}
#endif
