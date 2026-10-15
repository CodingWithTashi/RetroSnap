#if DEBUG
import Foundation

/// A player with nothing to play: the mock library's clips are stills.
final class MockClipPlayer: ClipPlaying {
    let frames = FrameFeed()
    let openFile: String? = nil
    let isPlaying = false

    func play(_ videoFile: String) {}

    func pause() {}

    func stop() {}
}
#endif
