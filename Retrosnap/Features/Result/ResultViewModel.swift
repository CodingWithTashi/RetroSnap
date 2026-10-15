import Foundation
import Observation

/// The screen shown right after a shot: the photo developing, then quiet actions and "Take another".
@Observable
final class ResultViewModel {
    /// The develop animation's own length.
    static let developTime = Duration.milliseconds(Int((RSMotion.developDuration * 1000).rounded()))
    /// Where the bar stands on the design's static Processing board.
    private static let boardProgress = 0.62

    private let photoID: Photo.ID
    /// The develop animation has run its course.
    private var hasDeveloped = false
    /// The Processing board: a progress bar that does not finish.
    @ObservationIgnored private let isPosedProcessing: Bool

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let saver: PhotosSaver
    @ObservationIgnored private let sharing: any PhotoSharing
    @ObservationIgnored private let importer: any PhotoImporting
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
        importer: any PhotoImporting,
        router: AppRouter,
        toasts: ToastCenter,
        scheduler: any Scheduling,
        dayLabeler: DayLabeler,
        isPosedProcessing: Bool = false
    ) {
        self.photoID = photoID
        self.photos = photos
        self.saver = saver
        self.sharing = sharing
        self.importer = importer
        self.router = router
        self.toasts = toasts
        self.scheduler = scheduler
        self.dayLabeler = dayLabeler
        self.isPosedProcessing = isPosedProcessing
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
        photo?.isInstantPrint ?? false
    }

    /// The print's width over its height.
    var displayAspect: CGFloat {
        photo?.displayAspect ?? Photo.cameraAspect
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.stampDate) }
    }

    /// The photo was brought in from the library: the result sits on the gallery, and the way on is another pick.
    var isFromLibrary: Bool {
        router.isResultOverGallery
    }

    var closeLabel: String {
        isFromLibrary ? "Back to photos" : "Back to camera"
    }

    /// The one amber button: back to the camera after a shot, the picker again after a pick.
    var primaryTitle: String {
        isFromLibrary ? "Develop another" : "Take another"
    }

    var primaryIcon: RSIcon {
        isFromLibrary ? .photos : .camera
    }

    var isPrimaryDimmed: Bool {
        isFromLibrary && importer.isImporting
    }

    func appeared() {
        guard !hasAppeared else { return }
        hasAppeared = true
        scheduler.after(Self.developTime) { [weak self] in
            self?.hasDeveloped = true
        }
    }

    func closeTapped() {
        leave()
    }

    func primaryTapped() {
        if isFromLibrary {
            developAnother()
        } else {
            leave()
        }
    }

    /// Back to where the photo came from, with where it went said once more.
    private func leave() {
        router.closeResult()
        toasts.show(saver.savedText)
    }

    /// Another trip to the library. The next pick starts on this photo's camera and takes the result's place.
    private func developAnother() {
        guard let photo, !importer.isImporting else { return }
        importer.pickDraft(on: photo.camera) { [weak self] draft in
            self?.router.showNextDevelop(draft) ?? false
        } failed: { [weak self] in
            self?.toasts.show(ImportOutcome.failureText)
        }
    }

    func perform(_ action: PhotoAction) {
        switch action {
        case .share:
            photo.map(sharing.share)
        case .edit, .print, .collage:
            if let route = action.route(for: photoID) {
                router.push(route)
            }
        case .delete:
            guard let deleted = photos.delete(id: photoID) else { return }
            router.closeResult()
            toasts.showDeleted(deleted, restoringInto: photos)
        }
    }
}
