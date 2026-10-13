import SwiftUI

// The controls the camera screen and the develop screen share: the picture under the look, the chip that names
// the camera, the strip of camera cards, and the shutter's flash.

/// The look over what the lens sees, or over a pick from the library, filling its box. A camera whose picture
/// is not the whole box (Instant shoots square, a film strip 2:3) has the rest dimmed.
struct ViewfinderPicture: View {
    let image: PhotoImage
    let camera: CameraStyle
    let stamp: PhotoStampText
    /// Enlarges a still scene standing in for a zoomed lens.
    var magnification: CGFloat = 1
    /// The play badge and clip length over a clip that is not running.
    var videoDuration: String?

    var body: some View {
        ZStack {
            PhotoLookView(
                image: image, camera: camera, stamp: stamp, stampBottom: 0.27, stampTop: 0.17,
                videoDuration: videoDuration, magnification: magnification
            )
            .id(camera)
            .transition(.opacity)

            GeometryReader { proxy in
                let size = proxy.size
                let ratio = Self.pictureRatio(of: camera, in: size)
                let vertical = max(0, (size.height - size.width / ratio) / 2)
                let horizontal = max(0, (size.width - size.height * ratio) / 2)
                let dim = Color(hex: 0x0A0908, opacity: 0.72)
                VStack(spacing: 0) {
                    dim.frame(height: vertical)
                    Spacer(minLength: 0)
                    dim.frame(height: vertical)
                }
                HStack(spacing: 0) {
                    dim.frame(width: horizontal)
                    Spacer(minLength: 0)
                    dim.frame(width: horizontal)
                }
            }
            .opacity(camera.pictureRatio != nil ? 1 : 0)
        }
        .animation(RSMotion.crossFade, value: camera)
    }

    /// The width over the height of the camera's picture in this box: the film's frame the way the box is, as
    /// `LookFrame.pictureAspect(forPhotoAspect:)` turns it; the Instant print and the square stay as they are.
    private static func pictureRatio(of camera: CameraStyle, in box: CGSize) -> CGFloat {
        camera.look.frame?.pictureAspect(forPhotoAspect: box.width / max(1, box.height)) ?? 1
    }
}

/// The dark gradients at the top and the bottom of the viewfinder that the controls sit on.
struct ViewfinderScrims: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
            Spacer(minLength: 0)
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                .frame(height: 330)
        }
        .allowsHitTesting(false)
    }
}

/// A round glass button over the viewfinder: flash, timer, and on the develop screen cancel and choose another.
struct GlassIconButton: View {
    let icon: RSIcon
    let label: String
    var iconSize: CGFloat = 22
    var lineWidth: CGFloat = 1.8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RSIconView(icon, size: iconSize, lineWidth: lineWidth)
                .foregroundStyle(RSColor.paper)
                .frame(width: 44, height: 44)
                .glass(cornerRadius: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The 240ms white flash the shutter sets off.
struct ShutterFlash: View {
    let trigger: Int

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, flash in
                Color.white.opacity(flash)
            } keyframes: { _ in
                MoveKeyframe(0.92)
                CubicKeyframe(0, duration: RSMotion.flashDuration)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Camera chip and strip

/// The pill above the shutter naming the current camera. It unfolds into the strip.
struct CameraChip: View {
    let style: CameraStyle
    let isVisible: Bool
    /// The strip is open above it; the chip sits a little lower while it is.
    let isStripOpen: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                PhotoLookView(image: .sample(style.sample), camera: style, usesThumbnail: true)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(Color(hex: style.accentHex), lineWidth: 2).padding(-2) }
                Text(style.name)
                    .rsText(.labelSmall)
                RSIconView(.chevronUp, size: 14, lineWidth: 2.4)
            }
            .foregroundStyle(RSColor.paper)
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 44)
            .glass(cornerRadius: 22, tint: RSColor.glass(0.5), visibility: isVisible ? 1 : 0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isStripOpen ? 12 : 0)
        .allowsHitTesting(isVisible)
        .animation(RSMotion.fade, value: isVisible)
        .animation(RSMotion.chip, value: isStripOpen)
        .accessibilityLabel(label)
        .accessibilityHidden(!isVisible)
    }
}

/// Camera cards over the picture. One tap switches the look and folds the strip away.
struct CameraStrip: View {
    let style: CameraStyle
    let isVisible: Bool
    /// First launch: the strip introduces itself with an amber glow and its own copy.
    let isFirstRun: Bool
    let title: String
    let subtitle: String
    let onClose: () -> Void
    let onPick: (CameraStyle) -> Void

    var body: some View {
        let visible = isVisible
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .rsText(.labelSmall)
                        .foregroundStyle(RSColor.paper)
                    Text(subtitle)
                        .rsText(.caption)
                        .foregroundStyle(RSColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CircleIconButton(
                    icon: .chevronDown, label: "Hide cameras", iconSize: 16, lineWidth: 2.4, diameter: 36,
                    fill: RSColor.raised, action: onClose
                )
            }
            .padding(.leading, 18)
            .padding(.trailing, 12)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(CameraStyle.allCases) { camera in
                            CameraCard(camera: camera, isSelected: camera == style) {
                                onPick(camera)
                            }
                        }
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.hidden)
                // The strip is longer than the screen: the selected card is brought into view, moving no
                // further than it has to, so a card that is already in view leaves the strip where it is.
                .onAppear { proxy.scrollTo(style.id, anchor: nil) }
                .onChange(of: visible) { _, isVisible in
                    if isVisible { proxy.scrollTo(style.id, anchor: nil) }
                }
                .onChange(of: style) { proxy.scrollTo(style.id, anchor: nil) }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .glass(cornerRadius: 28, tint: RSColor.ink(0.74), visibility: visible ? 1 : 0)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .background {
            if isFirstRun {
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

/// The camera's name, shown for about a second after the look changes.
struct CameraNameLabel: View {
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
