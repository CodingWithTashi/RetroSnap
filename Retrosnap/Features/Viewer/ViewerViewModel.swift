import Foundation
import Observation

/// One photo full screen, with swiping to its neighbours.
@Observable
final class ViewerViewModel {
    private(set) var currentID: Photo.ID

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(photoID: Photo.ID, photos: any PhotoStoring, router: AppRouter, toasts: ToastCenter, dayLabeler: DayLabeler) {
        currentID = photoID
        self.photos = photos
        self.router = router
        self.toasts = toasts
        self.dayLabeler = dayLabeler
    }

    var photo: Photo? {
        photos.photo(id: currentID)
    }

    var title: String {
        photo.map { dayLabeler.label(for: $0.capturedAt) } ?? ""
    }

    var subtitle: String {
        guard let photo else { return "" }
        return photo.camera.name + (photo.isVideo ? " · Video" : "")
    }

    var isInstant: Bool {
        photo?.camera == .instant
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.capturedAt) }
    }

    /// Swiping left shows the next (older) photo, right the previous one. Stops at both ends.
    func swiped(_ direction: SwipeDirection) {
        let all = photos.photos
        guard let index = all.firstIndex(where: { $0.id == currentID }) else { return }
        let target = index + (direction == .left ? 1 : -1)
        guard all.indices.contains(target) else { return }
        currentID = all[target].id
    }

    func backTapped() {
        router.back()
    }

    func perform(_ action: PhotoAction) {
        switch action {
        case .share:
            toasts.show("Share sheet opens here")
        case .edit:
            router.push(.edit(currentID))
        case .print:
            router.push(.print(currentID))
        case .collage:
            router.push(.collage(seed: currentID))
        case .delete:
            guard let deleted = photos.delete(id: currentID) else { return }
            router.returnToGallery()
            toasts.show("Photo deleted", actionTitle: "Undo") { [photos] in
                photos.restore(deleted)
            }
        }
    }
}
