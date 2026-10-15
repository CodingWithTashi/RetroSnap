#if DEBUG
import Foundation
import Observation

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
#endif
