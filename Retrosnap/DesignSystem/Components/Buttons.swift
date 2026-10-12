import SwiftUI

/// Scales the label down while pressed, like the prototype's `style-active`.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    /// Called as a finger comes down, ahead of the tap that follows when it lifts.
    var onPress: () -> Void = {}

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(RSMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    onPress()
                }
            }
    }
}

/// The one amber button a screen may have.
struct PrimaryButton: View {
    let title: String
    var icon: RSIcon?
    var height: CGFloat = 56
    /// Fixed side padding instead of filling the width.
    var horizontalPadding: CGFloat?
    var isDimmed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    RSIconView(icon, size: 20, lineWidth: 2.2)
                }
                Text(title).rsText(.label)
            }
            .foregroundStyle(RSColor.onAmber)
            .padding(.horizontal, horizontalPadding ?? 0)
            .frame(maxWidth: horizontalPadding == nil ? .infinity : nil)
            .frame(height: height)
            .background(RSColor.amber, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isDimmed ? 0.45 : 1)
    }
}

/// Quiet surface button from the design system board.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .rsText(.label)
                .foregroundStyle(RSColor.paper)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RSColor.raised, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Text-only button: "Not now", "Cancel", "Reset".
struct QuietButton: View {
    let title: String
    var style = RSTextStyle.bodySmall
    var horizontalPadding: CGFloat = 16
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .rsText(style)
                .foregroundStyle(RSColor.secondaryText)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Round icon button on a solid fill: close, back, settings.
struct CircleIconButton: View {
    let icon: RSIcon
    let label: String
    var iconSize: CGFloat = 18
    var lineWidth: CGFloat = 2.2
    var diameter: CGFloat = 44
    var fill = RSColor.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RSIconView(icon, size: iconSize, lineWidth: lineWidth)
                .foregroundStyle(RSColor.paper)
                .frame(width: diameter, height: diameter)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Small pill button on paper: toast actions and banner actions.
struct PaperPillButton: View {
    let title: String
    var height: CGFloat = 32
    var horizontalPadding: CGFloat = 12
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .rsText(.chip)
                .foregroundStyle(RSColor.onPaper)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .background(RSColor.paper, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
