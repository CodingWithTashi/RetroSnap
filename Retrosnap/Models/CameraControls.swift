import Foundation

nonisolated enum CaptureMode: Hashable, Sendable {
    case photo
    case video
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
