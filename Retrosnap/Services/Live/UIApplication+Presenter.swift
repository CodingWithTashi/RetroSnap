import UIKit

extension UIApplication {
    /// The window the user is looking at.
    var frontWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    /// The view controller on top of that window, which is the one that can present a system sheet.
    var topViewController: UIViewController? {
        var top = frontWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
