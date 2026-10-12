import SwiftUI

/// Draws a photo through a camera's look. A layer-for-layer port of the design's Photo component:
/// the plain image, the filtered image at the effect strength, the tint/flash/fade/bleed/scanline/
/// vignette/warmth/grain layers, stamps, then Light and Contrast over the lot.
struct PhotoLookView: View {
    var image: SampleImage
    var camera: CameraStyle
    var adjustments = PhotoAdjustments.neutral
    /// Instant photos get the white print frame when this is set.
    var framed = false
    /// Stamp text; nil draws no stamp.
    var stamp: PhotoStampText?
    /// Stamp insets as a fraction of the photo's height.
    var stampBottom: CGFloat = 0.05
    var stampTop: CGFloat = 0.05
    /// Shows the play badge and this duration.
    var videoDuration: String?
    var usesThumbnail = false

    var body: some View {
        GeometryReader { proxy in
            let model = LookRenderModel(camera: camera, adjustments: adjustments, framed: framed, stampEnabled: stamp != nil)
            let width = proxy.size.width
            let height = proxy.size.height
            if model.isFramed {
                // padding: 5.5% 5.5% 22% 5.5%, every side measured against the width.
                let side = width * 0.055
                let box = CGSize(width: width - side * 2, height: max(0, height - side - width * 0.22))
                ZStack(alignment: .topLeading) {
                    RSColor.printFrame
                    photo(model, size: box)
                        .offset(x: side, y: side)
                }
            } else {
                photo(model, size: CGSize(width: width, height: height))
            }
        }
    }

    private var assetName: String {
        usesThumbnail ? image.thumbnail : image.full
    }

    private func source(_ size: CGSize) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    private func rendered(_ model: LookRenderModel, size: CGSize) -> some View {
        ZStack {
            RSColor.photoBacking
            if model.lookOpacity < 1 {
                source(size)
            }
            if model.lookOpacity > 0 {
                source(size)
                    .blur(radius: model.blurRadius, opaque: true)
                    .colorEffect(LookShaders.filterChain(model.filters))
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
                stamps(stamp, kind: model.stamp, size: size)
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

    // Sizes follow the CSS: max(9px, N cqw) of the photo box width; insets are percentages of the box.
    @ViewBuilder
    private func stamps(_ text: PhotoStampText, kind: LookStamp, size: CGSize) -> some View {
        switch kind {
        case .none:
            EmptyView()
        case .date:
            DateStampView(text: text.date, size: max(9, size.width * 0.075))
                .padding(.trailing, size.width * 0.06)
                .padding(.bottom, size.height * stampBottom)
                .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
        case .vhs:
            let small = max(9, size.width * 0.065)
            ZStack {
                TapePlayLabel(size: max(9, size.width * 0.07))
                    .padding(.leading, size.width * 0.06)
                    .padding(.top, size.height * stampTop)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                TapeText {
                    HStack {
                        Text(text.tapeDate)
                        Spacer(minLength: 0)
                        Text(text.tapeTime)
                    }
                    .font(RSFont.stamp(small))
                }
                .padding(.horizontal, size.width * 0.06)
                .padding(.bottom, size.height * stampBottom)
                .frame(width: size.width, height: size.height, alignment: .bottom)
            }
        }
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
        .accessibilityHidden(true)
    }
}

extension PhotoLookView {
    /// A library photo with its own camera, edits and clip length.
    init(photo: Photo, framed: Bool = false, stamp: PhotoStampText? = nil, usesThumbnail: Bool = false) {
        self.init(
            image: photo.image, camera: photo.camera, adjustments: photo.adjustments, framed: framed,
            stamp: stamp, videoDuration: photo.videoDurationText, usesThumbnail: usesThumbnail
        )
    }
}
