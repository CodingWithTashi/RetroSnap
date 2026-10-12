import Foundation
import Observation

/// The screen shown right after a shot: the photo developing, then quiet actions and "Take another".
@Observable
final class ResultViewModel {
    static let developTime = Duration.milliseconds(900)
    /// Where the bar stands on the design's static Processing board.
    private static let boardProgress = 0.62

    let photoID: Photo.ID
    /// The develop animation has run its course.
    private var hasDeveloped = false
    /// The Processing board: a progress bar that does not finish.
    @ObservationIgnored private let isPosedProcessing: Bool

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let saver: PhotosSaver
    @ObservationIgnored private let sharing: any PhotoSharing
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private let dayLabeler: DayLabeler
    @ObservationIgnored private var hasAppeared = false

    init(
        photoID: Photo.ID,
        photos: any PhotoStoring,
        saver: PhotosSaver,
        sharing: any PhotoSharing,
        router: AppRouter,
        toasts: ToastCenter,
        scheduler: any Scheduling,
        dayLabeler: DayLabeler,
        isProcessing: Bool = false
    ) {
        self.photoID = photoID
        self.photos = photos
        self.saver = saver
        self.sharing = sharing
        self.router = router
        self.toasts = toasts
        self.scheduler = scheduler
        self.dayLabeler = dayLabeler
        isPosedProcessing = isProcessing
    }

    /// How far along the clip's bake for Photos is, from 0 to 1; nil when there is nothing to wait for.
    var processingProgress: Double? {
        isPosedProcessing ? Self.boardProgress : saver.progress(for: photoID)
    }

    var isProcessing: Bool {
        processingProgress != nil
    }

    /// The print is still coming up: the develop animation is running, or a clip is being baked.
    var isDeveloping: Bool {
        !hasDeveloped || isProcessing
    }

    var photo: Photo? {
        photos.photo(id: photoID)
    }

    var statusText: String {
        isDeveloping ? "Developing…" : saver.savedText
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
        scheduler.after(Self.developTime) { [weak self] in
            self?.hasDeveloped = true
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
        toasts.show(saver.savedText)
    }

    func perform(_ action: PhotoAction) {
        switch action {
        case .share:
            photo.map(sharing.share)
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
