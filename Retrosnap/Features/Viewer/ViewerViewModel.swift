import Foundation
import Observation

/// One photo full screen, with swiping to its neighbours. A clip plays in place when it is tapped.
@Observable
final class ViewerViewModel {
    private var currentID: Photo.ID

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let player: any ClipPlaying
    @ObservationIgnored private let sharing: any PhotoSharing
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(
        photoID: Photo.ID,
        photos: any PhotoStoring,
        player: any ClipPlaying,
        sharing: any PhotoSharing,
        router: AppRouter,
        toasts: ToastCenter,
        dayLabeler: DayLabeler
    ) {
        currentID = photoID
        self.photos = photos
        self.player = player
        self.sharing = sharing
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

    /// "Disposable, Today"
    var photoLabel: String {
        "\(subtitle), \(title)"
    }

    var subtitle: String {
        guard let photo else { return "" }
        guard !photo.isCollage else { return "Collage" }
        return photo.camera.name + (photo.isVideo ? " · Video" : "")
    }

    var isInstant: Bool {
        photo?.camera.isInstantPrint ?? false
    }

    /// The photo's box: width over height.
    var displayAspect: CGFloat {
        photo?.displayAspect ?? Photo.cameraAspect
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.stampDate) }
    }

    // MARK: Playing a clip

    /// This clip's movie is open in the player, playing or paused.
    private var isMovieOpen: Bool {
        guard let videoFile = photo?.videoFile else { return false }
        return player.openFile == videoFile
    }

    /// What the screen draws: the photo, a clip's first frame, or the movie once it has been started.
    var picture: PhotoImage? {
        isMovieOpen ? .live : photo?.image
    }

    /// The play badge and clip length, hidden while the movie runs.
    var badgeText: String? {
        isMovieOpen && player.isPlaying ? nil : photo?.videoDurationText
    }

    /// The movie's frames, for the picture to draw.
    var movieFrames: FrameFeed {
        player.frames
    }

    /// A tap plays a clip where it sits; another pauses it.
    func photoTapped() {
        guard let videoFile = photo?.videoFile else { return }
        if isMovieOpen, player.isPlaying {
            player.pause()
        } else {
            player.play(videoFile)
        }
    }

    // MARK: Moving on

    /// Swiping left shows the next (older) photo, right the previous one. Stops at both ends.
    func swiped(_ direction: SwipeDirection) {
        let all = photos.photos
        guard let index = all.firstIndex(where: { $0.id == currentID }) else { return }
        let target = index + direction.step
        guard all.indices.contains(target) else { return }
        player.stop()
        currentID = all[target].id
    }

    func backTapped() {
        player.stop()
        router.back()
    }

    func perform(_ action: PhotoAction) {
        player.stop()
        switch action {
        case .share:
            photo.map(sharing.share)
        case .edit, .print, .collage:
            if let route = action.route(for: currentID) {
                router.push(route)
            }
        case .delete:
            guard let deleted = photos.delete(id: currentID) else { return }
            router.returnToGallery()
            toasts.showDeleted(deleted, restoringInto: photos)
        }
    }
}
