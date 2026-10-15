import SwiftUI

/// The round button beside the chip: the zoom as a number. A tap steps through the lenses; a pinch on the
/// viewfinder moves it freely.
struct ZoomButton: View {
    let viewModel: CameraViewModel

    var body: some View {
        let visible = viewModel.isZoomVisible
        Button(action: viewModel.zoomTapped) {
            Text(viewModel.zoomTitle)
                .rsText(.chip.tabularDigits())
                .foregroundStyle(viewModel.isZoomed ? RSColor.amber : RSColor.paper)
                .frame(width: 44, height: 44)
                .glass(cornerRadius: 22, tint: RSColor.glass(0.5), visibility: visible ? 1 : 0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .animation(RSMotion.fade, value: visible)
        .accessibilityLabel(viewModel.zoomLabel)
        .accessibilityHidden(!visible)
    }
}
