import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

/// Draws a camera's look with Core Image, for the files and video frames that leave the app.
/// It runs the Metal functions `PhotoLookView` runs on screen, layer for layer in the same order.
/// The kernels and the context never change once made, so one renderer serves every thread.
nonisolated final class LookRenderer: @unchecked Sendable {
    enum Failure: Error {
        case missingShaderLibrary
    }

    /// Works in gamma-encoded sRGB like the screen and the design's CSS, not in Core Image's linear default.
    let context: CIContext
    private let colorSpace: CGColorSpace
    private let filterChain: CIColorKernel
    private let overlays: CIColorKernel
    private let adjust: CIColorKernel

    init() throws {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { throw Failure.missingShaderLibrary }
        let library = try Data(contentsOf: url)
        filterChain = try CIColorKernel(functionName: "rsFilterChainKernel", fromMetalLibraryData: library)
        overlays = try CIColorKernel(functionName: "rsOverlaysKernel", fromMetalLibraryData: library)
        adjust = try CIColorKernel(functionName: "rsAdjustKernel", fromMetalLibraryData: library)
        context = CIContext(options: [.workingColorSpace: colorSpace, .cacheIntermediates: false])
        self.colorSpace = colorSpace
    }

    /// The picture as a JPEG, with whatever metadata it carries.
    func jpeg(_ picture: CIImage, quality: Double) -> Data? {
        context.jpegRepresentation(
            of: picture, colorSpace: colorSpace,
            options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality]
        )
    }

    /// The photo with its look: the filtered picture at the effect strength over the plain one, the
    /// tint/flash/fade/bleed/scanline/vignette/warmth/grain layers, the stamp, then Light and Contrast.
    /// - Parameters:
    ///   - photo: The picture upright, with its bottom-left corner at zero.
    ///   - scale: Pixels per point.
    ///   - stamp: The date or tape text already drawn at the photo's size.
    func render(_ photo: CIImage, model: LookRenderModel, scale: CGFloat, stamp: CIImage? = nil) -> CIImage {
        let extent = photo.extent
        let uniforms = LookUniforms(model)
        var image = photo

        if model.lookOpacity > 0 {
            var filtered = photo
            if model.blurRadius > 0 {
                filtered = photo.clampedToExtent().applyingGaussianBlur(sigma: model.blurRadius * scale).cropped(to: extent)
            }
            let operations = uniforms.operations.map { CIVector(x: $0.kind, y: $0.amount) }
            filtered = filterChain.apply(extent: extent, arguments: [filtered] + operations) ?? filtered
            image = model.lookOpacity < 1 ? Self.blend(filtered, over: photo, opacity: model.lookOpacity) : filtered
        }

        image = overlays.apply(extent: extent, arguments: [
            image,
            CIVector(x: extent.width / scale, y: extent.height / scale),
            scale,
            Self.vector(uniforms.tint),
            Self.vector(uniforms.warm),
            CIVector(x: uniforms.flash, y: uniforms.fade, z: uniforms.chroma, w: uniforms.scan),
            CIVector(x: uniforms.vignette, y: uniforms.grain),
        ]) ?? image

        if let stamp {
            image = stamp.composited(over: image).cropped(to: extent)
        }
        if model.needsAdjustmentPass {
            image = adjust.apply(extent: extent, arguments: [image, uniforms.brightness, uniforms.contrast]) ?? image
        }
        return image
    }

    /// The whole picture as it is saved: the part of the original the layout uses, with its look,
    /// on paper wherever the layout leaves a margin: the Instant print's frame, or a print's border.
    func picture(
        from original: CIImage, model: LookRenderModel, layout: BakeLayout, stamp: CIImage?,
        paper: CIColor = CIColor(hex: RSColor.printFrameHex)
    ) -> CIImage {
        let photo = original
            .cropped(to: layout.crop.offsetBy(dx: original.extent.minX, dy: original.extent.minY))
            .transformed(by: CGAffineTransform(
                translationX: -original.extent.minX - layout.crop.minX, y: -original.extent.minY - layout.crop.minY
            ))
        let looked = render(photo, model: model, scale: layout.scale, stamp: stamp)
        guard layout.canvas != layout.crop.size else { return looked }
        let sheet = CIImage(color: paper).cropped(to: CGRect(origin: .zero, size: layout.canvas))
        return looked
            .transformed(by: CGAffineTransform(translationX: layout.photoOrigin.x, y: layout.photoOrigin.y))
            .composited(over: sheet)
    }

    private static func blend(_ top: CIImage, over bottom: CIImage, opacity: Double) -> CIImage {
        let dissolve = CIFilter.dissolveTransition()
        dissolve.inputImage = bottom
        dissolve.targetImage = top
        dissolve.time = Float(opacity)
        return dissolve.outputImage?.cropped(to: bottom.extent) ?? top
    }

    private static func vector(_ color: LookUniforms.Color) -> CIVector {
        CIVector(x: color.red, y: color.green, z: color.blue, w: color.opacity)
    }
}

extension CIColor {
    /// An sRGB colour from a `0xRRGGBB` literal, as written in the design files.
    nonisolated convenience init(hex: UInt32) {
        let rgb = rgbComponents(hex: hex)
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
