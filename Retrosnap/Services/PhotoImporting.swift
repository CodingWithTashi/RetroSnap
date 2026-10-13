import Foundation

/// What a trip to the Photos library came back with.
nonisolated enum ImportOutcome: Hashable, Sendable {
    /// The picker was closed with nothing chosen.
    case cancelled
    /// The pick could not be read or filed.
    case failed
    /// The pick, filed in the library folder as a photo that is not in the library yet. Its look is still to be
    /// chosen: whoever shows it sets `camera` first.
    case imported(Photo)
}

/// Brings a picture or a clip from the Photos library into the app's own library folder, through the system
/// picker. The pick is a draft: it is added to the library once a look has been chosen for it, or its files are
/// discarded.
protocol PhotoImporting: AnyObject {
    /// A pick is being copied in: between the picker closing and the completion.
    var isImporting: Bool { get }
    /// Shows the picker. The completion gets the pick, or says why there is none.
    func pick(completion: @escaping @MainActor (ImportOutcome) -> Void)
    /// Removes the files of a pick that is not going to be kept.
    func discard(_ draft: Photo)
}
