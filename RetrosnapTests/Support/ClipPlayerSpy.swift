import Foundation
@testable import Retrosnap

/// A clip player that only remembers what it was asked to do.
@MainActor
final class ClipPlayerSpy: ClipPlaying {
    let frames = FrameFeed()
    private(set) var isPlaying = false
    private(set) var openFile: String?
    private(set) var playedFiles: [String] = []

    func play(_ videoFile: String) {
        openFile = videoFile
        playedFiles.append(videoFile)
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        openFile = nil
    }

    /// The movie reaches its end by itself.
    func finish() {
        stop()
    }
}
