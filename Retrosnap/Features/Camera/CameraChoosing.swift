import Foundation

/// What the camera chooser reads from a screen's view model: the camera screen and the develop screen both
/// show the chip, the strip of cameras and the name, and drive them the same way.
protocol CameraChoosing: AnyObject {
    var style: CameraStyle { get }
    var isChipVisible: Bool { get }
    var isStripVisible: Bool { get }
    /// A requirement rather than only a default below, so the camera's own value is the one read.
    var isFirstRun: Bool { get }
    var stripTitle: String { get }
    var stripSubtitle: String { get }
    var styleChangeCount: Int { get }
    func chipTapped()
    func closeStripTapped()
    func pick(_ newStyle: CameraStyle)
}

extension CameraChoosing {
    /// Only the camera has a first launch.
    var isFirstRun: Bool { false }

    var chipLabel: String {
        "Camera: \(style.name). Change camera"
    }
}
