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
