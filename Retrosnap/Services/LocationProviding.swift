import Foundation

/// Where the phone is, for tagging shots. Used only while "Location on photos" is on.
protocol LocationProviding: AnyObject {
    /// iOS currently lets the app use location.
    var isAllowed: Bool { get }
    /// The latest fix since `start()`, or nil when there is none.
    var current: PhotoLocation? { get }
    /// Shows the when-in-use prompt if it has never been answered. The completion says whether location may be used.
    func requestAccess(completion: @escaping @MainActor (Bool) -> Void)
    /// Begins following the phone's position, if allowed.
    func start()
    func stop()
}
