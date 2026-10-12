import Foundation

/// A removed photo and enough about where it was to put it back.
nonisolated struct DeletedPhoto: Hashable, Sendable {
    let photo: Photo
    let index: Int
    /// The photo that sat right after it, so Undo keeps the order even if new shots arrived meanwhile.
    let olderNeighborID: Photo.ID?
}

/// The photo library, newest first.
protocol PhotoStoring: AnyObject {
    var photos: [Photo] { get }
    func photo(id: Photo.ID) -> Photo?
    func add(_ photo: Photo)
    @discardableResult func delete(id: Photo.ID) -> DeletedPhoto?
    func restore(_ deleted: DeletedPhoto)
    func setAdjustments(_ adjustments: PhotoAdjustments, for id: Photo.ID)
}
