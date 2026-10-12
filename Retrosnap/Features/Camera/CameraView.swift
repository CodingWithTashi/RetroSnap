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
                viewfinder
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
            scrims
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isTouchingViewfinder) { _, isTouching, _ in
                    isTouching = true
                }
                .onEnded { value in
                    guard !touchWasPinch else { return }
                    if abs(value.translation.width) > 40 {
                        viewModel.viewfinderSwiped(value.translation.width < 0 ? .left : .right)
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
        .accessibilityLabel("Viewfinder, \(viewModel.style.name)")
        .accessibilityHint("Swipe up or down to change camera")
        .accessibilityAdjustableAction { direction in
            viewModel.viewfinderSwiped(direction == .increment ? .left : .right)
        }
    }

    private var viewfinder: some View {
        ZStack {
            PhotoLookView(
                image: viewModel.scene, camera: viewModel.style, stamp: stamp, stampBottom: 0.27, stampTop: 0.17,
                magnification: viewModel.sceneMagnification
            )
            .id(viewModel.style)
            .transition(.opacity)

            // Instant shoots square: the rest of the frame is dimmed.
            GeometryReader { proxy in
                let bar = max(0, (proxy.size.height - proxy.size.width) / 2)
                VStack(spacing: 0) {
                    Color(hex: 0x0A0908, opacity: 0.72).frame(height: bar)
                    Spacer(minLength: 0)
                    Color(hex: 0x0A0908, opacity: 0.72).frame(height: bar)
                }
            }
            .opacity(viewModel.style == .instant ? 1 : 0)
        }
        .animation(RSMotion.crossFade, value: viewModel.style)
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
            Spacer(minLength: 0)
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                .frame(height: 330)
        }
        .allowsHitTesting(false)
    }

    // MARK: Controls

    private var controls: some View {
        ZStack {
            if let block = viewModel.blockContent {
                BlockedMessage(notice: block, action: viewModel.blockActionTapped)
            }
            if viewModel.countdown > 0 {
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

            CameraChip(viewModel: viewModel)
                .padding(.bottom, layout.bottom(146))
                .frame(maxHeight: .infinity, alignment: .bottom)

            // Centred over the lens button below it.
            ZoomButton(viewModel: viewModel)
                .padding(.trailing, 36)
                .padding(.bottom, layout.bottom(146))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            CameraStrip(viewModel: viewModel)
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
        .animation(RSMotion.fade, value: viewModel.banner)
    }

    private var bottomBar: some View {
        HStack {
            Button(action: viewModel.galleryTapped) {
                ZStack {
                    RSColor.raised
                    if let look = viewModel.pendingShot {
                        // The shot on its way, as the viewfinder saw it.
                        PhotoLookView(image: viewModel.scene, camera: look, usesThumbnail: true)
                            .environment(\.liveFrames, shotFrames)
                    } else if let photo = viewModel.lastPhoto {
                        PhotoLookView(image: photo.image, camera: photo.camera, adjustments: photo.adjustments, usesThumbnail: true)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(RSColor.paper.opacity(0.85), lineWidth: 2) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open photos")

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
}

// MARK: - Top bar

private struct CameraTopBar: View {
    let viewModel: CameraViewModel
    @State private var pulse = false

    var body: some View {
        HStack {
            Button(action: viewModel.flashTapped) {
                RSIconView(viewModel.flash == .off ? .boltSlash : .bolt, size: 22, lineWidth: 1.8)
                    .foregroundStyle(viewModel.flash == .on ? RSColor.amber : RSColor.paper)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if viewModel.flash == .auto {
                            badge("A").padding(.trailing, 5).padding(.bottom, 5)
                        }
                    }
                    .glass(cornerRadius: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.flashLabel)

            Spacer(minLength: 0)

            if viewModel.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 0.25 : 1)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                    Text(viewModel.recordingClock)
                        .rsText(.labelSmall.tabularDigits())
                        .foregroundStyle(RSColor.paper)
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(RSColor.record, in: Capsule())
                .onAppear { pulse = true }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Recording, \(viewModel.recordingClock)")
            } else {
                SegmentedPill(
                    options: [(CaptureMode.photo, "Photo"), (CaptureMode.video, "Video")],
                    selection: viewModel.mode,
                    onSelect: viewModel.select
                )
            }

            Spacer(minLength: 0)

            Button(action: viewModel.timerTapped) {
                RSIconView(.timer, size: 22, lineWidth: 1.8)
                    .foregroundStyle(viewModel.isTimerOn ? RSColor.amber : RSColor.paper)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if viewModel.isTimerOn {
                            badge("3s").foregroundStyle(RSColor.amber).padding(.trailing, 3).padding(.bottom, 4)
                        }
                    }
                    .glass(cornerRadius: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.timerLabel)
        }
        .frame(height: 44)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .accessibilityHidden(true)
    }
}

// MARK: - Camera chip and strip

/// The pill above the shutter naming the current camera. It unfolds into the strip.
private struct CameraChip: View {
    let viewModel: CameraViewModel

    var body: some View {
        let visible = viewModel.isChipVisible
        Button(action: viewModel.chipTapped) {
            HStack(spacing: 8) {
                PhotoLookView(image: .sample(viewModel.style.sample), camera: viewModel.style, usesThumbnail: true)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(Color(hex: viewModel.style.accentHex), lineWidth: 2).padding(-2) }
                Text(viewModel.style.name)
                    .rsText(.labelSmall)
                RSIconView(.chevronUp, size: 14, lineWidth: 2.4)
            }
            .foregroundStyle(RSColor.paper)
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 44)
            .glass(cornerRadius: 22, tint: RSColor.glass(0.5), visibility: visible ? 1 : 0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .offset(y: viewModel.isStripVisible ? 12 : 0)
        .allowsHitTesting(visible)
        .animation(RSMotion.fade, value: visible)
        .animation(RSMotion.chip, value: viewModel.isStripVisible)
        .accessibilityLabel(viewModel.chipLabel)
        .accessibilityHidden(!visible)
    }
}

/// The round button beside the chip: the zoom as a number. A tap steps through the lenses; a pinch on the
/// viewfinder moves it freely.
private struct ZoomButton: View {
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

/// Five camera cards over the live preview. One tap switches the look and folds the strip away.
private struct CameraStrip: View {
    let viewModel: CameraViewModel

    var body: some View {
        let visible = viewModel.isStripVisible
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.stripTitle)
                        .rsText(.labelSmall)
                        .foregroundStyle(RSColor.paper)
                    Text(viewModel.stripSubtitle)
                        .rsText(.caption)
                        .foregroundStyle(RSColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CircleIconButton(
                    icon: .chevronDown, label: "Hide cameras", iconSize: 16, lineWidth: 2.4, diameter: 36,
                    fill: RSColor.raised, action: viewModel.closeStripTapped
                )
            }
            .padding(.leading, 18)
            .padding(.trailing, 12)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(CameraStyle.allCases) { camera in
                        CameraCard(camera: camera, isSelected: camera == viewModel.style) {
                            viewModel.pick(camera)
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .glass(cornerRadius: 28, tint: RSColor.ink(0.74), visibility: visible ? 1 : 0)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .background {
            if viewModel.isFirstRun {
                FirstRunGlow()
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 28)
        .allowsHitTesting(visible)
        .animation(RSMotion.fade, value: visible)
        .animation(RSMotion.strip, value: visible)
        .accessibilityHidden(!visible)
    }
}

/// The soft amber outline on first launch: box-shadow 0 0 0 1.5px amber 55%, 0 0 40px amber 18%.
private struct FirstRunGlow: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(RSColor.amber.opacity(0.18))
                .blur(radius: 20)
            RoundedRectangle(cornerRadius: 29.5)
                .strokeBorder(RSColor.amber.opacity(0.55), lineWidth: 1.5)
                .padding(-1.5)
        }
        // A box-shadow is never drawn under its own box.
        .mask {
            Rectangle()
                .padding(-80)
                .overlay { RoundedRectangle(cornerRadius: 28).blendMode(.destinationOut) }
                .compositingGroup()
        }
        .allowsHitTesting(false)
    }
}

struct CameraCard: View {
    let camera: CameraStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PhotoLookView(image: .sample(camera.sample), camera: camera, usesThumbnail: true)
                    .frame(width: 88, height: 110)
                    .overlay(alignment: .bottom) {
                        Color(hex: camera.accentHex).frame(height: 4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            RSIconView(.check, size: 13, lineWidth: 3.2)
                                .foregroundStyle(RSColor.onAmber)
                                .frame(width: 22, height: 22)
                                .background(RSColor.amber, in: Circle())
                                .padding(6)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18.5)
                            .strokeBorder(RSColor.amber, lineWidth: 2.5)
                            .padding(-2.5)
                            .opacity(isSelected ? 1 : 0)
                    }
                Text(camera.name)
                    .rsText(.chip)
                    .foregroundStyle(isSelected ? RSColor.paper : RSColor.tertiaryText)
                    .fixedSize()
            }
            .frame(width: 88)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.95))
        .animation(RSMotion.selection, value: isSelected)
        .accessibilityLabel("\(camera.name). \(camera.summary)\(isSelected ? " Selected." : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Blocked camera

private struct BlockedBackdrop: View {
    var body: some View {
        // radial-gradient(ellipse at 50% 40%, #221f1b, #0E0D0C 70%), sized to the farthest corner.
        GeometryReader { proxy in
            EllipticalGradient(
                stops: [
                    .init(color: Color(hex: 0x221F1B), location: 0),
                    .init(color: RSColor.ink, location: 0.7),
                    .init(color: RSColor.ink, location: 1),
                ],
                center: .center, startRadiusFraction: 0, endRadiusFraction: 0.7071
            )
            .frame(height: proxy.size.height * 1.2)
            .offset(y: -proxy.size.height * 0.2)
        }
        .clipped()
    }
}

private struct BlockedMessage: View {
    let notice: CameraNotice
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            RSIconView(.cameraSlash, size: 32, lineWidth: 1.7)
                .foregroundStyle(RSColor.secondaryText)
                .frame(width: 72, height: 72)
                .background(RSColor.raised, in: Circle())
            Text(notice.title)
                .rsText(.heading.lineHeight(1.2))
                .foregroundStyle(RSColor.paper)
                .accessibilityAddTraits(.isHeader)
            Text(notice.message)
                .rsText(.bodySmall.lineHeight(1.4).multiline())
                .foregroundStyle(RSColor.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: notice.actionTitle, height: 48, horizontalPadding: 28, action: action)
                .padding(.top, 8)
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 180)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Motion

/// The camera's name, shown for about a second after the look changes.
private struct CameraNameLabel: View {
    let name: String
    let trigger: Int

    private struct Values {
        var opacity = 0.0
        var offset = 8.0
        var scale = 0.96
    }

    var body: some View {
        Color.clear
            .frame(height: 1)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { _, value in
                Text(name)
                    .rsText(.labelSmall)
                    .foregroundStyle(RSColor.paper)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glass(cornerRadius: 20, tint: RSColor.glass(0.55), visibility: value.opacity)
                    .opacity(value.opacity)
                    .scaleEffect(value.scale)
                    .offset(y: value.offset)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0)
                    CubicKeyframe(1, duration: RSMotion.nameLabelDuration * 0.15)
                    CubicKeyframe(1, duration: RSMotion.nameLabelDuration * 0.60)
                    CubicKeyframe(0, duration: RSMotion.nameLabelDuration * 0.25)
                }
                KeyframeTrack(\.offset) {
                    MoveKeyframe(8)
                    CubicKeyframe(0, duration: RSMotion.nameLabelDuration * 0.15)
                }
                KeyframeTrack(\.scale) {
                    MoveKeyframe(0.96)
                    CubicKeyframe(1, duration: RSMotion.nameLabelDuration * 0.15)
                }
            }
            .accessibilityHidden(true)
    }
}

/// What the shutter sets off: the 240ms white flash, and over it the picture the lens saw shrinking into the
/// gallery button. Both start as the shutter fires; the photo itself lands in the library when the camera is done.
private struct CaptureEffects: View {
    let shutterCount: Int
    let mode: CaptureMode
    /// What the lens sees. A live scene is drawn from the frames around this view, frozen as the shutter fired.
    let scene: PhotoImage
    @Environment(\.designLayout) private var layout

    private struct Flight {
        var progress = 1.0
        var opacity = 0.0
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let landing = size.height - layout.bottom(122)
            let picture = PhotoPicture(image: scene)
            let flashes = mode == .photo
            ZStack(alignment: .topLeading) {
                Color.clear
                    .keyframeAnimator(initialValue: 0.0, trigger: shutterCount) { _, flash in
                        Color.white.opacity(flashes ? flash : 0)
                    } keyframes: { _ in
                        MoveKeyframe(0.92)
                        CubicKeyframe(0, duration: RSMotion.flashDuration)
                    }
                Color.clear
                    .keyframeAnimator(initialValue: Flight(), trigger: shutterCount) { _, value in
                        ZStack(alignment: .topLeading) {
                            Self.flyingShot(picture, progress: value.progress, in: size, landingY: landing)
                                .opacity(value.opacity)
                        }
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                    } keyframes: { _ in
                        KeyframeTrack(\.progress) {
                            MoveKeyframe(0)
                            LinearKeyframe(0, duration: RSMotion.flyDelay)
                            LinearKeyframe(1, duration: RSMotion.flyDuration, timingCurve: Self.flyCurve)
                        }
                        KeyframeTrack(\.opacity) {
                            MoveKeyframe(1)
                            LinearKeyframe(1, duration: RSMotion.flyDelay + RSMotion.flyDuration * 0.85)
                            LinearKeyframe(0, duration: RSMotion.flyDuration * 0.15, timingCurve: Self.flyCurve)
                        }
                    }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private nonisolated static let flyCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.4, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1)
    )

    /// From the whole screen down to the 56pt gallery button, as in the prototype's keyframes.
    private nonisolated static func flyingShot(
        _ picture: PhotoPicture, progress: Double, in size: CGSize, landingY: CGFloat
    ) -> some View {
        let width = size.width + (56 - size.width) * progress
        let height = size.height + (56 - size.height) * progress
        let radius = 50 + (16 - 50) * progress
        return picture
            .frame(width: width, height: height)
            .colorEffect(LookShaders.filterChain([.sepia(0.3), .saturate(1.2)]))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .compositingGroup()
            .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
            .offset(x: 30 * progress, y: landingY * progress)
    }
}
