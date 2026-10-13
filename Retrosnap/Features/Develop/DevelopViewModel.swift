import Foundation
import Observation

/// A pick from the Photos library getting its look: the picture under the camera chosen for it, the strip to
/// choose another, and the shutter to develop it into the library, just as a shot is.
@Observable
final class DevelopViewModel {
    /// The result opens once the flash is over, as it does after a shot.
    static let reviewDelay = CameraViewModel.reviewDelay
    /// What the user is told when a pick could not be read.
    static let importFailedText = "Couldn’t open that photo or video"

    private(set) var draft: Photo
    private(set) var isStripOpen = false
    /// Bumps when the shutter fires; the view plays the white flash on change.
    private(set) var shutterCount = 0
    /// Bumps on every look change; the view shows the camera's name briefly on change.
    private(set) var styleChangeCount = 0
    /// The shutter has fired: the pick is in the library and its result is on its way.
    private(set) var isDeveloping = false

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let saver: PhotosSaver
    @ObservationIgnored private let importer: any PhotoImporting
    @ObservationIgnored private let player: any ClipPlaying
    @ObservationIgnored private let feedback: FeedbackCenter
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(
        draft: Photo,
        photos: any PhotoStoring,
        saver: PhotosSaver,
        importer: any PhotoImporting,
        player: any ClipPlaying,
        feedback: FeedbackCenter,
        router: AppRouter,
        toasts: ToastCenter,
        scheduler: any Scheduling,
        dayLabeler: DayLabeler
    ) {
        self.draft = draft
        self.photos = photos
        self.saver = saver
        self.importer = importer
        self.player = player
        self.feedback = feedback
        self.router = router
        self.toasts = toasts
        self.scheduler = scheduler
        self.dayLabeler = dayLabeler
    }

    // MARK: Derived state

    var style: CameraStyle {
        draft.camera
    }

    var isVideo: Bool {
        draft.isVideo
    }

    /// What is being developed: "Photo", or "Video 0:24".
    var kindTitle: String {
        draft.videoDurationText.map { "Video \($0)" } ?? "Photo"
    }

    var stamp: PhotoStampText {
        dayLabeler.stamp(for: draft.capturedAt)
    }

    var isStripVisible: Bool {
        isStripOpen
    }

    var isChipVisible: Bool {
        !isStripOpen
    }

    var stripTitle: String {
        style.name
    }

    var stripSubtitle: String {
        style.shortSummary
    }

    /// Another pick is being copied in.
    var isImporting: Bool {
        importer.isImporting
    }

    // MARK: VoiceOver labels

    var chipLabel: String {
        "Camera: \(style.name). Change camera"
    }

    var shutterLabel: String {
        isVideo ? "Develop video" : "Develop photo"
    }

    var pictureLabel: String {
        "\(kindTitle) from your library, \(style.name)"
    }

    // MARK: Playing a clip

    /// This clip's movie is open in the player, playing or paused.
    private var isMovieOpen: Bool {
        guard let videoFile = draft.videoFile else { return false }
        return player.openFile == videoFile
    }

    /// What the screen draws: the picture, a clip's first frame, or the movie once it has been started.
    var picture: PhotoImage {
        isMovieOpen ? .live : draft.image
    }

    /// The play badge over a clip that is not running. The length is in the title, so the badge carries none.
    var badgeText: String? {
        guard isVideo, !(isMovieOpen && player.isPlaying) else { return nil }
        return ""
    }

    /// The movie's frames, for the picture to draw.
    var movieFrames: FrameFeed {
        player.frames
    }

    // MARK: Choosing a camera

    func chipTapped() {
        guard !isDeveloping else { return }
        feedback.haptic(.tick)
        isStripOpen.toggle()
    }

    func closeStripTapped() {
        isStripOpen = false
    }

    /// A tap on the picture folds the strip away. With the strip away, it plays a clip where it sits, or pauses it.
    func pictureTapped() {
        guard !isDeveloping else { return }
        if isStripOpen {
            isStripOpen = false
            return
        }
        guard let videoFile = draft.videoFile else { return }
        if isMovieOpen, player.isPlaying {
            player.pause()
        } else {
            player.play(videoFile)
        }
    }

    /// Swiping left goes to the next camera, right to the previous one, wrapping at the ends.
    func pictureSwiped(_ direction: SwipeDirection) {
        guard !isDeveloping else { return }
        pick(style.stepped(by: direction == .left ? 1 : -1))
    }

    func pick(_ newStyle: CameraStyle) {
        guard !isDeveloping else { return }
        feedback.haptic(.soft)
        isStripOpen = false
        guard newStyle != style else { return }
        draft.camera = newStyle
        styleChangeCount += 1
    }

    // MARK: Shutter

    /// A finger has come down on the shutter; the tap follows when it lifts.
    func shutterPressed() {
        feedback.prepare(click: true)
    }

    /// Files the pick in the library with its look, and opens its result once the flash is over.
    func shutterTapped() {
        guard !isDeveloping, !importer.isImporting else { return }
        feedback.haptic(.firm)
        feedback.shutterClick()
        player.stop()
        isDeveloping = true
        shutterCount += 1
        isStripOpen = false

        let photo = draft
        photos.add(photo)
        saver.save(photo)
        scheduler.after(Self.reviewDelay) { [weak self] in
            self?.router.showDevelopedResult(photo.id)
        }
    }

    // MARK: Leaving, or starting over

    /// The pick is not kept: its files go, and the gallery is back.
    func cancelTapped() {
        guard !isDeveloping else { return }
        player.stop()
        importer.discard(draft)
        router.back()
    }

    /// Another trip to the library. The new pick takes this one's place, on the camera chosen so far.
    func chooseAnotherTapped() {
        guard !isDeveloping, !importer.isImporting else { return }
        player.stop()
        let current = draft
        importer.pick { [weak self, importer] outcome in
            switch outcome {
            case .imported(var next):
                guard let self else {
                    importer.discard(next)
                    return
                }
                next.camera = current.camera
                importer.discard(current)
                draft = next
            case .failed:
                self?.toasts.show(Self.importFailedText)
            case .cancelled:
                break
            }
        }
    }

    /// Another screen covers this one.
    func disappeared() {
        player.stop()
    }
}
