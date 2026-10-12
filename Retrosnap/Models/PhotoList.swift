import Foundation

/// The library's order, shared by every store: newest first, and Undo puts a photo back where it was.
nonisolated struct PhotoList: Hashable, Sendable {
    private(set) var photos: [Photo]

    init(_ photos: [Photo] = []) {
        self.photos = photos
    }

    func photo(id: Photo.ID) -> Photo? {
        photos.first { $0.id == id }
    }

    mutating func add(_ photo: Photo) {
        photos.insert(photo, at: 0)
    }

    mutating func delete(id: Photo.ID) -> DeletedPhoto? {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
        let photo = photos.remove(at: index)
        let olderNeighbor = index < photos.count ? photos[index].id : nil
        return DeletedPhoto(photo: photo, index: index, olderNeighborID: olderNeighbor)
    }

    mutating func restore(_ deleted: DeletedPhoto) {
        guard !photos.contains(where: { $0.id == deleted.photo.id }) else { return }
        let neighborIndex = deleted.olderNeighborID.flatMap { id in photos.firstIndex { $0.id == id } }
        let fallback = deleted.olderNeighborID == nil ? photos.count : min(deleted.index, photos.count)
        photos.insert(deleted.photo, at: neighborIndex ?? fallback)
    }

    mutating func setAdjustments(_ adjustments: PhotoAdjustments, for id: Photo.ID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].adjustments = adjustments
    }
}
