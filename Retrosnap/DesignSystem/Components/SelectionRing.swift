import SwiftUI

extension View {
    /// The amber ring 2.5pt outside a selected card or tile; hidden rather than removed, so it fades with the selection.
    func selectionRing(cornerRadius: CGFloat, isSelected: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius + 2.5)
                .strokeBorder(RSColor.amber, lineWidth: 2.5)
                .padding(-2.5)
                .opacity(isSelected ? 1 : 0)
        }
    }
}
