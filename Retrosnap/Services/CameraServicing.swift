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

/// The camera hardware. In v1 the mock serves a still scene per lens and turns it into library items.
protocol CameraServicing: AnyObject {
    var availability: CameraAvailability { get }
    /// What the lens currently sees.
    func scene(for facing: CameraFacing) -> SampleImage
    func capturePhoto(style: CameraStyle, facing: CameraFacing) -> Photo
    func finishRecording(seconds: Int, style: CameraStyle, facing: CameraFacing) -> Photo
    /// Tries to get the camera back after it was denied or busy.
    func recover()
}
