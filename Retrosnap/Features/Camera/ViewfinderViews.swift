import SwiftUI

// The picture under the look and what is drawn over it, shared by the camera and develop screens.

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

/// The 240ms white flash the shutter sets off.
struct ShutterFlash: View {
    let trigger: Int
    /// False where the shot makes no flash, as in video mode.
    var isEnabled = true

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, flash in
                Color.white.opacity(isEnabled ? flash : 0)
            } keyframes: { _ in
                MoveKeyframe(0.92)
                CubicKeyframe(0, duration: RSMotion.flashDuration)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
