import CoreImage
import SwiftUI

/// A baked file's stamp and frame artwork, drawn by the views the screen draws (`PhotoStampView`, `LookFrameView`)
/// and handed to `LookRenderer.picture` as transparent pictures. `PhotoExporter` and the calibration tests both
/// draw them here, so the file and the tests cannot drift apart.
@MainActor
enum BakeArtwork {
    /// The same stamp the screen draws, as a transparent picture exactly the size of the photo; nil for no stamp.
    static func stamp(_ text: PhotoStampText, kind: LookStamp, layout: BakeLayout) -> CIImage? {
        guard kind != .none else { return nil }
        let size = layout.pointSize
        return rasterised(
            PhotoStampView(text: text, kind: kind, size: size).frame(width: size.width, height: size.height),
            scale: layout.stampScale, to: layout.crop.size
        )
    }

    /// The frame's artwork as the screen draws it, as a transparent picture exactly the size of the file; nil for
    /// no frame, and for the full frame, which has no artwork.
    static func frame(_ frame: LookFrame?, layout: BakeLayout, photoAspect: CGFloat, design: FrameDesign) -> CIImage? {
        guard let frame, frame != .fullFrame else { return nil }
        let size = layout.canvasPointSize
        return rasterised(
            LookFrameView(frame: frame, size: size, photoAspect: photoAspect, design: design)
                .frame(width: size.width, height: size.height),
            scale: layout.artworkScale, to: layout.canvas
        )
    }

    /// `content` drawn at `scale` pixels per point, then stretched to exactly `pixels`.
    private static func rasterised(_ content: some View, scale: CGFloat, to pixels: CGSize) -> CIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let drawn = renderer.cgImage else { return nil }
        let image = CIImage(cgImage: drawn)
        return image.transformed(by: CGAffineTransform(
            scaleX: pixels.width / image.extent.width, y: pixels.height / image.extent.height
        ))
    }
}
