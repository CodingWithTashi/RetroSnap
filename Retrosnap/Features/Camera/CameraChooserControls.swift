import SwiftUI

/// Where the chooser sits on the screen, and the gallery button the shutter's fly-in lands on.
nonisolated enum CameraControlMetrics {
    /// The bottom bar's side inset: where the gallery button starts.
    static let bottomBarInset: CGFloat = 30
    static let galleryButtonSize: CGFloat = 56
    static let galleryButtonRadius: CGFloat = 16
}

/// The chooser the camera and develop screens share. The body is a list, not a stack: each part is its own layer
/// in the screen's ZStack, in this order: chip, accessory, strip, bottom bar, name.
struct CameraChooserControls<Model: CameraChoosing, Accessory: View, BottomBar: View>: View {
    let viewModel: Model
    /// Between the chip and the strip.
    let accessory: Accessory
    let bottomBar: BottomBar
    @Environment(\.designLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: Model, @ViewBuilder accessory: () -> Accessory, @ViewBuilder bottomBar: () -> BottomBar) {
        self.viewModel = viewModel
        self.accessory = accessory()
        self.bottomBar = bottomBar()
    }

    var body: some View {
        CameraChip(
            style: viewModel.style, isVisible: viewModel.isChipVisible, isStripOpen: viewModel.isStripVisible,
            label: viewModel.chipLabel, action: viewModel.chipTapped
        )
        .padding(.bottom, layout.bottom(146))
        .frame(maxHeight: .infinity, alignment: .bottom)

        accessory

        CameraStrip(
            style: viewModel.style, isVisible: viewModel.isStripVisible, isFirstRun: viewModel.isFirstRun,
            title: viewModel.stripTitle, subtitle: viewModel.stripSubtitle,
            onClose: viewModel.closeStripTapped, onPick: viewModel.pick
        )
        .padding(.horizontal, 8)
        .padding(.bottom, layout.bottom(136))
        .frame(maxHeight: .infinity, alignment: .bottom)

        bottomBar
            .padding(.horizontal, CameraControlMetrics.bottomBarInset)
            .padding(.bottom, layout.bottom(40))
            .frame(maxHeight: .infinity, alignment: .bottom)

        if !reduceMotion {
            CameraNameLabel(name: viewModel.style.name, trigger: viewModel.styleChangeCount)
                .padding(.top, layout.top(120))
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
    }
}

extension CameraChooserControls where Accessory == EmptyView {
    init(viewModel: Model, @ViewBuilder bottomBar: () -> BottomBar) {
        self.init(viewModel: viewModel, accessory: { EmptyView() }, bottomBar: bottomBar)
    }
}
