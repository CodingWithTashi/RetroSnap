import SwiftUI

/// A pick from the library where the viewfinder would be: the whole picture under the look, the camera strip to
/// choose another, and the shutter to develop it. The same controls as the camera, in the same places.
struct DevelopView: View {
    @State private var viewModel: DevelopViewModel
    @Environment(\.designLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: DevelopViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GlassContainer {
            backdrop
        } content: {
            controls
        }
        .overlay {
            if !reduceMotion {
                ShutterFlash(trigger: viewModel.shutterCount)
            }
        }
        .background(.black)
        .ignoresSafeArea()
        .onDisappear(perform: viewModel.disappeared)
    }

    // MARK: Backdrop (everything the glass controls blur)

    private var backdrop: some View {
        ZStack {
            Color.black
            // The whole picture, in its own shape: what is on the screen is what gets developed.
            ViewfinderPicture(
                image: viewModel.picture, camera: viewModel.style, stamp: viewModel.stamp,
                videoDuration: viewModel.badgeText
            )
            .environment(\.liveFrames, viewModel.movieFrames)
            .aspectRatio(viewModel.draft.aspectRatio, contentMode: .fit)
            ViewfinderScrims()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    if abs(value.translation.width) > 40 {
                        viewModel.pictureSwiped(value.translation.width < 0 ? .left : .right)
                    } else {
                        viewModel.pictureTapped()
                    }
                }
        )
        .accessibilityElement()
        .accessibilityLabel(viewModel.pictureLabel)
        .accessibilityHint("Swipe left or right to change camera")
        .accessibilityAdjustableAction { direction in
            viewModel.pictureSwiped(direction == .increment ? .left : .right)
        }
    }

    // MARK: Controls

    private var controls: some View {
        ZStack {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, layout.top(56))
                .frame(maxHeight: .infinity, alignment: .top)

            CameraChip(
                style: viewModel.style, isVisible: viewModel.isChipVisible, isStripOpen: viewModel.isStripVisible,
                label: viewModel.chipLabel, action: viewModel.chipTapped
            )
            .padding(.bottom, layout.bottom(146))
            .frame(maxHeight: .infinity, alignment: .bottom)

            CameraStrip(
                style: viewModel.style, isVisible: viewModel.isStripVisible, isFirstRun: false,
                title: viewModel.stripTitle, subtitle: viewModel.stripSubtitle,
                onClose: viewModel.closeStripTapped, onPick: viewModel.pick
            )
            .padding(.horizontal, 8)
            .padding(.bottom, layout.bottom(136))
            .frame(maxHeight: .infinity, alignment: .bottom)

            bottomBar
                .padding(.horizontal, 30)
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

    private var topBar: some View {
        HStack {
            GlassIconButton(icon: .close, label: "Cancel", iconSize: 20, lineWidth: 2.2, action: viewModel.cancelTapped)
            Spacer(minLength: 0)
            Text(viewModel.kindTitle)
                .rsText(.labelSmall.tabularDigits())
                .foregroundStyle(RSColor.paper)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .glass(cornerRadius: 20)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            GlassIconButton(icon: .photos, label: "Choose another", action: viewModel.chooseAnotherTapped)
                .opacity(viewModel.isImporting ? 0.45 : 1)
        }
        .frame(height: 44)
    }

    private var bottomBar: some View {
        HStack {
            Spacer(minLength: 0)
            ShutterButton(
                appearance: .photo,
                isDimmed: viewModel.isDeveloping,
                label: viewModel.shutterLabel,
                onPress: viewModel.shutterPressed,
                action: viewModel.shutterTapped
            )
            Spacer(minLength: 0)
        }
        .frame(height: 84)
    }
}
