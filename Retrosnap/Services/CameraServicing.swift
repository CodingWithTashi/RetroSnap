import Foundation

nonisolated enum CameraAvailability: Hashable, Sendable {
    case ready
    /// Camera permission is off.
    case denied
    /// Another app holds the camera.
    case busy
}

nonisolated enum CameraFacing: Hashable, Sendable {
    case back
    case front

    var flipped: CameraFacing {
        self == .back ? .front : .back
    }
}

/// What the shutter asks the camera for.
nonisolated struct Shot: Hashable, Sendable {
    var style: CameraStyle
    var facing: CameraFacing
    var flash: FlashMode
    /// Where the shot is taken, while "Location on photos" is on and there is a fix.
    var location: PhotoLocation?
}

/// The camera hardware: a still scene per lens in the mock, the capture session on a device.
/// A real capture finishes later, so results arrive through completions; the mock calls them at once.
protocol CameraServicing: AnyObject {
    var availability: CameraAvailability { get }
    /// iOS makes its own shutter sound for a capture here, so the app's click stays silent.
    var playsSystemShutterSound: Bool { get }
    /// The camera is changing lens or mode, and the viewfinder is between the old picture and the new one.
    var isSwitching: Bool { get }
    /// How far the lens in use can zoom, and where it is now. A lens that has just been switched to is at 1×.
    var zoom: CameraZoom { get }
    /// What the lens currently sees. A live picture shows the zoom by itself; a still one has to be enlarged to.
    func scene(for facing: CameraFacing) -> PhotoImage
    /// Zooms the lens in use, as far as it can go.
    /// - Parameter smoothly: Glide there, for a tap on the zoom button. A pinch follows the fingers at once instead.
    func setZoom(_ factor: Double, smoothly: Bool)
    /// Runs the camera on this lens, set up for photos or for video: when its screen appears, and again
    /// when the lens is flipped or the mode changes.
    func start(facing: CameraFacing, mode: CaptureMode)
    /// The camera screen is covered or gone.
    func stop()
    /// Takes a photo and files it in the library. The completion gets its record, or nil if it could not be taken.
    func capturePhoto(_ shot: Shot, completion: @escaping @MainActor (Photo?) -> Void)
    func startRecording(_ shot: Shot)
    /// Stops recording and files the clip in the library. `seconds` is the length the recording clock showed.
    /// The completion gets the clip's record, or nil if it could not be saved.
    func finishRecording(seconds: Int, completion: @escaping @MainActor (Photo?) -> Void)
    /// Tries to get the camera back after it was denied or busy. The completion runs once it is usable again.
    func recover(completion: @escaping @MainActor () -> Void)
}
