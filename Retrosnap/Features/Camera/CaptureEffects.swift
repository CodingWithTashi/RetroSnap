import SwiftUI

/// What the shutter sets off: the 240ms white flash, and over it the picture the lens saw shrinking into the
/// gallery button. Both start as the shutter fires; the photo itself lands in the library when the camera is done.
struct CaptureEffects: View {
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
                ShutterFlash(trigger: shutterCount, isEnabled: flashes)
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

    /// From the whole screen down to the gallery button, as in the prototype's keyframes.
    private nonisolated static func flyingShot(
        _ picture: PhotoPicture, progress: Double, in size: CGSize, landingY: CGFloat
    ) -> some View {
        let width = size.width + (CameraControlMetrics.galleryButtonSize - size.width) * progress
        let height = size.height + (CameraControlMetrics.galleryButtonSize - size.height) * progress
        let radius = 50 + (CameraControlMetrics.galleryButtonRadius - 50) * progress
        return picture
            .frame(width: width, height: height)
            .colorEffect(LookShaders.filterChain([.sepia(0.3), .saturate(1.2)]))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .compositingGroup()
            .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
            .offset(x: CameraControlMetrics.bottomBarInset * progress, y: landingY * progress)
    }
}
