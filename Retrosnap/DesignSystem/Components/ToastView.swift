import SwiftUI

/// The pill that confirms something at the top of the screen, optionally with one action.
struct ToastView: View {
    let text: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .rsText(.text(15, .semibold))
                .foregroundStyle(RSColor.paper)
                .padding(.trailing, actionTitle == nil ? 10 : 0)
            if let actionTitle {
                PaperPillButton(title: actionTitle, action: action)
            }
        }
        .fixedSize()
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 44)
        .background {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Color(hex: 0x26231F, opacity: 0.92))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
        .accessibilityElement(children: .contain)
    }
}

/// A message with one action that sits under the camera's top controls.
struct BannerView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .rsText(.text(15, .semibold))
                    .foregroundStyle(RSColor.paper)
                Text(message)
                    .rsText(.caption.lineHeight(1.3).multiline())
                    .foregroundStyle(RSColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PaperPillButton(title: actionTitle, height: 36, horizontalPadding: 14, action: action)
        }
        .padding(.leading, 16)
        .padding([.trailing, .vertical], 12)
        .glass(cornerRadius: 20, tint: RSColor.glass(0.72))
    }
}
