import Foundation

/// Hands a shot to other apps through the system share sheet, with its look, stamp and edits baked in.
protocol PhotoSharing: AnyObject {
    func share(_ photo: Photo)
    /// Shares a collage as arranged, whether or not it has been saved.
    func share(_ collage: Collage)
}
