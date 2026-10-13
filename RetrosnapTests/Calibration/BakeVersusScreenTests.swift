import CoreImage
import Foundation
import SwiftUI
import Testing
@testable import Retrosnap

/// The export path for every framed camera, written out for `tools/screen_vs_bake.py` to hold against a
/// screenshot of the Viewer showing the same photo (`-rsScreen viewer -rsCamera <id>`): the Core Image bake
/// must match the screen. Runs only on a machine that has `ref/`, which git ignores.
@MainActor
struct BakeVersusScreenTests {
    @Test(.enabled(if: ReferencePairTests.hasPairs), arguments: [CameraStyle.negative, .plastic35, .slide, .mediumFormat, .tlr])
    func bakesTheFirstSeedPhotoAsTheViewerShowsIt(camera: CameraStyle) throws {
        let renderer = try LookRenderer()
        // The first seed photo, as `-rsScreen viewer -rsCamera <id>` poses it.
        let picture = try #require(UIImage(named: "photo-1011")?.cgImage)
        let original = CIImage(cgImage: picture)
        let model = LookRenderModel(camera: camera, adjustments: .neutral, framed: true, stampEnabled: false)
        let layout = BakeLayout(source: original.extent.size, frame: model.frame)
        var artwork: CIImage?
        if let frame = model.frame, frame != .instantPrint {
            let size = layout.canvasPointSize
            let frameRenderer = ImageRenderer(
                content: LookFrameView(frame: frame, size: size).frame(width: size.width, height: size.height)
            )
            frameRenderer.scale = layout.scale
            if let drawn = frameRenderer.cgImage {
                let image = CIImage(cgImage: drawn)
                artwork = image.transformed(by: CGAffineTransform(
                    scaleX: layout.canvas.width / image.extent.width, y: layout.canvas.height / image.extent.height
                ))
            }
        }
        let paper = CIColor(hex: model.frame?.baseHex ?? RSColor.printFrameHex)
        let baked = renderer.picture(from: original, model: model, layout: layout, stamp: nil, paper: paper, artwork: artwork)
        let output = ReferencePairTests.pairs.appendingPathComponent("bake-\(camera.rawValue).png")
        try renderer.context.writePNGRepresentation(
            of: baked, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )
        #expect(baked.extent.size == layout.canvas)
    }
}
