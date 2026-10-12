import Foundation
@testable import Retrosnap

/// A camera whose captures finish only when the test says so, and that remembers what it was asked.
@MainActor
final class CameraSpy: CameraServicing {
    /// One request to zoom.
    struct Zoom: Equatable {
        let factor: Double
        let smoothly: Bool
    }

    var availability = CameraAvailability.ready
    var playsSystemShutterSound = false
    var isSwitching = false
    /// A phone with an ultra-wide beside its main lens.
    var zoom = CameraZoom(factor: 1, range: 0.5...10, stops: [0.5, 1, 2])
    private(set) var zooms: [Zoom] = []
    private(set) var startedFacings: [CameraFacing] = []
    private(set) var startedModes: [CaptureMode] = []
    private(set) var stopCount = 0
    private(set) var shots: [Shot] = []
    private(set) var recordings: [Shot] = []
    private(set) var finishedSeconds: [Int] = []
    private(set) var recoverCount = 0
    private var captureCompletion: (@MainActor (Photo?) -> Void)?
    private var recoverCompletion: (@MainActor () -> Void)?

    func scene(for facing: CameraFacing) -> PhotoImage {
        .live
    }

    func start(facing: CameraFacing, mode: CaptureMode) {
        startedFacings.append(facing)
        startedModes.append(mode)
    }

    func stop() {
        stopCount += 1
    }

    func setZoom(_ factor: Double, smoothly: Bool) {
        zooms.append(Zoom(factor: factor, smoothly: smoothly))
        zoom.factor = zoom.clamped(factor)
    }

    func capturePhoto(_ shot: Shot, completion: @escaping @MainActor (Photo?) -> Void) {
        shots.append(shot)
        captureCompletion = completion
    }

    func startRecording(_ shot: Shot) {
        recordings.append(shot)
    }

    func finishRecording(seconds: Int, completion: @escaping @MainActor (Photo?) -> Void) {
        finishedSeconds.append(seconds)
        captureCompletion = completion
    }

    func recover(completion: @escaping @MainActor () -> Void) {
        recoverCount += 1
        recoverCompletion = completion
    }

    /// The pending photo or clip lands in the library.
    func deliver(_ photo: Photo) {
        captureCompletion?(photo)
        captureCompletion = nil
    }

    /// The pending photo or clip could not be taken.
    func fail() {
        captureCompletion?(nil)
        captureCompletion = nil
    }

    /// The camera is usable again.
    func comeBack() {
        availability = .ready
        recoverCompletion?()
        recoverCompletion = nil
    }
}
