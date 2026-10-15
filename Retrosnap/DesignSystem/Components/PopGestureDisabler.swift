import SwiftUI
import UIKit

/// Every screen has its own back or close button and several use horizontal swipes for content,
/// so the navigation stack's swipe-to-go-back gestures are switched off.
struct PopGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            disable()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            disable()
        }

        private func disable() {
            guard let navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
            if #available(iOS 26.0, *) {
                navigationController.interactiveContentPopGestureRecognizer?.isEnabled = false
            }
        }
    }
}
