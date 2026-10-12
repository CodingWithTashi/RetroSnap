import CoreGraphics
import Observation
import os

/// The newest frame of a moving picture, for the screen to draw: the camera's viewfinder, or a clip being played.
@Observable
final class FrameFeed {
    private(set) var frame: CGImage?
    /// Whether there is a picture yet. It changes when the first frame comes, where `frame` changes with every one.
    private(set) var hasFrame = false

    /// The frame waiting for the main actor. A newer one replaces it, so the screen never falls behind its source.
    @ObservationIgnored private nonisolated let waiting = OSAllocatedUnfairLock<CGImage?>(uncheckedState: nil)

    /// Shows a frame at once, or clears the picture with nil.
    func show(_ frame: CGImage?) {
        self.frame = frame
        if hasFrame != (frame != nil) {
            hasFrame = frame != nil
        }
    }

    /// Hands in a frame from any queue, as fast as they come.
    nonisolated func submit(_ image: CGImage) {
        let isFirstWaiting = waiting.withLockUnchecked { slot in
            defer { slot = image }
            return slot == nil
        }
        guard isFirstWaiting else { return }
        Task { @MainActor in
            show(waiting.withLockUnchecked { slot in
                defer { slot = nil }
                return slot
            })
        }
    }
}
