import CoreGraphics
import Foundation

/// A picture's size in pixels, the way up it is shown.
nonisolated struct PixelSize: Hashable, Sendable, Codable {
    var width: Int
    var height: Int

    /// Width over height.
    var aspectRatio: CGFloat {
        guard width > 0, height > 0 else { return 3.0 / 4.0 }
        return CGFloat(width) / CGFloat(height)
    }
}
