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
    private let colorStage: CIColorKernel
    private let overlays: CIColorKernel
    private let adjust: CIColorKernel
    private let halationGlow: CIColorKernel
    private let softMask: CIColorKernel

    init() throws {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { throw Failure.missingShaderLibrary }
        let library = try Data(contentsOf: url)
        filterChain = try CIColorKernel(functionName: "rsFilterChainKernel", fromMetalLibraryData: library)
        colorStage = try CIColorKernel(functionName: "rsColorKernel", fromMetalLibraryData: library)
        overlays = try CIColorKernel(functionName: "rsOverlaysKernel", fromMetalLibraryData: library)
        adjust = try CIColorKernel(functionName: "rsAdjustKernel", fromMetalLibraryData: library)
        halationGlow = try CIColorKernel(functionName: "rsHalationGlowKernel", fromMetalLibraryData: library)
        softMask = try CIColorKernel(functionName: "rsSoftMaskKernel", fromMetalLibraryData: library)
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

    // MARK: The look

    /// The photo with its look: the looked picture at the effect strength over the plain one, the
    /// tint/flash/fade/bleed/scanline/vignette/warmth/grain layers, the stamp, then Light and Contrast.
    /// The looked picture is the plain one through the lens (soft corners), the film's halation, the camera's
    /// blur, and then its colour: the camera's table, else its fitted colour stage, else the design's filter chain.
    /// - Parameters:
    ///   - photo: The picture upright, with its bottom-left corner at zero.
    ///   - scale: Pixels per point.
    ///   - stamp: The date or tape text already drawn at the photo's size.
    func render(_ photo: CIImage, model: LookRenderModel, scale: CGFloat, stamp: CIImage? = nil) -> CIImage {
        let extent = photo.extent
        let uniforms = LookUniforms(model)
        let pointSize = CIVector(x: extent.width / scale, y: extent.height / scale)
        var image = photo

        if model.lookOpacity > 0 {
            var filtered = photo
            if let soft = model.soft {
                let blurred = Self.blurred(photo, sigma: soft.radius * scale)
                let white = CIImage(color: .white).cropped(to: extent)
                let mask = softMask.apply(extent: extent, arguments: [white, pointSize, scale, Self.vector(uniforms.soft)]) ?? white
                filtered = Self.blend(blurred, over: filtered, mask: mask)
            }
            if let halation = model.halation {
                let glow = halationGlow.apply(
                    extent: extent, arguments: [photo, Self.vector(uniforms.halation), Self.vector(uniforms.halationTint)]
                ) ?? photo
                filtered = Self.screen(Self.blurred(glow, sigma: halation.radius * scale), over: filtered)
            }
            if model.blurRadius > 0 {
                filtered = Self.blurred(filtered, sigma: model.blurRadius * scale)
            }
            if let name = uniforms.colorCube, let table = ColorCubes.cubeData(named: name) {
                let cube = CIFilter.colorCubeWithColorSpace()
                cube.inputImage = filtered
                cube.cubeDimension = Float(table.size)
                cube.cubeData = table.data
                cube.colorSpace = colorSpace
                filtered = cube.outputImage?.cropped(to: extent) ?? filtered
            } else {
                switch uniforms.colorPass {
                case .stage(let stage):
                    filtered = colorStage.apply(extent: extent, arguments: [filtered] + stage.map(Self.vector)) ?? filtered
                case .chain(let operations):
                    let steps = operations.map { CIVector(x: $0.kind, y: $0.amount) }
                    filtered = filterChain.apply(extent: extent, arguments: [filtered] + steps) ?? filtered
                }
            }
            image = model.lookOpacity < 1 ? Self.blend(filtered, over: photo, opacity: model.lookOpacity) : filtered
        }

        image = overlays.apply(extent: extent, arguments: [
            image,
            pointSize,
            scale,
            Self.vector(uniforms.tint),
            Self.vector(uniforms.warm),
            Self.vector(uniforms.effects),
            CIVector(x: uniforms.vignette, y: uniforms.grain),
            Self.vector(uniforms.filmGrain),
        ]) ?? image

        if let stamp {
            image = model.stamp.isScreened ? Self.screen(stamp, over: image) : stamp.composited(over: image).cropped(to: extent)
        }
        if model.needsAdjustmentPass {
            image = adjust.apply(extent: extent, arguments: [image, uniforms.brightness, uniforms.contrast]) ?? image
        }
        return image
    }

    // MARK: The saved picture

    /// The whole picture as it is saved: the part of the original the layout uses, with its look, on paper
    /// wherever the layout leaves a margin (the Instant print's frame, a film's strip, a print's border), and
    /// the frame's artwork over the lot when it has any.
    func picture(
        from original: CIImage, model: LookRenderModel, layout: BakeLayout, stamp: CIImage?,
        paper: CIColor = CIColor(hex: RSColor.printFrameHex), artwork: CIImage? = nil
    ) -> CIImage {
        let photo = original
            .cropped(to: layout.crop.offsetBy(dx: original.extent.minX, dy: original.extent.minY))
            .transformed(by: CGAffineTransform(
                translationX: -original.extent.minX - layout.crop.minX, y: -original.extent.minY - layout.crop.minY
            ))
        let looked = render(photo, model: model, scale: layout.scale, stamp: stamp)
        guard layout.canvas != layout.crop.size else { return looked }
        let canvas = CGRect(origin: .zero, size: layout.canvas)
        let sheet = CIImage(color: paper).cropped(to: canvas)
        var picture = looked
            .transformed(by: CGAffineTransform(translationX: layout.photoOrigin.x, y: layout.photoOrigin.y))
            .composited(over: sheet)
        if let artwork {
            picture = artwork.composited(over: picture)
        }
        return picture.cropped(to: canvas)
    }

    // MARK: Compositing

    private static func blurred(_ image: CIImage, sigma: CGFloat) -> CIImage {
        image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: image.extent)
    }

    private static func blend(_ top: CIImage, over bottom: CIImage, opacity: Double) -> CIImage {
        let dissolve = CIFilter.dissolveTransition()
        dissolve.inputImage = bottom
        dissolve.targetImage = top
        dissolve.time = Float(opacity)
        return dissolve.outputImage?.cropped(to: bottom.extent) ?? top
    }

    /// `top` where the mask is white, `bottom` where it is black.
    private static func blend(_ top: CIImage, over bottom: CIImage, mask: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = top
        filter.backgroundImage = bottom
        filter.maskImage = mask
        return filter.outputImage?.cropped(to: bottom.extent) ?? bottom
    }

    private static func screen(_ top: CIImage, over bottom: CIImage) -> CIImage {
        let filter = CIFilter.screenBlendMode()
        filter.inputImage = top
        filter.backgroundImage = bottom
        return filter.outputImage?.cropped(to: bottom.extent) ?? bottom
    }

    // MARK: Arguments

    private static func vector(_ color: LookUniforms.Color) -> CIVector {
        CIVector(x: color.red, y: color.green, z: color.blue, w: color.opacity)
    }

    private static func vector(_ vector: LookUniforms.Vector) -> CIVector {
        CIVector(x: vector.x, y: vector.y, z: vector.z, w: vector.w)
    }
}
