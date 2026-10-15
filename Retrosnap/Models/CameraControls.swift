import Foundation

nonisolated enum CaptureMode: Hashable, CaseIterable, Sendable {
    case photo
    case video

    /// The segment's title on the camera.
    var title: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        }
    }
}

nonisolated enum FlashMode: String, Hashable, Sendable {
    case auto
    case on
    case off

    /// Auto, then on, then off, then round again.
    var next: FlashMode {
        switch self {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
    }
}

/// What the shutter looks like: the cream button, the red record dot, or the stop square.
nonisolated enum ShutterAppearance: Hashable, Sendable {
    case photo
    case video
    case recording
}

/// A message under the top controls. Shooting keeps working while it is up.
nonisolated enum CameraBanner: Hashable, Sendable {
    case library
    case storage
}

/// A reason the viewfinder cannot show anything.
nonisolated enum CameraBlock: Hashable, Sendable {
    case denied
    case busy
}

/// Copy for a banner or a blocked state: one title, one sentence, one action.
nonisolated struct CameraNotice: Hashable, Sendable {
    let title: String
    let message: String
    let actionTitle: String
}

nonisolated enum SwipeDirection: Hashable, Sendable {
    case left
    case right
}

extension SwipeDirection {
    /// How far a drag must travel sideways before it is a swipe and not a tap.
    nonisolated static let threshold: CGFloat = 40

    /// The swipe a drag of this sideways travel makes, or nil when it is too short to be one.
    nonisolated init?(translation width: CGFloat) {
        guard abs(width) > Self.threshold else { return nil }
        self = width < 0 ? .left : .right
    }

    /// Left steps on to the next, right back to the previous.
    nonisolated var step: Int {
        self == .left ? 1 : -1
    }
}

extension CameraBanner {
    /// The copy for this banner; `photosLeft` fills in the storage one.
    nonisolated func notice(photosLeft: Int) -> CameraNotice {
        switch self {
        case .library:
            CameraNotice(
                title: "Saving inside RetroSnap only",
                message: "Allow Photos access to also save to your library.",
                actionTitle: "Allow"
            )
        case .storage:
            CameraNotice(
                title: "Your phone is almost full",
                message: "About \(photosLeft) photos left. Free up space to keep shooting.",
                actionTitle: "Manage"
            )
        }
    }
}

extension CameraBlock {
    /// The copy for this blocked state.
    nonisolated var notice: CameraNotice {
        switch self {
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
        }
    }
}
