import AVFoundation
import Foundation
import Observation
import os
import UIKit

/// The device camera. The session lives in `CaptureSession`, off the main actor; this is its face on the
/// main actor: whether the camera can be used, the frames for the viewfinder, and photos filed in the library.
@Observable
final class LiveCameraService: CameraServicing {
    private static let log = Logger.retroSnap("camera")
    /// The preview's rotation with the interface in portrait, for the moment before there is a window to ask.
    private static let portraitAngle: CGFloat = 90

    private(set) var availability: CameraAvailability
    private(set) var playsSystemShutterSound = true
    private(set) var zoom = CameraZoom.fixed
    /// Changes of lens or mode that have been asked for and are not finished.
    private var switchCount = 0

    /// The frames the viewfinder draws.
    @ObservationIgnored let feed: FrameFeed
    /// The frame the viewfinder was showing as the shutter last fired: the shot, until the real one is ready.
    @ObservationIgnored let shotFeed = FrameFeed()
    @ObservationIgnored private let clock: any DateProviding
    @ObservationIgnored private let folder: PhotoLibraryFolder
    @ObservationIgnored private let loader: PhotoImageLoader
    @ObservationIgnored private let session: CaptureSession
    @ObservationIgnored private var facing = CameraFacing.back
    @ObservationIgnored private var mode = CaptureMode.photo
    /// The clip being recorded: what it was started with, and the record it will become.
    @ObservationIgnored private var recording: (shot: Shot, id: Photo.ID, startedAt: Date)?
    /// Session work, done in the order it was asked for.
    @ObservationIgnored private var work: Task<Void, Never>?
    /// The newest zoom the session has not been told yet. A pinch asks faster than the camera follows,
    /// so only the latest is sent on.
    @ObservationIgnored private var zoomWaiting: (factor: Double, smoothly: Bool)?
    @ObservationIgnored private var isSendingZoom = false
    @ObservationIgnored private var rotation: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservation: NSKeyValueObservation?

    /// - Parameter loader: Decodes a new shot's thumbnail before the shot is handed over, so it can be drawn at once.
    init(clock: any DateProviding, folder: PhotoLibraryFolder, loader: PhotoImageLoader) {
        self.clock = clock
        self.folder = folder
        self.loader = loader
        let feed = FrameFeed()
        self.feed = feed
        session = CaptureSession { feed.submit($0) }

        let access = AVCaptureDevice.authorizationStatus(for: .video)
        availability = access == .denied || access == .restricted ? .denied : .ready
        watchSession()
    }

    var isSwitching: Bool {
        switchCount > 0
    }

    func scene(for facing: CameraFacing) -> PhotoImage {
        .live
    }

    func start(facing: CameraFacing, mode: CaptureMode) {
        // Coming back to the same lens and mode only picks the picture up where it stopped.
        let isChange = facing != self.facing || mode != self.mode
        if facing != self.facing {
            // The other lens starts at its own 1×; how far it zooms is known once it runs.
            zoom.factor = 1
        }
        self.facing = facing
        self.mode = mode
        if isChange {
            switchCount += 1
        }
        enqueue { [weak self] in
            await self?.run()
            guard let self, isChange else { return }
            switchCount -= 1
        }
    }

    func stop() {
        enqueue { [session] in
            await session.stop()
        }
    }

    func setZoom(_ factor: Double, smoothly: Bool) {
        zoom.factor = zoom.clamped(factor)
        zoomWaiting = (zoom.factor, smoothly)
        guard !isSendingZoom else { return }
        isSendingZoom = true
        Task { [weak self, session] in
            while let next = self?.zoomWaiting {
                self?.zoomWaiting = nil
                await session.setZoom(next.factor, smoothly: next.smoothly)
            }
            self?.isSendingZoom = false
        }
    }

    func capturePhoto(_ shot: Shot, completion: @escaping @MainActor (Photo?) -> Void) {
        shotFeed.show(feed.frame)
        let id = UUID().uuidString
        let capturedAt = clock.now
        let angle = rotation?.videoRotationAngleForHorizonLevelCapture ?? Self.portraitAngle
        Task { [session, folder, loader] in
            do {
                let captured = try await session.capturePhoto(flash: shot.flash, rotationAngle: angle)
                let image = try await folder.storeConcurrently(
                    original: captured.data, id: id, fileExtension: captured.fileExtension
                )
                await loader.prepareThumbnail(of: image)
                completion(Photo(
                    id: id, image: image, camera: shot.style, capturedAt: capturedAt, isJustCaptured: true,
                    location: shot.location
                ))
            } catch {
                Self.log.error("A photo could not be taken: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    func startRecording(_ shot: Shot) {
        recording = (shot, UUID().uuidString, clock.now)
        let angle = rotation?.videoRotationAngleForHorizonLevelCapture ?? Self.portraitAngle
        enqueue { [session] in
            do {
                try await session.startRecording(rotationAngle: angle, light: shot.flash)
            } catch {
                Self.log.error("Recording could not start: \(error.localizedDescription)")
            }
        }
    }

    func finishRecording(seconds: Int, completion: @escaping @MainActor (Photo?) -> Void) {
        guard let recording else {
            completion(nil)
            return
        }
        self.recording = nil
        enqueue { [session, folder, loader] in
            do {
                let movie = try await session.stopRecording()
                let filed = try await folder.storeClip(movieAt: movie, id: recording.id)
                await loader.prepareThumbnail(of: filed.poster)
                completion(Photo(
                    id: recording.id, image: filed.poster, camera: recording.shot.style, capturedAt: recording.startedAt,
                    isJustCaptured: true, videoSeconds: seconds, videoFile: filed.videoFile,
                    location: recording.shot.location
                ))
            } catch {
                Self.log.error("A clip could not be saved: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    func recover(completion: @escaping @MainActor () -> Void) {
        // Camera access is turned back on in the app's page in Settings.
        guard availability != .denied else {
            SystemSettings.open()
            return
        }
        enqueue { [weak self] in
            guard let self else { return }
            await run()
            if availability == .ready {
                completion()
            }
        }
    }

    // MARK: Session

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        work = Task { [previous = work] in
            await previous?.value
            await operation()
        }
    }

    private func run() async {
        guard await isAllowed() else {
            availability = .denied
            return
        }
        guard let device = Self.device(for: facing) else {
            availability = .busy
            return
        }
        follow(device)
        do {
            zoom = try await session.run(device, for: mode, previewAngle: previewAngle)
            playsSystemShutterSound = await !session.canSilenceShutter
            availability = .ready
        } catch {
            Self.log.error("The camera could not start: \(error.localizedDescription)")
            availability = .busy
        }
    }

    /// The back camera with every lens the phone has, so that zooming can change lens. The front one has a single lens.
    private static func device(for facing: CameraFacing) -> AVCaptureDevice? {
        guard facing == .back else {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        let kinds: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera,
        ]
        return kinds.lazy.compactMap { AVCaptureDevice.default($0, for: .video, position: .back) }.first
    }

    /// Asks for the camera when iOS never has; the onboarding screen normally does this first.
    private func isAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    // MARK: Rotation

    private var previewAngle: CGFloat {
        guard let rotation, rotation.previewLayer != nil else { return Self.portraitAngle }
        return rotation.videoRotationAngleForHorizonLevelPreview
    }

    /// Keeps the viewfinder upright as the interface turns, and tells captures how the device is held.
    private func follow(_ device: AVCaptureDevice) {
        guard rotation?.device?.uniqueID != device.uniqueID else { return }
        // Any layer on screen tells the coordinator which way up the interface is.
        let screen = UIApplication.shared.frontWindow?.layer
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: screen)
        rotation = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview) { [session] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task {
                await session.setPreviewAngle(angle)
            }
        }
    }

    // MARK: Interruptions

    /// Follows the session being taken away and given back: by another app, by the system, or by an error.
    private func watchSession() {
        let center = NotificationCenter.default
        Task { [weak self] in
            for await notification in center.notifications(named: AVCaptureSession.wasInterruptedNotification) {
                let reason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                    .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
                // Going to the background interrupts the session too; that is not the camera being busy.
                if reason != .videoDeviceNotAvailableInBackground {
                    self?.availability = .busy
                }
            }
        }
        Task { [weak self] in
            for await _ in center.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                guard let self, availability == .busy else { continue }
                availability = .ready
            }
        }
        Task { [weak self] in
            for await _ in center.notifications(named: AVCaptureSession.runtimeErrorNotification) {
                self?.availability = .busy
            }
        }
    }
}
