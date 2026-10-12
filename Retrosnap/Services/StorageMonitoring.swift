import Foundation

protocol StorageMonitoring: AnyObject {
    /// The phone is almost full.
    var isLow: Bool { get }
    /// Roughly how many more photos fit.
    var photosLeft: Int { get }
    /// Space the app's photos take, as shown in Settings.
    var usedText: String { get }
    /// Measures again: after the library changes, and when the app comes back to the front.
    func refresh()
}
