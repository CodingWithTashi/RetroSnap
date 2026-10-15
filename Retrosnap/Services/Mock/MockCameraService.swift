#if DEBUG
import Foundation
import Observation
import UIKit

/// A camera that "sees" one still scene per lens and delivers its shots at once.
/// Given a library folder, it files each shot there as a real picture, the way the device camera does.
@Observable
final class MockCameraService: CameraServicing {
    private(set) var availability: CameraAvailability
    let playsSystemShutterSound = false
    /// A still scene is swapped for the other at once.
    let isSwitching = false
    /// One lens, like the phone the simulator stands in for.
    private(set) var zoom = CameraZoom(factor: 1, range: 1...5, stops: [1, 2])

    @ObservationIgnored private let clock: any DateProviding
    @ObservationIgnored private let library: PhotoLibraryFolder?
    @ObservationIgnored private var facing = CameraFacing.back
    /// What the clip being recorded was started with.
    @ObservationIgnored private var recording: Shot?

    init(clock: any DateProviding, availability: CameraAvailability = .ready, library: PhotoLibraryFolder? = nil) {
        self.clock = clock
        self.availability = availability
        self.library = library
    }

    func scene(for facing: CameraFacing) -> PhotoImage {
        facing == .back ? .sceneBack : .sceneFront
    }

    func start(facing: CameraFacing, mode: CaptureMode) {
        guard facing != self.facing else { return }
        self.facing = facing
        zoom.factor = 1
    }

    func stop() {}

    func setZoom(_ factor: Double, smoothly: Bool) {
        zoom.factor = zoom.clamped(factor)
    }

    func capturePhoto(_ shot: Shot, completion: @escaping @MainActor (Photo?) -> Void) {
        var photo = capturePhoto(style: shot.style, facing: shot.facing)
        photo.location = shot.location
        completion(photo)
    }

    func startRecording(_ shot: Shot) {
        recording = shot
    }

    func finishRecording(seconds: Int, completion: @escaping @MainActor (Photo?) -> Void) {
        guard let shot = recording else {
            completion(nil)
            return
        }
        recording = nil
        var clip = finishRecording(seconds: seconds, style: shot.style, facing: shot.facing)
        clip.location = shot.location
        completion(clip)
    }

    func recover(completion: @escaping @MainActor () -> Void) {
        availability = .ready
        completion()
    }

    /// The photo this camera takes, without waiting.
    func capturePhoto(style: CameraStyle, facing: CameraFacing) -> Photo {
        let id = UUID().uuidString
        return Photo(id: id, image: shot(of: facing, id: id), camera: style, capturedAt: clock.now, isJustCaptured: true)
    }

    /// The clip this camera records, without waiting.
    func finishRecording(seconds: Int, style: CameraStyle, facing: CameraFacing) -> Photo {
        Photo(
            id: UUID().uuidString, image: scene(for: facing), camera: style, capturedAt: clock.now,
            isJustCaptured: true, videoSeconds: seconds
        )
    }

    /// The scene itself, or a copy of it filed in the library when there is one.
    private func shot(of facing: CameraFacing, id: Photo.ID) -> PhotoImage {
        let scene = scene(for: facing)
        guard let library, case .sample(let sample) = scene,
              let original = UIImage(named: sample.full)?.jpegData(compressionQuality: 0.95),
              let filed = try? library.store(original: original, id: id, fileExtension: "jpg")
        else { return scene }
        return filed
    }
}
#endif
