import SwiftUI

/// The home screen: a full-bleed viewfinder with the look applied live, and five controls around the shutter.
struct CameraView: View {
    let viewModel: CameraViewModel
    let stamp: PhotoStampText
    /// What the viewfinder showed as the shutter last fired. It stands for the shot until the camera delivers it.
    /// Nil while the camera shows a still scene, which is its own shot.
    let shotFrames: FrameFeed?
    @Environment(\.designLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The camera's own frames; nil while it shows a still scene.
    @Environment(\.liveFrames) private var viewfinderFrames
    @GestureState private var isTouchingViewfinder = false
    @GestureState private var isPinching = false
    /// The touch on the viewfinder became a pinch, so the fingers lifting is neither a tap nor a swipe.
    @State private var touchWasPinch = false

    var body: some View {
        GlassContainer {
            backdrop
        } content: {
            controls
        }
        .overlay {
            if !reduceMotion {
                CaptureEffects(shutterCount: viewModel.shutterCount, mode: viewModel.mode, scene: viewModel.scene)
                    .environment(\.liveFrames, shotFrames)
            }
        }
        .background(.black)
        .ignoresSafeArea()
        .onAppear(perform: viewModel.appeared)
        .onDisappear(perform: viewModel.disappeared)
        .onChange(of: isTouchingViewfinder) { _, isTouching in
            if isTouching {
                touchWasPinch = false
            }
        }
        .onChange(of: isPinching) { _, isPinching in
            if !isPinching {
                viewModel.viewfinderPinchEnded()
            }
        }
    }

    // MARK: Backdrop (everything the glass controls blur)

    private var backdrop: some View {
        ZStack {
            Color.black
            if viewModel.block == nil {
                // The picture fades in with the camera's first frame, and goes out of focus while the camera
                // changes lens or mode, so neither arrives as a jump.
                ViewfinderPicture(
                    image: viewModel.scene, camera: viewModel.style, stamp: stamp, magnification: viewModel.sceneMagnification
                )
                    .blur(radius: viewModel.isViewfinderSettling ? 18 : 0, opaque: true)
                    .opacity(viewfinderFrames?.hasFrame == false ? 0 : 1)
                    .animation(RSMotion.crossFade, value: viewModel.isViewfinderSettling)
                    .animation(RSMotion.crossFade, value: viewfinderFrames?.hasFrame)
            } else {
                BlockedBackdrop()
            }
            if viewModel.isPosed {
                Color.white.opacity(0.55)
            }
            ViewfinderScrims()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isTouchingViewfinder) { _, isTouching, _ in
                    isTouching = true
                }
                .onEnded { value in
                    guard !touchWasPinch else { return }
                    if let direction = SwipeDirection(translation: value.translation.width) {
                        viewModel.viewfinderSwiped(direction)
                    } else {
                        viewModel.viewfinderTapped()
                    }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .updating($isPinching) { _, isPinching, _ in
                    isPinching = true
                }
                .onChanged { value in
                    touchWasPinch = true
                    viewModel.viewfinderPinched(value.magnification)
                }
        )
        .accessibilityElement()
        .accessibilityLabel(viewModel.viewfinderLabel)
        .accessibilityHint("Swipe up or down to change camera")
        .accessibilityAdjustableAction { direction in
            viewModel.viewfinderSwiped(SwipeDirection(direction))
        }
    }

    // MARK: Controls

    private var controls: some View {
        ZStack {
            if let block = viewModel.blockContent {
                BlockedMessage(notice: block, action: viewModel.blockActionTapped)
            }
            if viewModel.countdown > 0 {
                countdownLabel
            }

            CameraTopBar(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, layout.top(56))
                .frame(maxHeight: .infinity, alignment: .top)

            if let banner = viewModel.bannerContent {
                BannerView(
                    title: banner.title, message: banner.message, actionTitle: banner.actionTitle,
                    action: viewModel.bannerActionTapped
                )
                .padding(.horizontal, 16)
                .padding(.top, layout.top(112))
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
            }

            CameraChooserControls(viewModel: viewModel) {
                // Centred over the lens button below it.
                ZoomButton(viewModel: viewModel)
                    .padding(.trailing, 36)
                    .padding(.bottom, layout.bottom(146))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            } bottomBar: {
                bottomBar
            }
        }
        .animation(RSMotion.fade, value: viewModel.banner)
    }

    private var bottomBar: some View {
        HStack {
            galleryButton

            Spacer(minLength: 0)

            ShutterButton(
                appearance: viewModel.shutterAppearance,
                isPosed: viewModel.isPosed,
                isDimmed: !viewModel.isShutterEnabled,
                label: viewModel.shutterLabel,
                onPress: viewModel.shutterPressed,
                action: viewModel.shutterTapped
            )

            Spacer(minLength: 0)

            Button(action: viewModel.flipTapped) {
                RSIconView(.flip, size: 24, lineWidth: 1.8)
                    .foregroundStyle(RSColor.paper)
                    .frame(width: 56, height: 56)
                    .glass(cornerRadius: 28, tint: RSColor.glass(0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch to front or back camera")
        }
        .frame(height: 84)
    }

    private var countdownLabel: some View {
        Text("\(viewModel.countdown)")
            .font(.system(size: 120, weight: .heavy, design: .rounded))
            .foregroundStyle(RSColor.paper)
            .shadow(color: .black.opacity(0.5), radius: 15, y: 4)
            .frame(height: 120)
            .padding(.top, layout.top(330))
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
            .accessibilityLabel("\(viewModel.countdown)")
    }

    private var galleryButton: some View {
        Button(action: viewModel.galleryTapped) {
            ZStack {
                RSColor.raised
                if let look = viewModel.pendingShot {
                    // The shot on its way, as the viewfinder saw it.
                    PhotoLookView(image: viewModel.scene, camera: look, usesThumbnail: true)
                        .environment(\.liveFrames, shotFrames)
                } else if let photo = viewModel.lastPhoto {
                    PhotoLookView(photo: photo, usesThumbnail: true)
                }
            }
            .frame(width: CameraControlMetrics.galleryButtonSize, height: CameraControlMetrics.galleryButtonSize)
            .clipShape(RoundedRectangle(cornerRadius: CameraControlMetrics.galleryButtonRadius))
            .overlay { RoundedRectangle(cornerRadius: CameraControlMetrics.galleryButtonRadius).strokeBorder(RSColor.paper.opacity(0.85), lineWidth: 2) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open photos")
    }
}
