import Foundation

/// Plays a clip's movie frame by frame, so the screen can draw the look over it as it does over the viewfinder.
protocol ClipPlaying: AnyObject {
    /// The frames of the movie that is open.
    var frames: FrameFeed { get }
    /// The movie that is open, playing or paused, by file name; nil when none is.
    var openFile: String? { get }
    var isPlaying: Bool { get }
    /// Plays this movie from where it stands, opening it first unless it is the one already open.
    func play(_ videoFile: String)
    func pause()
    /// Closes the movie.
    func stop()
}
