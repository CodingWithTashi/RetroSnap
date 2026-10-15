import SwiftUI

/// The hero: an 84pt amber ring around a cream button that becomes record, then stop.
struct ShutterButton: View {
    let appearance: ShutterAppearance
    /// Held slightly pressed, as on the capture board.
    var isPosed = false
    var isDimmed = false
    let label: String
    /// Called as a finger comes down on the button.
    var onPress: () -> Void = {}
    let action: () -> Void

    private var innerSize: CGFloat {
        switch appearance {
        case .photo: 66
        case .video: 62
        case .recording: 30
        }
    }

    private var innerRadius: CGFloat {
        appearance == .recording ? 8 : innerSize / 2
    }

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: innerRadius, style: .circular)
                .fill(innerFill)
                .frame(width: innerSize, height: innerSize)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .scaleEffect(isPosed ? 0.9 : 1)
                .animation(RSMotion.shutterMorph, value: appearance)
                .frame(width: 84, height: 84)
                .background(.black.opacity(0.12), in: Circle())
                .overlay { Circle().strokeBorder(RSColor.amber, lineWidth: 4) }
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.92, onPress: onPress))
        .opacity(isDimmed ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    private var innerFill: AnyShapeStyle {
        if appearance == .photo {
            // radial-gradient(circle at 38% 30%, #FFFDF8, #EEE6D9 55%, #CDBFAA), sized to the farthest corner,
            // with the top light and pressed-in bottom shadow from the design.
            AnyShapeStyle(
                RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0xFFFDF8), location: 0),
                        .init(color: Color(hex: 0xEEE6D9), location: 0.55),
                        .init(color: Color(hex: 0xCDBFAA), location: 1),
                    ],
                    center: UnitPoint(x: 0.38, y: 0.30),
                    startRadius: 0,
                    endRadius: 61.7
                )
                .pressedIn()
            )
        } else {
            AnyShapeStyle(
                RSColor.record
                    .pressedIn()
            )
        }
    }
}

private extension ShapeStyle {
    /// The design's light along the top of the inner shape and its pressed-in shadow along the bottom.
    func pressedIn() -> some ShapeStyle {
        shadow(.inner(color: .black.opacity(0.18), radius: 3, y: -3))
            .shadow(.inner(color: .white.opacity(0.5), radius: 1, y: 2))
    }
}
