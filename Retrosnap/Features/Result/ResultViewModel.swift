import Foundation
import Observation

/// The screen shown right after a shot: the photo developing, then quiet actions and "Take another".
@Observable
final class ResultViewModel {
    static let developTime = Duration.milliseconds(900)

    let photoID: Photo.ID
    /// The Processing board: developing shown as a progress bar that does not finish.
    let isProcessing: Bool
    private(set) var isDeveloping = true

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private let dayLabeler: DayLabeler
    @ObservationIgnored private var hasAppeared = false

    init(
        photoID: Photo.ID,
        photos: any PhotoStoring,
        router: AppRouter,
        toasts: ToastCenter,
        scheduler: any Scheduling,
        dayLabeler: DayLabeler,
        isProcessing: Bool = false
    ) {
        self.photoID = photoID
        self.photos = photos
        self.router = router
        self.toasts = toasts
        self.scheduler = scheduler
        self.dayLabeler = dayLabeler
        self.isProcessing = isProcessing
    }

    var photo: Photo? {
        photos.photo(id: photoID)
    }

    var statusText: String {
        isDeveloping ? "Developing…" : "Saved to Photos"
    }

    /// "35mm Film · Just now"
    var metaText: String {
        guard let photo else { return "" }
        let when = photo.isJustCaptured ? "Just now" : dayLabeler.label(for: photo.capturedAt)
        return "\(photo.camera.name) · \(when)"
    }

    var isInstant: Bool {
        photo?.camera == .instant
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.capturedAt) }
    }

    func appeared() {
        guard !hasAppeared else { return }
        hasAppeared = true
        guard !isProcessing else { return }
        scheduler.after(Self.developTime) { [weak self] in
            self?.isDeveloping = false
        }
    }

    func closeTapped() {
        returnToCamera()
    }

    func takeAnotherTapped() {
        returnToCamera()
    }

    private func returnToCamera() {
        router.returnToCamera()
        toasts.show("Saved to Photos")
    }

    func perform(_ action: PhotoAction) {
        switch action {
        case .share:
            toasts.show("Share sheet opens here")
        case .edit:
            router.push(.edit(photoID))
        case .print:
            router.push(.print(photoID))
        case .collage:
            router.push(.collage(seed: photoID))
        case .delete:
            guard let deleted = photos.delete(id: photoID) else { return }
            router.returnToCamera()
            toasts.show("Photo deleted", actionTitle: "Undo") { [photos] in
                photos.restore(deleted)
            }
        }
    }
}
