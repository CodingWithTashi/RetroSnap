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
            frameRenderer.scale = layout.artworkScale
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

/// The reference inputs baked as the user would get them from the Share sheet: the full canvas with the frame,
/// written small enough to hold against the reference app's screenshots (`tools/frames.py`). Runs only on a
/// machine that has `ref/`, which git ignores.
@MainActor
struct ReferenceExportTests {
    nonisolated static let inputs = ReferencePairTests.pairs.deletingLastPathComponent().appendingPathComponent("photo-input")

    @Test(.enabled(if: ReferencePairTests.hasPairs), arguments: [CameraStyle.negative, .plastic35, .slide, .mediumFormat, .tlr])
    func bakesBothReferencePicturesWithTheirCanvas(camera: CameraStyle) throws {
        let renderer = try LookRenderer()
        let labeler = DayLabeler(clock: FixedClock.design)
        for (suffix, file, taken) in [("", "input.JPG", "2026-10-08T12:32:00Z"), ("-1", "input_1.JPG", "2026-07-23T17:07:00Z")] {
            let url = Self.inputs.appendingPathComponent(file)
            let original = try #require(CIImage(contentsOf: url, options: [.applyOrientationProperty: true]))
            let model = LookRenderModel(camera: camera, adjustments: .neutral, framed: true, stampEnabled: true)
            let layout = BakeLayout(source: original.extent.size, frame: model.frame)
            let photoAspect = original.extent.width / original.extent.height
            var artwork: CIImage?
            if let frame = model.frame, frame != .instantPrint, frame != .fullFrame {
                let size = layout.canvasPointSize
                let frameRenderer = ImageRenderer(
                    content: LookFrameView(frame: frame, size: size, photoAspect: photoAspect).frame(width: size.width, height: size.height)
                )
                frameRenderer.scale = layout.artworkScale
                if let drawn = frameRenderer.cgImage {
                    let image = CIImage(cgImage: drawn)
                    artwork = image.transformed(by: CGAffineTransform(
                        scaleX: layout.canvas.width / image.extent.width, y: layout.canvas.height / image.extent.height
                    ))
                }
            }
            var stamp: CIImage?
            if model.stamp != .none {
                let size = layout.pointSize
                let date = ISO8601DateFormatter().date(from: taken) ?? FixedClock.design.now
                let stampRenderer = ImageRenderer(
                    content: PhotoStampView(text: labeler.stamp(for: date), kind: model.stamp, size: size)
                        .frame(width: size.width, height: size.height)
                )
                stampRenderer.scale = layout.stampScale
                if let drawn = stampRenderer.cgImage {
                    let image = CIImage(cgImage: drawn)
                    stamp = image.transformed(by: CGAffineTransform(
                        scaleX: layout.crop.width / image.extent.width, y: layout.crop.height / image.extent.height
                    ))
                }
            }
            let paper = CIColor(hex: model.frame?.baseHex ?? RSColor.printFrameHex)
            let baked = renderer.picture(from: original, model: model, layout: layout, stamp: stamp, paper: paper, artwork: artwork)
            // Small enough to look at: 1200 px wide.
            let factor = 1200 / baked.extent.width
            let small = baked.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
            let output = ReferencePairTests.pairs.appendingPathComponent("export-\(camera.rawValue)\(suffix).png")
            try renderer.context.writePNGRepresentation(
                of: small, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            )
            #expect(FileManager.default.fileExists(atPath: output.path))
        }
    }
}
