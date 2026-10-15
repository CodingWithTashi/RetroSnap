import AVFoundation
import CoreGraphics
import VideoToolbox

extension AVAsset {
    /// The first video track's size the way up it plays; nil without one.
    nonisolated func uprightVideoSize() async throws -> CGSize? {
        guard let track = try await loadTracks(withMediaType: .video).first else { return nil }
        let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
        let upright = CGRect(origin: .zero, size: size).applying(transform).size
        return CGSize(width: abs(upright.width), height: abs(upright.height))
    }
}

extension CVPixelBuffer {
    /// The frame as a picture the screen can draw.
    nonisolated var cgImage: CGImage? {
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &image)
        return image
    }
}
