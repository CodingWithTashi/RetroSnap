import Foundation
import Observation

/// The camera screen: which look is live, the top controls, the shutter in all its modes,
/// and the banners and blocked states. Mirrors the camera logic of the design prototype.
@Observable
final class CameraViewModel {
    /// A starting state other than the ordinary one, for the design's static boards.
    nonisolated struct Preset: Sendable {
        var isStripOpen = false
        var mode = CaptureMode.photo
        /// Starts mid-recording at this many seconds, frozen.
        var recordedSeconds: Int?
        /// The shutter held down with the white flash on, as on the Capture board.
        var isPosed = false
    }

    static let countdownStart = 3
    static let countdownBeat = Duration.milliseconds(700)
    static let reviewDelay = Duration.milliseconds(420)

    private(set) var style: CameraStyle
    private(set) var mode: CaptureMode
    private(set) var flash: FlashMode
    private(set) var facing = CameraFacing.back
    private(set) var isTimerOn: Bool
    /// The number on screen during the self-timer; 0 when it is not running.
    private(set) var countdown = 0
    private(set) var isStripOpen: Bool
    /// The strip is showing its first-launch introduction.
    private(set) var isFirstRun: Bool
    private(set) var isRecording: Bool
    private(set) var recordedSeconds: Int
    /// Bumps when the shutter fires; the view plays the white flash and the fly to the gallery on change.
    private(set) var shutterCount = 0
    /// The look of a photo that has been asked for and has not come back yet. Until it does, the gallery
    /// button shows what the viewfinder saw.
    private(set) var pendingShot: CameraStyle?
    /// Bumps on every look change; the view shows the camera's name briefly on change.
    private(set) var styleChangeCount = 0
    private(set) var isPosed: Bool

    @ObservationIgnored private let config: AppConfig
    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let camera: any CameraServicing
    @ObservationIgnored private let permissions: any PermissionServicing
    @ObservationIgnored private let storage: any StorageMonitoring
    @ObservationIgnored private let settings: any SettingsStoring
    @ObservationIgnored private let feedback: FeedbackCenter
    @ObservationIgnored private let saver: PhotosSaver
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private var countdownWork: (any ScheduledWork)?
    @ObservationIgnored private var reviewWork: (any ScheduledWork)?
    @ObservationIgnored private var recordingTicker: (any ScheduledWork)?
    /// The review of the shot in the air, while the user has not walked away from it.
    @ObservationIgnored private var review: Review?
    /// The zoom a pinch in progress started from.
    @ObservationIgnored private var pinchStart: Double?
    private var dismissedBanners: Set<CameraBanner> = []

    init(
        config: AppConfig,
        photos: any PhotoStoring,
        camera: any CameraServicing,
        permissions: any PermissionServicing,
        storage: any StorageMonitoring,
        settings: any SettingsStoring,
        feedback: FeedbackCenter,
        saver: PhotosSaver,
        location: any LocationProviding,
        router: AppRouter,
        toasts: ToastCenter,
        scheduler: any Scheduling,
        preset: Preset = Preset()
    ) {
        self.config = config
        self.photos = photos
        self.camera = camera
        self.permissions = permissions
        self.storage = storage
        self.settings = settings
        self.feedback = feedback
        self.saver = saver
        self.location = location
        self.router = router
        self.toasts = toasts
        self.scheduler = scheduler

        style = settings.lastCamera
        flash = settings.flash
        isTimerOn = settings.isTimerOn
        isFirstRun = !settings.hasSeenCameraIntro
        isStripOpen = preset.isStripOpen || !settings.hasSeenCameraIntro
        isRecording = preset.recordedSeconds != nil
        recordedSeconds = preset.recordedSeconds ?? 0
        mode = preset.recordedSeconds != nil ? .video : preset.mode
        isPosed = preset.isPosed
        if isRecording {
            camera.startRecording(shot)
        }
    }

    // MARK: Derived state

    var block: CameraBlock? {
        switch camera.availability {
        case .ready: nil
        case .denied: .denied
        case .busy: .busy
        }
    }

    var banner: CameraBanner? {
        guard block == nil else { return nil }
        if settings.saveToPhotos, permissions.photoLibraryAccess == .denied, !dismissedBanners.contains(.library) {
            return .library
        }
        if storage.isLow, !dismissedBanners.contains(.storage) {
            return .storage
        }
        return nil
    }

    var isStripVisible: Bool {
        isStripOpen && block == nil && !isRecording
    }

    var isChipVisible: Bool {
        !isStripVisible && !isRecording
    }

    var stripTitle: String {
        isFirstRun ? "Choose a camera" : style.name
    }

    var stripSubtitle: String {
        isFirstRun ? "\(style.name) is on. You can shoot right away." : style.shortSummary
    }

    var scene: PhotoImage {
        camera.scene(for: facing)
    }

    /// The viewfinder is between two lenses or modes; it is drawn out of focus until the new picture is there.
    var isViewfinderSettling: Bool {
        camera.isSwitching
    }

    /// The newest shot, shown in the gallery button.
    var lastPhoto: Photo? {
        photos.photos.first
    }

    var shutterAppearance: ShutterAppearance {
        if isRecording { .recording } else if mode == .video { .video } else { .photo }
    }

    var isShutterEnabled: Bool {
        block == nil
    }

    /// Elapsed recording time, "MM:SS".
    var recordingClock: String {
        String(format: "%02d:%02d", recordedSeconds / 60, recordedSeconds % 60)
    }

    var bannerContent: CameraNotice? {
        switch banner {
        case .library:
            CameraNotice(
                title: "Saving inside RetroSnap only",
                message: "Allow Photos access to also save to your library.",
                actionTitle: "Allow"
            )
        case .storage:
            CameraNotice(
                title: "Your phone is almost full",
                message: "About \(storage.photosLeft) photos left. Free up space to keep shooting.",
                actionTitle: "Manage"
            )
        case nil:
            nil
        }
    }

    var blockContent: CameraNotice? {
        switch block {
        case .denied:
            CameraNotice(
                title: "Camera access is off",
                message: "Turn on Camera for RetroSnap in\nSettings to start shooting.",
                actionTitle: "Open Settings"
            )
        case .busy:
            CameraNotice(
                title: "Camera is busy",
                message: "Another app is using the camera.\nClose it, then try again.",
                actionTitle: "Try again"
            )
        case nil:
            nil
        }
    }

    // MARK: VoiceOver labels

    var flashLabel: String {
        "Flash: \(flash.rawValue)"
    }

    var timerLabel: String {
        isTimerOn ? "Self-timer on, \(Self.countdownStart) seconds" : "Self-timer off"
    }

    var shutterLabel: String {
        switch shutterAppearance {
        case .photo: "Take photo"
        case .video: "Start recording"
        case .recording: "Stop recording"
        }
    }

    var chipLabel: String {
        "Camera: \(style.name). Change camera"
    }

    var zoomLabel: String {
        "Zoom: \(zoomTitle)"
    }

    // MARK: Choosing a camera

    func chipTapped() {
        guard block == nil, !isRecording else { return }
        feedback.haptic(.tick)
        if config.selector == .carousel {
            router.push(.cameraCarousel)
        } else {
            isStripOpen.toggle()
        }
    }

    func closeStripTapped() {
        isStripOpen = false
        endFirstRun()
    }

    /// A tap on the picture folds the strip away, except while it is introducing itself.
    func viewfinderTapped() {
        guard isStripOpen, !isFirstRun else { return }
        isStripOpen = false
    }

    /// Swiping left goes to the next camera, right to the previous one, wrapping at the ends.
    func viewfinderSwiped(_ direction: SwipeDirection) {
        guard block == nil else { return }
        pick(style.stepped(by: direction == .left ? 1 : -1))
    }

    func pick(_ newStyle: CameraStyle) {
        guard !isRecording else { return }
        feedback.haptic(.soft)
        isStripOpen = false
        endFirstRun()
        guard newStyle != style else { return }
        style = newStyle
        styleChangeCount += 1
        settings.lastCamera = newStyle
    }

    func pickFromCarousel(_ newStyle: CameraStyle) {
        pick(newStyle)
        router.returnToCamera()
    }

    private func endFirstRun() {
        isFirstRun = false
        settings.hasSeenCameraIntro = true
    }

    // MARK: Zoom

    var zoomTitle: String {
        camera.zoom.title
    }

    /// Anything but the main lens's own view; the button shows it in amber.
    var isZoomed: Bool {
        !camera.zoom.isAtRest
    }

    var isZoomVisible: Bool {
        block == nil && !isStripVisible
    }

    /// How much the screen enlarges a still scene to show the zoom. A live picture arrives zoomed.
    var sceneMagnification: Double {
        guard scene != .live else { return 1 }
        return camera.zoom.factor / camera.zoom.range.lowerBound
    }

    /// Each tap goes to the next lens up, and from the last one round to the first.
    func zoomTapped() {
        guard block == nil else { return }
        feedback.haptic(.tick)
        camera.setZoom(camera.zoom.nextStop, smoothly: true)
    }

    /// Two fingers spreading or closing on the viewfinder. `magnification` is 1 where they started.
    func viewfinderPinched(_ magnification: Double) {
        guard block == nil else { return }
        let zoom = camera.zoom
        let start = pinchStart ?? zoom.factor
        pinchStart = start
        let target = zoom.settled(start * magnification)
        guard target != zoom.factor else { return }
        if zoom.passesStop(goingTo: target) {
            feedback.haptic(.tick)
        }
        camera.setZoom(target, smoothly: false)
    }

    func viewfinderPinchEnded() {
        pinchStart = nil
    }

    // MARK: Top controls

    func flashTapped() {
        feedback.haptic(.tick)
        flash = flash.next
        settings.flash = flash
    }

    func timerTapped() {
        feedback.haptic(.tick)
        isTimerOn.toggle()
        settings.isTimerOn = isTimerOn
    }

    func select(_ newMode: CaptureMode) {
        guard !isRecording, countdown == 0, newMode != mode else { return }
        mode = newMode
        guard newMode == .video else {
            camera.start(facing: facing, mode: mode)
            return
        }
        // The camera is set up for video once the microphone question is settled, so the clip gets its sound.
        permissions.requestMicrophoneAccess { [weak self] in
            guard let self, mode == .video else { return }
            camera.start(facing: facing, mode: mode)
        }
    }

    func flipTapped() {
        // Changing lens takes the camera away from a recording and ends it.
        guard !isRecording else { return }
        feedback.haptic(.soft)
        facing = facing.flipped
        camera.start(facing: facing, mode: mode)
    }

    // MARK: Running the camera

    /// The camera screen is on screen.
    func appeared() {
        camera.start(facing: facing, mode: mode)
        prepareFeedback()
        if settings.locationOnPhotos {
            location.start()
        }
    }

    /// Another screen covers the camera.
    func disappeared() {
        camera.stop()
        location.stop()
    }

    /// The app is in front again; permissions and free space may have changed meanwhile.
    func becameActive() {
        permissions.refresh()
        storage.refresh()
    }

    // MARK: Shutter

    /// A finger has come down on the shutter; the tap follows when it lifts.
    func shutterPressed() {
        prepareFeedback()
    }

    /// The click only follows a photo. Whether iOS makes its own instead is not known until the camera runs,
    /// so the app's is made ready either way; it costs nothing on the main actor.
    private func prepareFeedback() {
        feedback.prepare(click: mode == .photo)
    }

    func shutterTapped() {
        guard block == nil, countdown == 0, pendingShot == nil else { return }
        if mode == .video {
            toggleRecording()
        } else if isTimerOn {
            runCountdown(from: Self.countdownStart)
        } else {
            capture()
        }
    }

    private func runCountdown(from beat: Int) {
        guard beat > 0 else {
            countdown = 0
            countdownWork = nil
            capture()
            return
        }
        feedback.haptic(.tick)
        countdown = beat
        countdownWork = scheduler.after(Self.countdownBeat) { [weak self] in
            self?.runCountdown(from: beat - 1)
        }
    }

    private func capture() {
        feedback.haptic(.firm)
        if !camera.playsSystemShutterSound {
            feedback.shutterClick()
        }
        pendingShot = style
        shutterCount += 1
        isStripOpen = false
        isPosed = false
        endFirstRun()

        let review = startReview()
        camera.capturePhoto(shot) { [weak self] photo in
            self?.captured(photo, review: review)
        }
    }

    /// A shot's turn on the result screen: it opens once the photo has landed, and no sooner than the
    /// fly-in the shutter started is over.
    private final class Review {
        var photoID: Photo.ID?
        var hasFlownIn = false
    }

    /// Starts this shot's review if the rule asks for one, replacing whatever an earlier shot left.
    private func startReview() -> Review? {
        reviewWork?.cancel()
        let isWanted = config.reviewRule == .always || (config.reviewRule == .first && !settings.hasTakenFirstPhoto)
        guard isWanted else {
            review = nil
            reviewWork = nil
            return nil
        }
        let review = Review()
        self.review = review
        reviewWork = scheduler.after(Self.reviewDelay) { [weak self] in
            review.hasFlownIn = true
            self?.showIfReady(review)
        }
        return review
    }

    /// What the camera is asked for right now, tagged with the place while "Location on photos" is on.
    private var shot: Shot {
        Shot(style: style, facing: facing, flash: flash, location: settings.locationOnPhotos ? location.current : nil)
    }

    /// The camera has delivered the photo, or given up on it.
    private func captured(_ photo: Photo?, review: Review?) {
        pendingShot = nil
        guard let photo else {
            toasts.show("Couldn’t save the photo")
            return
        }
        photos.add(photo)
        saver.save(photo)
        storage.refresh()

        settings.hasTakenFirstPhoto = true

        if let review {
            review.photoID = photo.id
            showIfReady(review)
        } else {
            toasts.show("Saved · \(photo.camera.name)")
        }
    }

    /// Opens the result once both halves are in. A review the user walked away from is no longer the
    /// current one and is dropped; the router drops this too if the camera is not on top by then.
    private func showIfReady(_ review: Review) {
        guard review === self.review, review.hasFlownIn, let id = review.photoID else { return }
        self.review = nil
        router.showResult(id)
    }

    private func toggleRecording() {
        feedback.haptic(.firm)
        if isRecording {
            recordingTicker?.cancel()
            recordingTicker = nil
            isRecording = false
            camera.finishRecording(seconds: max(1, recordedSeconds)) { [weak self] clip in
                self?.recorded(clip)
            }
        } else {
            isRecording = true
            recordedSeconds = 0
            isStripOpen = false
            camera.startRecording(shot)
            recordingTicker = scheduler.every(.seconds(1)) { [weak self] in
                self?.recordedSeconds += 1
            }
        }
    }

    private func recorded(_ clip: Photo?) {
        guard let clip else {
            toasts.show("Couldn’t save the video")
            return
        }
        photos.add(clip)
        saver.save(clip)
        storage.refresh()
        router.showResult(clip.id)
    }

    // MARK: Leaving the camera

    func galleryTapped() {
        guard !isRecording else { return }
        cancelPendingWork()
        router.push(.gallery)
    }

    private func cancelPendingWork() {
        countdownWork?.cancel()
        countdownWork = nil
        countdown = 0
        reviewWork?.cancel()
        reviewWork = nil
        review = nil
    }

    // MARK: Banners and blocked states

    func bannerActionTapped() {
        switch banner {
        case .library:
            dismissedBanners.insert(.library)
            permissions.requestPhotoLibraryAccess { [weak self] in
                guard let self, permissions.photoLibraryAccess == .granted else { return }
                toasts.show("Saving to Photos")
            }
        case .storage:
            // iOS offers no way into its own storage screen; the gallery is where shots can be deleted.
            dismissedBanners.insert(.storage)
            galleryTapped()
        case nil:
            break
        }
    }

    func blockActionTapped() {
        guard let block else { return }
        camera.recover { [toasts] in
            toasts.show(block == .denied ? "Camera is on" : "Camera ready")
        }
    }
}
