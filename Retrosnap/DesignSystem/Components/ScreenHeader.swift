import SwiftUI

/// The 44pt bar at the top of a pushed screen: something on the left, a centred title, something on the right.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(title)
                    .rsText(.label)
                    .foregroundStyle(RSColor.paper)
                if let subtitle {
                    Text(subtitle)
                        .rsText(.caption)
                        .foregroundStyle(RSColor.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            HStack {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .frame(height: 44)
    }
}

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
