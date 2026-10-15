import SwiftUI

struct BlockedBackdrop: View {
    var body: some View {
        // radial-gradient(ellipse at 50% 40%, #221f1b, #0E0D0C 70%), sized to the farthest corner.
        GeometryReader { proxy in
            EllipticalGradient(
                stops: [
                    .init(color: Color(hex: 0x221F1B), location: 0),
                    .init(color: RSColor.ink, location: 0.7),
                    .init(color: RSColor.ink, location: 1),
                ],
                center: .center, startRadiusFraction: 0, endRadiusFraction: 0.7071
            )
            .frame(height: proxy.size.height * 1.2)
            .offset(y: -proxy.size.height * 0.2)
        }
        .clipped()
    }
}

struct BlockedMessage: View {
    let notice: CameraNotice
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            RSIconView(.cameraSlash, size: 32, lineWidth: 1.7)
                .foregroundStyle(RSColor.secondaryText)
                .frame(width: 72, height: 72)
                .background(RSColor.raised, in: Circle())
            Text(notice.title)
                .rsText(.heading.lineHeight(1.2))
                .foregroundStyle(RSColor.paper)
                .accessibilityAddTraits(.isHeader)
            Text(notice.message)
                .rsText(.bodySmall.lineHeight(1.4).multiline())
                .foregroundStyle(RSColor.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: notice.actionTitle, height: 48, horizontalPadding: 28, action: action)
                .padding(.top, 8)
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 180)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
