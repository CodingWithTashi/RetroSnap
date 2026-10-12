import Foundation
import Observation

nonisolated struct GallerySection: Identifiable, Hashable, Sendable {
    /// Start of the day the photos were taken.
    let id: Date
    let title: String
    let countText: String
    let photos: [Photo]
}

@Observable
final class GalleryViewModel {
    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(photos: any PhotoStoring, router: AppRouter, dayLabeler: DayLabeler) {
        self.photos = photos
        self.router = router
        self.dayLabeler = dayLabeler
    }

    /// Photos grouped by day, newest day first; inside a day they keep library order.
    var sections: [GallerySection] {
        let grouped = Dictionary(grouping: photos.photos) { dayLabeler.startOfDay($0.capturedAt) }
        return grouped.keys.sorted(by: >).map { day in
            let items = grouped[day] ?? []
            return GallerySection(id: day, title: dayLabeler.label(for: day), countText: "\(items.count)", photos: items)
        }
    }

    var isEmpty: Bool {
        photos.photos.isEmpty
    }

    /// The floating button: a quiet way back to the camera, or the one primary action when there is nothing here.
    var actionTitle: String {
        isEmpty ? "Take a photo" : "Camera"
    }

    var isActionPrimary: Bool {
        isEmpty
    }

    func accessibilityLabel(for photo: Photo) -> String {
        "\(photo.camera.name) \(photo.isVideo ? "video" : "photo"), \(dayLabeler.label(for: photo.capturedAt))"
    }

    func open(_ photo: Photo) {
        router.push(.viewer(photo.id))
    }

    func closeTapped() {
        router.returnToCamera()
    }

    func cameraTapped() {
        router.returnToCamera()
    }

    func settingsTapped() {
        router.push(.settings)
    }
}
