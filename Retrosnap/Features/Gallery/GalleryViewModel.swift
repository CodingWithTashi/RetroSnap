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
    @ObservationIgnored private let settings: any SettingsStoring
    @ObservationIgnored private let importer: any PhotoImporting
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(
        photos: any PhotoStoring,
        settings: any SettingsStoring,
        importer: any PhotoImporting,
        router: AppRouter,
        toasts: ToastCenter,
        dayLabeler: DayLabeler
    ) {
        self.photos = photos
        self.settings = settings
        self.importer = importer
        self.router = router
        self.toasts = toasts
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
        let name = photo.isCollage ? "Collage" : "\(photo.camera.name) \(photo.isVideo ? "video" : "photo")"
        return "\(name), \(dayLabeler.label(for: photo.capturedAt))"
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

    // MARK: Bringing in a picture from the library

    /// A pick is on its way in; the add button shows it.
    var isImporting: Bool {
        importer.isImporting
    }

    var addLabel: String {
        isImporting ? "Opening your pick" : "Add from your library"
    }

    /// Opens the Photos picker. The pick goes to the develop screen on the camera the app is set to.
    func addTapped() {
        guard !importer.isImporting else { return }
        let camera = settings.lastCamera
        importer.pick { [weak self, importer] outcome in
            switch outcome {
            case .imported(var draft):
                guard let self else {
                    importer.discard(draft)
                    return
                }
                draft.camera = camera
                router.push(.develop(draft))
            case .failed:
                self?.toasts.show(DevelopViewModel.importFailedText)
            case .cancelled:
                break
            }
        }
    }
}
