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
    private(set) var flash = FlashMode.auto
    private(set) var facing = CameraFacing.back
    private(set) var isTimerOn = false
    /// The number on screen during the self-timer; 0 when it is not running.
    private(set) var countdown = 0
    private(set) var isStripOpen: Bool
    /// The strip is showing its first-launch introduction.
    private(set) var isFirstRun: Bool
    private(set) var isRecording: Bool
    private(set) var recordedSeconds: Int
    /// Bumps on every photo; the view plays the flash and fly-to-gallery animation on change.
    private(set) var shotCount = 0
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
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private var countdownWork: (any ScheduledWork)?
    @ObservationIgnored private var reviewWork: (any ScheduledWork)?
    @ObservationIgnored private var recordingTicker: (any ScheduledWork)?
    private var dismissedBanners: Set<CameraBanner> = []

    init(
        config: AppConfig,
        photos: any PhotoStoring,
        camera: any CameraServicing,
        permissions: any PermissionServicing,
        storage: any StorageMonitoring,
        settings: any SettingsStoring,
        feedback: FeedbackCenter,
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
        self.router = router
        self.toasts = toasts
        self.scheduler = scheduler

        style = settings.lastCamera
        isFirstRun = !settings.hasSeenCameraIntro
        isStripOpen = preset.isStripOpen || !settings.hasSeenCameraIntro
        isRecording = preset.recordedSeconds != nil
        recordedSeconds = preset.recordedSeconds ?? 0
        mode = preset.recordedSeconds != nil ? .video : preset.mode
        isPosed = preset.isPosed
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
        if permissions.photoLibraryAccess == .denied, !dismissedBanners.contains(.library) {
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

    var scene: SampleImage {
        camera.scene(for: facing)
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

    // MARK: Top controls

    func flashTapped() {
        feedback.haptic(.tick)
        flash = flash.next
    }

    func timerTapped() {
        feedback.haptic(.tick)
        isTimerOn.toggle()
    }

    func select(_ newMode: CaptureMode) {
        guard !isRecording, countdown == 0 else { return }
        mode = newMode
    }

    func flipTapped() {
        feedback.haptic(.soft)
        facing = facing.flipped
    }

    // MARK: Shutter

    func shutterTapped() {
        guard block == nil, countdown == 0 else { return }
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
        feedback.shutterClick()

        let photo = camera.capturePhoto(style: style, facing: facing)
        photos.add(photo)

        let review = config.reviewRule == .always || (config.reviewRule == .first && !settings.hasTakenFirstPhoto)
        settings.hasTakenFirstPhoto = true
        shotCount += 1
        isStripOpen = false
        isPosed = false
        endFirstRun()

        if review {
            // The flash and fly-in play first; the router drops this if the user has left the camera by then.
            reviewWork = scheduler.after(Self.reviewDelay) { [weak self] in
                self?.router.showResult(photo.id)
            }
        } else {
            toasts.show("Saved · \(style.name)")
        }
    }

    private func toggleRecording() {
        feedback.haptic(.firm)
        if isRecording {
            recordingTicker?.cancel()
            recordingTicker = nil
            isRecording = false
            let clip = camera.finishRecording(seconds: max(1, recordedSeconds), style: style, facing: facing)
            photos.add(clip)
            router.showResult(clip.id)
        } else {
            isRecording = true
            recordedSeconds = 0
            isStripOpen = false
            recordingTicker = scheduler.every(.seconds(1)) { [weak self] in
                self?.recordedSeconds += 1
            }
        }
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
    }

    // MARK: Banners and blocked states

    func bannerActionTapped() {
        switch banner {
        case .library:
            permissions.requestPhotoLibraryAccess()
            dismissedBanners.insert(.library)
            toasts.show("Saving to Photos")
        case .storage:
            dismissedBanners.insert(.storage)
            toasts.show("Opening Storage")
        case nil:
            break
        }
    }

    func blockActionTapped() {
        guard let block else { return }
        camera.recover()
        toasts.show(block == .denied ? "Camera is on" : "Camera ready")
    }
}
