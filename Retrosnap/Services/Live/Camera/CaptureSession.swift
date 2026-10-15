import AVFoundation
import CoreGraphics
import Foundation
import os

/// A photo as the camera delivered it.
nonisolated struct CapturedPhoto: Sendable {
    let data: Data
    /// "heic" or "jpg".
    let fileExtension: String
}

/// Owns the capture session. Everything that touches AVFoundation runs here, on the session's own queue,
/// off the main actor.
actor CaptureSession {
    enum Failure: Error {
        case cannotUseCamera
        case noPicture
        case notRecording
    }

    /// How fast a tap on the zoom button gets there, in doublings a second.
    private nonisolated static let zoomGlideRate: Float = 6

    private let queue = DispatchSerialQueue(label: "com.retrosnap.vintagecamera.capture")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let frameOutput = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let frames: FrameRelay
    private var input: AVCaptureDeviceInput?
    private var microphone: AVCaptureDeviceInput?
    private var mode: CaptureMode?
    private var hasOutputs = false
    private var recording: Recording?
    private var previewAngle: CGFloat = 0
    /// How the camera in use counts its zoom, and where it should be in its own numbers.
    private var lens = LensZoom(limits: 1...1, switchOvers: [], mainLens: 0)
    private var zoomFactor = 1.0
    /// Photos still being processed, kept alive until they finish.
    private var captures: [Int64: PhotoCapture] = [:]

    /// - Parameter onFrame: Called with every viewfinder frame, on a queue of its own.
    init(onFrame: @escaping @Sendable (CGImage) -> Void) {
        frames = FrameRelay(onFrame: onFrame)
    }

    /// Whether iOS lets this app take a photo without the system's own shutter sound.
    var canSilenceShutter: Bool {
        if #available(iOS 18.0, *) {
            photoOutput.isShutterSoundSuppressionSupported
        } else {
            false
        }
    }

    /// Runs the session on this camera, set up for photos or for video, replacing whatever was in use.
    /// - Returns: How far this camera zooms and where it is: 1× when it has just been switched to.
    func run(_ device: AVCaptureDevice, for mode: CaptureMode, previewAngle: CGFloat) throws -> CameraZoom {
        self.previewAngle = previewAngle
        let isSameCamera = input?.device.uniqueID == device.uniqueID
        try configure(device, for: mode, isSameCamera: isSameCamera)
        // Again now that the mode's format is in place, in case it could not be told before.
        quickenPhotos()

        // What a camera can zoom to depends on the format the mode has just picked.
        let shown = isSameCamera ? lens.zoom(atCameraFactor: zoomFactor).factor : 1
        lens = Self.lensZoom(of: device)
        zoomFactor = lens.cameraFactor(showing: shown)
        // A new format puts the camera back at its widest, so the zoom is set again: before the first
        // frame, and once more in case starting moved it.
        applyZoom(smoothly: false)
        if !session.isRunning {
            session.startRunning()
            applyZoom(smoothly: false)
        }
        // Another app can hold the camera while this session counts as running.
        guard session.isRunning, !session.isInterrupted else { throw Failure.cannotUseCamera }
        return lens.zoom(atCameraFactor: zoomFactor)
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    // MARK: Zoom

    /// Zooms the camera in use to a shown number, as far as it can go.
    func setZoom(_ factor: Double, smoothly: Bool) {
        zoomFactor = lens.cameraFactor(showing: factor)
        applyZoom(smoothly: smoothly)
    }

    private func applyZoom(smoothly: Bool) {
        guard let device = input?.device else { return }
        device.withLockedConfiguration {
            let factor = min(
                max(CGFloat(zoomFactor), device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor
            )
            if smoothly {
                device.ramp(toVideoZoomFactor: factor, withRate: Self.zoomGlideRate)
            } else {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = factor
            }
        }
    }

    /// A camera made of several lenses lists them from the widest, and says where it changes from one to the next.
    private nonisolated static func lensZoom(of device: AVCaptureDevice) -> LensZoom {
        let widest = Double(device.minAvailableVideoZoomFactor)
        return LensZoom(
            limits: widest...max(widest, Double(device.maxAvailableVideoZoomFactor)),
            switchOvers: device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue),
            mainLens: device.constituentDevices.firstIndex { $0.deviceType == .builtInWideAngleCamera } ?? 0
        )
    }

    // MARK: Preview angle

    /// Turns the viewfinder's frames so they stay upright as the interface rotates.
    func setPreviewAngle(_ angle: CGFloat) {
        previewAngle = angle
        applyPreviewAngle()
    }

    // MARK: Photos

    /// - Parameter rotationAngle: How far to turn the photo so that it is level however the device is held.
    func capturePhoto(flash: FlashMode, rotationAngle: CGFloat) async throws -> CapturedPhoto {
        guard session.isRunning, let connection = photoOutput.connection(with: .video) else {
            throw Failure.cannotUseCamera
        }
        connection.setRotationIfSupported(rotationAngle)

        let usesHEVC = photoOutput.availablePhotoCodecTypes.contains(.hevc)
        let settings = usesHEVC
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            : AVCapturePhotoSettings()
        let flashMode = AVCaptureDevice.FlashMode(flash)
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        if #available(iOS 18.0, *), photoOutput.isShutterSoundSuppressionSupported {
            settings.isShutterSoundSuppressionEnabled = true
        }

        let id = settings.uniqueID
        defer { captures[id] = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let capture = PhotoCapture(fileExtension: usesHEVC ? "heic" : "jpg", continuation: continuation)
            captures[id] = capture
            photoOutput.capturePhoto(with: settings, delegate: capture)
        }
    }

    // MARK: Video

    /// - Parameters:
    ///   - rotationAngle: How far to turn the clip so that it is level however the device is held.
    ///   - light: The flash setting, which for video means the torch.
    func startRecording(rotationAngle: CGFloat, light: FlashMode) throws {
        guard session.isRunning, session.outputs.contains(movieOutput), !movieOutput.isRecording else {
            throw Failure.cannotUseCamera
        }
        movieOutput.connection(with: .video)?.setRotationIfSupported(rotationAngle)
        setTorch(light)
        let recording = Recording()
        self.recording = recording
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        movieOutput.startRecording(to: file, recordingDelegate: recording)
    }

    /// Stops the recording and returns the finished movie, still in the temporary folder.
    func stopRecording() async throws -> URL {
        guard let recording else { throw Failure.notRecording }
        self.recording = nil
        defer { setTorch(.off) }
        // Asked for even when the output does not count as recording yet: it only does once the first
        // samples are written, and a recording that was started always reports that it finished.
        movieOutput.stopRecording()
        return try await recording.movie()
    }

    private func setTorch(_ light: FlashMode) {
        guard let device = input?.device, device.hasTorch else { return }
        let torch = AVCaptureDevice.TorchMode(light)
        guard device.isTorchModeSupported(torch) else { return }
        device.withLockedConfiguration { device.torchMode = torch }
    }

    // MARK: Configuration

    private func configure(_ device: AVCaptureDevice, for mode: CaptureMode, isSameCamera: Bool) throws {
        guard !isSameCamera || self.mode != mode else {
            applyPreviewAngle()
            return
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if !hasOutputs {
            guard session.canAddOutput(photoOutput), session.canAddOutput(frameOutput) else {
                throw Failure.cannotUseCamera
            }
            session.addOutput(photoOutput)
            frameOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            frameOutput.alwaysDiscardsLateVideoFrames = true
            frameOutput.setSampleBufferDelegate(frames, queue: frames.queue)
            session.addOutput(frameOutput)
            hasOutputs = true
        }

        if !isSameCamera {
            let newInput = try AVCaptureDeviceInput(device: device)
            if let input {
                session.removeInput(input)
            }
            guard session.canAddInput(newInput) else {
                if let input {
                    session.addInput(input)
                }
                throw Failure.cannotUseCamera
            }
            session.addInput(newInput)
            input = newInput
        }
        setUp(for: mode)
        quickenPhotos()

        // The front camera is shown and saved the way a mirror shows it.
        for output in [photoOutput, frameOutput, movieOutput] as [AVCaptureOutput] {
            guard let connection = output.connection(with: .video), connection.isVideoMirroringSupported else { continue }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = device.position == .front
        }
        applyPreviewAngle()
    }

    /// Video records 1080p movies with sound; photos need neither the movie output nor the microphone.
    private func setUp(for mode: CaptureMode) {
        self.mode = mode
        let preset: AVCaptureSession.Preset = mode == .video ? .hd1920x1080 : .photo
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
        guard mode == .video else {
            if session.outputs.contains(movieOutput) {
                session.removeOutput(movieOutput)
            }
            if let microphone {
                session.removeInput(microphone)
                self.microphone = nil
            }
            return
        }
        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        // Without microphone access the clip is recorded silent.
        if microphone == nil, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let device = AVCaptureDevice.default(for: .audio), let audio = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(audio) {
            session.addInput(audio)
            microphone = audio
        }
    }

    /// Lets a photo be taken the moment the shutter fires, and the next one before it is finished,
    /// wherever this camera and format can.
    private func quickenPhotos() {
        guard photoOutput.connection(with: .video) != nil else { return }
        if photoOutput.isZeroShutterLagSupported, !photoOutput.isZeroShutterLagEnabled {
            photoOutput.isZeroShutterLagEnabled = true
        }
        // Each is set only when it changes: the camera rebuilds its pipeline for every one that does.
        let isResponsive = photoOutput.isZeroShutterLagEnabled && photoOutput.isResponsiveCaptureSupported
        if photoOutput.isResponsiveCaptureEnabled != isResponsive {
            photoOutput.isResponsiveCaptureEnabled = isResponsive
        }
        let isFast = isResponsive && photoOutput.isFastCapturePrioritizationSupported
        if photoOutput.isFastCapturePrioritizationEnabled != isFast {
            photoOutput.isFastCapturePrioritizationEnabled = isFast
        }
    }

    private func applyPreviewAngle() {
        frameOutput.connection(with: .video)?.setRotationIfSupported(previewAngle)
    }
}

// MARK: - Bridging

private extension AVCaptureConnection {
    nonisolated func setRotationIfSupported(_ angle: CGFloat) {
        if isVideoRotationAngleSupported(angle) {
            videoRotationAngle = angle
        }
    }
}

private extension AVCaptureDevice {
    /// Runs the change with the device locked for configuration; does nothing when it cannot be locked.
    nonisolated func withLockedConfiguration(_ change: () -> Void) {
        guard (try? lockForConfiguration()) != nil else { return }
        defer { unlockForConfiguration() }
        change()
    }
}

private extension AVCaptureDevice.FlashMode {
    nonisolated init(_ mode: FlashMode) {
        switch mode {
        case .auto: self = .auto
        case .on: self = .on
        case .off: self = .off
        }
    }
}

private extension AVCaptureDevice.TorchMode {
    nonisolated init(_ mode: FlashMode) {
        switch mode {
        case .auto: self = .auto
        case .on: self = .on
        case .off: self = .off
        }
    }
}

// MARK: - Delegates

/// Waits for a recording to be written out. The movie can be finished before anyone asks for it
/// (the system may stop it), or asked for before it is finished; either order ends the same way.
private nonisolated final class Recording: NSObject, AVCaptureFileOutputRecordingDelegate, Sendable {
    private struct State {
        var result: Result<URL, any Error>?
        var waiting: CheckedContinuation<URL, any Error>?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func movie() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let finished = state.withLock { state -> Result<URL, any Error>? in
                if state.result == nil {
                    state.waiting = continuation
                }
                return state.result
            }
            if let finished {
                continuation.resume(with: finished)
            }
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection], error: (any Error)?
    ) {
        // Some errors, such as the disk filling up, still leave a movie that plays.
        let isUsable = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        let result: Result<URL, any Error> = isUsable ? .success(outputFileURL) : .failure(error ?? CaptureSession.Failure.notRecording)
        let waiting = state.withLock { state -> CheckedContinuation<URL, any Error>? in
            state.result = result
            defer { state.waiting = nil }
            return state.waiting
        }
        waiting?.resume(with: result)
    }
}

/// Turns each viewfinder frame into a picture the screen can draw.
private nonisolated final class FrameRelay: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    let queue = DispatchQueue(label: "com.retrosnap.vintagecamera.frames", qos: .userInteractive)
    private let onFrame: @Sendable (CGImage) -> Void

    init(onFrame: @escaping @Sendable (CGImage) -> Void) {
        self.onFrame = onFrame
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let buffer = sampleBuffer.imageBuffer else { return }
        if let image = buffer.cgImage {
            onFrame(image)
        }
    }
}

/// Collects one photo from the output's callbacks and hands it to whoever is waiting.
/// The output calls these one at a time, so the state needs no lock.
private nonisolated final class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let fileExtension: String
    private var continuation: CheckedContinuation<CapturedPhoto, any Error>?
    private var data: Data?

    init(fileExtension: String, continuation: CheckedContinuation<CapturedPhoto, any Error>) {
        self.fileExtension = fileExtension
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        data = photo.fileDataRepresentation()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        if let error {
            continuation?.resume(throwing: error)
        } else if let data {
            continuation?.resume(returning: CapturedPhoto(data: data, fileExtension: fileExtension))
        } else {
            continuation?.resume(throwing: CaptureSession.Failure.noPicture)
        }
        continuation = nil
    }
}
