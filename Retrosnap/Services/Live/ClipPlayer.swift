import AVFoundation
import Foundation
import Observation

/// Plays a clip from the library. The sound goes out as usual; the pictures are handed to the feed one by one.
@Observable
final class ClipPlayer: ClipPlaying {
    private static let frameInterval = CMTime(value: 1, timescale: 30)

    @ObservationIgnored let frames = FrameFeed()
    private(set) var openFile: String?
    private(set) var isPlaying = false

    @ObservationIgnored private let folder: PhotoLibraryFolder
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var output: AVPlayerItemVideoOutput?
    @ObservationIgnored private var frameObserver: Any?
    @ObservationIgnored private var endWatch: Task<Void, Never>?
    @ObservationIgnored private var rateWatch: Task<Void, Never>?

    init(folder: PhotoLibraryFolder) {
        self.folder = folder
    }

    func play(_ videoFile: String) {
        if openFile != videoFile {
            open(videoFile)
        }
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        pause()
        if let frameObserver {
            player?.removeTimeObserver(frameObserver)
        }
        endWatch?.cancel()
        rateWatch?.cancel()
        frameObserver = nil
        endWatch = nil
        rateWatch = nil
        player = nil
        output = nil
        openFile = nil
        frames.show(nil)
    }

    private func open(_ videoFile: String) {
        stop()
        openFile = videoFile
        let asset = AVURLAsset(url: folder.url(for: videoFile))
        let item = AVPlayerItem(asset: asset)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        item.add(output)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.output = output

        frameObserver = player.addPeriodicTimeObserver(forInterval: Self.frameInterval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.showFrame(at: time)
            }
        }
        // The system pauses a player by itself: the app leaves the screen, a call comes in, headphones come out.
        rateWatch = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVPlayer.rateDidChangeNotification, object: player) {
                guard let self, self.player === player else { return }
                isPlaying = player.rate != 0
            }
        }
        endWatch = Task { [weak self] in
            // A recording is stored sideways with a rotation beside it; the composition turns its frames upright.
            item.videoComposition = try? await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
            for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item) {
                self?.stop()
            }
        }
    }

    private func showFrame(at time: CMTime) {
        guard let output, output.hasNewPixelBuffer(forItemTime: time),
              let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        else { return }
        if let image = buffer.cgImage {
            frames.show(image)
        }
    }
}
