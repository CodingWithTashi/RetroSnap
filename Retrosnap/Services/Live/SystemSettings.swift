import UIKit

/// The app's own page in the Settings app, where iOS keeps its permissions.
enum SystemSettings {
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// A web page or a new email, handed to whichever app opens it.
enum ExternalLink {
    /// - Parameter completion: Whether anything opened it. A phone with no mail app set up cannot start an email.
    static func open(_ url: URL, completion: @escaping @MainActor (Bool) -> Void) {
        UIApplication.shared.open(url) { isOpened in
            Task { @MainActor in
                completion(isOpened)
            }
        }
    }
}
