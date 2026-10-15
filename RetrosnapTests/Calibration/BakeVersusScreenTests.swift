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
    @Test(.enabled(if: ReferencePairTests.hasPairs), arguments: ReferencePairTests.fittedCameras)
    func bakesTheFirstSeedPhotoAsTheViewerShowsIt(camera: CameraStyle) throws {
        let renderer = try LookRenderer()
        // The first seed photo, as `-rsScreen viewer -rsCamera <id>` poses it.
        let picture = try #require(UIImage(named: "photo-1011")?.cgImage)
        let original = CIImage(cgImage: picture)
        let model = LookRenderModel(camera: camera, adjustments: .neutral, framed: true, stampEnabled: false)
        let layout = BakeLayout(source: original.extent.size, frame: model.frame)
        let artwork = BakeArtwork.frame(model.frame, layout: layout, photoAspect: Photo.cameraAspect, design: FrameDesign())
        let paper = CIColor(hex: model.paperHex)
        let baked = renderer.picture(from: original, model: model, layout: layout, stamp: nil, paper: paper, artwork: artwork)
        let output = ReferencePairTests.pairs.appendingPathComponent("bake-\(camera.rawValue).png")
        try renderer.context.writePNGRepresentation(
            of: baked, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )
        #expect(baked.extent.size == layout.canvas)
    }
}

/// The reference inputs baked as the user would get them from the Share sheet: the full canvas with the frame,
/// written small enough to hold against the reference app's screenshots and exports (`tools/frames.py`). Runs
/// only on a machine that has `ref/`, which git ignores.
@MainActor
struct ReferenceExportTests {
    nonisolated static let inputs = ReferencePairTests.pairs.deletingLastPathComponent().appendingPathComponent("photo-input")

    /// The reference pictures (`tools/pairs.py`): the pair suffix, the file, when it was taken (its stamp: the
    /// generated pictures have no EXIF and were stamped with the day they were imported), and the square print's
    /// and the slide mount's cards the reference app happened to give it.
    nonisolated static let pictures: [(suffix: String, file: String, taken: String, design: FrameDesign)] = [
        ("", "IMG_5821.JPG", "2026-10-08T17:00:00Z", FrameDesign(square: .lightBlue, slide: .greyDimpled)),
        ("-1", "IMG_5326.JPG", "2026-07-23T17:00:00Z", FrameDesign(square: .whitePattern, slide: .creamStriped)),
        ("-2", "IMG_5646.JPG", "2026-08-21T17:00:00Z", FrameDesign(square: .darkBlue, slide: .greyDimpled)),
        ("-3", "gen_tungsten.jpg", "2026-10-13T17:00:00Z", FrameDesign(square: .plainWhite, slide: .creamPrinted)),
        ("-4", "gen_backlit.jpg", "2026-10-13T17:00:00Z", FrameDesign(square: .green, slide: .whitePlastic)),
        ("-5", "gen_market.jpg", "2026-10-13T17:00:00Z", FrameDesign(square: .plainWhite, slide: .creamPrinted)),
        ("-6", "gen_wall.jpg", "2026-10-13T17:00:00Z", FrameDesign(square: .green, slide: .greyDimpled)),
    ]

    @Test(.enabled(if: ReferencePairTests.hasPairs), arguments: ReferencePairTests.fittedCameras)
    func bakesEveryReferencePictureWithItsCanvas(camera: CameraStyle) throws {
        let renderer = try LookRenderer()
        let labeler = DayLabeler(clock: FixedClock.design)
        for picture in Self.pictures {
            let url = Self.inputs.appendingPathComponent(picture.file)
            let original = try #require(CIImage(contentsOf: url, options: [.applyOrientationProperty: true]))
            let model = LookRenderModel(camera: camera, adjustments: .neutral, framed: true, stampEnabled: true)
            let layout = BakeLayout(source: original.extent.size, frame: model.frame)
            let photoAspect = original.extent.width / original.extent.height
            let artwork = BakeArtwork.frame(model.frame, layout: layout, photoAspect: photoAspect, design: picture.design)
            let date = ISO8601DateFormatter().date(from: picture.taken) ?? FixedClock.design.now
            let stamp = BakeArtwork.stamp(labeler.stamp(for: date), kind: model.stamp, layout: layout)
            let paper = CIColor(hex: model.paperHex)
            let baked = renderer.picture(from: original, model: model, layout: layout, stamp: stamp, paper: paper, artwork: artwork)
            // Small enough to look at: 1200 px wide.
            let factor = 1200 / baked.extent.width
            let small = baked.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
            let output = ReferencePairTests.pairs.appendingPathComponent("export-\(camera.rawValue)\(picture.suffix).png")
            try renderer.context.writePNGRepresentation(
                of: small, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            )
            #expect(FileManager.default.fileExists(atPath: output.path))
        }
    }
}
