import SwiftUI

/// Draws a photo through a camera's look. A layer-for-layer port of the design's Photo component:
/// the plain image, the looked image at the effect strength, the tint/flash/fade/bleed/scanline/
/// vignette/warmth/grain layers, stamps, then Light and Contrast over the lot. A framed photo sits in
/// the window of its canvas: the Instant print's paper, or a film camera's strip, mount or rebate.
struct PhotoLookView: View {
    var image: PhotoImage
    var camera: CameraStyle
    var adjustments = PhotoAdjustments.neutral
    /// Cameras with a canvas get it when this is set: the Instant print's frame, the film strip, the slide mount.
    var framed = false
    /// Stamp text; nil draws no stamp.
    var stamp: PhotoStampText?
    /// Stamp insets as a fraction of the photo's height.
    var stampBottom: CGFloat = 0.05
    var stampTop: CGFloat = 0.05
    /// Shows the play badge, with this duration in the corner unless it is empty.
    var videoDuration: String?
    var usesThumbnail = false
    /// Enlarges the picture inside its box, under the look: a still scene standing in for a zoomed lens.
    var magnification: CGFloat = 1
    /// The photo's own width over its height: which way a frame's window turns, and where a film's stamp lands.
    var photoAspect: CGFloat = 3.0 / 4
    /// Which of the square print's cards the photo gets.
    var frameDesign: SquarePrintDesign = .lightBlue

    var body: some View {
        GeometryReader { proxy in
            let model = LookRenderModel(camera: camera, adjustments: adjustments, framed: framed, stampEnabled: stamp != nil)
            let size = proxy.size
            if let frame = model.frame {
                let window = frame.window(in: size, photoAspect: photoAspect)
                ZStack(alignment: .topLeading) {
                    Color(hex: frame.baseHex)
                    photo(model, size: window.size)
                        .offset(x: window.minX, y: window.minY)
                    LookFrameView(frame: frame, size: size, photoAspect: photoAspect, design: frameDesign)
                }
            } else {
                photo(model, size: size)
            }
        }
    }

    /// Where the film's frame lies in an unframed box: the part the camera keeps, centred, the way the box is.
    /// A framed photo's box is the window itself.
    private func filmFrame(in size: CGSize) -> CGRect {
        guard !framed, let frame = camera.look.frame else {
            return CGRect(origin: .zero, size: size)
        }
        let ratio = frame.pictureAspect(forPhotoAspect: size.width / size.height)
        let fitted = size.width / size.height <= ratio
            ? CGSize(width: size.width, height: size.width / ratio)
            : CGSize(width: size.height * ratio, height: size.height)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }

    private func source(_ size: CGSize) -> some View {
        PhotoPicture(image: image, usesThumbnail: usesThumbnail)
            .frame(width: size.width, height: size.height)
            .scaleEffect(magnification)
            .clipped()
    }

    /// The picture through the lens and the film: soft corners and halation, when the camera has them.
    @ViewBuilder
    private func optics(_ model: LookRenderModel, size: CGSize) -> some View {
        if model.soft == nil && model.halation == nil {
            source(size)
        } else {
            ZStack {
                source(size)
                if let soft = model.soft {
                    source(size)
                        .blur(radius: soft.radius, opaque: true)
                        .mask {
                            Rectangle()
                                .fill(.white)
                                .colorEffect(LookShaders.softMask(model))
                        }
                }
                if let halation = model.halation {
                    source(size)
                        .colorEffect(LookShaders.halationGlow(model))
                        .blur(radius: halation.radius, opaque: true)
                        .blendMode(.screen)
                }
            }
            .frame(width: size.width, height: size.height)
            .compositingGroup()
        }
    }

    private func rendered(_ model: LookRenderModel, size: CGSize) -> some View {
        ZStack {
            RSColor.photoBacking
            if model.lookOpacity < 1 {
                source(size)
            }
            if model.lookOpacity > 0 {
                optics(model, size: size)
                    .blur(radius: model.blurRadius, opaque: true)
                    .colorEffect(LookShaders.color(model))
                    .opacity(model.lookOpacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .compositingGroup()
        .colorEffect(LookShaders.overlays(model))
    }

    private func photo(_ model: LookRenderModel, size: CGSize) -> some View {
        ZStack {
            rendered(model, size: size)
            if let stamp {
                PhotoStampView(
                    text: stamp, kind: model.stamp, size: size, bottomInset: stampBottom, topInset: stampTop,
                    filmFrame: filmFrame(in: size)
                )
                .blendMode(model.stamp.isScreened ? .screen : .normal)
            }
            if let videoDuration {
                videoBadge(model, duration: videoDuration, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
        .colorEffect(
            LookShaders.adjust(brightness: model.brightness, contrast: model.contrast),
            isEnabled: model.needsAdjustmentPass
        )
    }

    private func videoBadge(_ model: LookRenderModel, duration: String, size: CGSize) -> some View {
        let diameter = min(72, max(28, size.width * 0.18))
        return ZStack {
            // backdrop-filter: blur(12px) — the photo again, blurred, showing only through the disc.
            rendered(model, size: size)
                .compositingGroup()
                .blur(radius: 12, opaque: true)
                .mask { Circle().frame(width: diameter, height: diameter) }
            Circle()
                .fill(RSColor.ink(0.55))
                .frame(width: diameter, height: diameter)
            RSIconView(.play, size: diameter * 0.45, filled: true)
                .foregroundStyle(RSColor.paper)
                .offset(x: diameter * 0.03)
            if !duration.isEmpty {
                Text(duration)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(RSColor.paper)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RSColor.ink(0.6), in: RoundedRectangle(cornerRadius: 9))
                    .padding(.trailing, size.width * 0.05)
                    .padding(.top, size.height * 0.05)
                    .frame(width: size.width, height: size.height, alignment: .topTrailing)
            }
        }
        .accessibilityHidden(true)
    }
}

extension PhotoLookView {
    /// A library photo with its own camera, edits and clip length.
    init(photo: Photo, framed: Bool = false, stamp: PhotoStampText? = nil, usesThumbnail: Bool = false) {
        self.init(
            image: photo.image, camera: photo.camera, adjustments: photo.adjustments, framed: framed,
            stamp: stamp, videoDuration: photo.videoDurationText, usesThumbnail: usesThumbnail,
            photoAspect: photo.aspectRatio, frameDesign: SquarePrintDesign.forPhoto(id: photo.id)
        )
    }
}
