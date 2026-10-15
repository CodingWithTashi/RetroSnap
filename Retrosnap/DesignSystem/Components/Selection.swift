import SwiftUI

/// Two or three options in a pill: Photo/Video over the viewfinder, print sizes on a card.
struct SegmentedPill<Value: Hashable>: View {
    enum Style {
        /// Glass over the viewfinder.
        case glass
        /// Inset in a card.
        case inset
    }

    let options: [(value: Value, title: String)]
    let selection: Value
    var style = Style.glass
    let onSelect: (Value) -> Void

    private var segmentPadding: CGFloat { style == .glass ? 16 : 12 }
    private var cornerRadius: CGFloat { style == .glass ? 20 : 18 }

    var body: some View {
        let segments = HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    onSelect(option.value)
                } label: {
                    Text(option.title)
                        .rsText(.chip)
                        .foregroundStyle(isSelected ? RSColor.onPaper : RSColor.paper)
                        .padding(.horizontal, segmentPadding)
                        .frame(height: 32)
                        .background(isSelected ? RSColor.paper : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .animation(RSMotion.selection, value: selection)

        switch style {
        case .glass:
            segments.glass(cornerRadius: cornerRadius)
        case .inset:
            segments.background(RSColor.ink, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// A selectable chip: edit tools, collage borders.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    /// A colour dot before the title.
    var swatch: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let swatch {
                    Circle()
                        .fill(swatch)
                        .overlay { Circle().strokeBorder(Color(hex: 0x80786E, opacity: 0.6), lineWidth: 1.5) }
                        .frame(width: 20, height: 20)
                }
                Text(title).rsText(.chip)
            }
            .foregroundStyle(isSelected ? RSColor.onPaper : RSColor.paper)
            .padding(.leading, swatch == nil ? 13 : 8)
            .padding(.trailing, swatch == nil ? 13 : 14)
            .frame(height: 36)
            .background(isSelected ? RSColor.paper : RSColor.raised, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(RSMotion.choice, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The 51x31 switch, drawn to the design so it looks the same on every iOS version.
struct RSSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? RSColor.amber : RSColor.toggleOff)
            .frame(width: 51, height: 31)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                    .offset(x: isOn ? 22 : 2)
            }
            .animation(RSMotion.knob, value: isOn)
            .accessibilityHidden(true)
    }
}
