import SwiftUI

/// Share, Edit, Print, Collage, Delete under a photo.
struct PhotoActionRow: View {
    enum Style {
        /// Icons on round surface chips, used on the result screen.
        case chips
        /// Bare icons spread across the width, used in the viewer.
        case plain
    }

    let style: Style
    let onAction: (PhotoAction) -> Void

    var body: some View {
        switch style {
        case .chips:
            HStack(spacing: 10) {
                ForEach(PhotoAction.allCases) { action in
                    button(action) {
                        VStack(spacing: 6) {
                            RSIconView(action.icon, size: 22, lineWidth: 1.8)
                                .frame(width: 48, height: 48)
                                .background(RSColor.surface, in: Circle())
                            Text(action.label).rsText(.caption)
                        }
                        .frame(width: 62)
                    }
                }
            }
        case .plain:
            HStack(spacing: 0) {
                ForEach(PhotoAction.allCases) { action in
                    button(action) {
                        VStack(spacing: 6) {
                            RSIconView(action.icon, size: 24, lineWidth: 1.8)
                            Text(action.label).rsText(.caption)
                        }
                        .frame(width: 64, height: 60)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func button(_ action: PhotoAction, @ViewBuilder label: () -> some View) -> some View {
        Button {
            onAction(action)
        } label: {
            label()
                .foregroundStyle(action.isDestructive ? RSColor.destructive : RSColor.paper)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
    }
}
