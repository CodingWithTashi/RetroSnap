import CoreImage
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Retrosnap

/// The pictures `tools/exceed.py` measures the brief's "Exceed" list on: the same photo baked at 12 and 48
/// megapixels (resolution-independent grain), the export of a reference input with its EXIF (metadata), and the
/// bake of the scene the mock camera shows (viewfinder equals export, against a screenshot of the camera screen).
/// Runs only on a machine that has `ref/`, which git ignores.
@MainActor
struct ExceedTests {
    /// (a) The grey wall through Classic U, the strongest grain, at its own 12 MP and upscaled to 48 MP: the
    /// same 200 pt square from the middle of each, so the grain can be measured in points on both.
    @Test(.enabled(if: ReferencePairTests.hasPairs))
    func bakesTheSamePhotoAtTwelveAndFortyEightMegapixels() throws {
        let renderer = try LookRenderer()
        let url = ReferenceExportTests.inputs.appendingPathComponent("gen_wall.jpg")
        let original = try #require(CIImage(contentsOf: url, options: [.applyOrientationProperty: true]))
        let model = LookRenderModel(camera: .classicSLR, adjustments: .neutral, framed: false, stampEnabled: false)
        for (name, factor) in [("12mp", 1.0), ("48mp", 2.0)] {
            let source = factor == 1 ? original : original.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
            let layout = BakeLayout(source: source.extent.size, frame: nil)
            let baked = renderer.picture(from: source, model: model, layout: layout, stamp: nil)
            let side = (200 * layout.scale).rounded()
            let region = CGRect(x: ((baked.extent.width - side) / 2).rounded(), y: ((baked.extent.height - side) / 2).rounded(), width: side, height: side)
            let crop = baked.cropped(to: region).transformed(by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
            let output = ReferencePairTests.pairs.appendingPathComponent("exceed-grain-\(name).png")
            try renderer.context.writePNGRepresentation(of: crop, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            #expect(FileManager.default.fileExists(atPath: output.path))
        }
    }

    /// (e) The selfie, an iPhone photo with lens, exposure, date and place in its EXIF, baked by the exporter as
    /// the Share sheet would get it.
    @Test(.enabled(if: ReferencePairTests.hasPairs))
    func exportsTheSelfieWithItsMetadata() async throws {
        let folder = PhotoLibraryFolder(url: FileManager.default.temporaryDirectory.appendingPathComponent("ExceedTests-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: folder.url) }
        let renderer = try LookRenderer()
        let exporter = PhotoExporter(folder: folder, renderer: renderer, clock: FixedClock.design)
        let data = try Data(contentsOf: ReferenceExportTests.inputs.appendingPathComponent("IMG_5821.JPG"))
        let image = try folder.store(original: data, id: "exceed", fileExtension: "jpg")
        let photo = Photo(id: "exceed", image: image, camera: .film, capturedAt: FixedClock.design.now)
        let baked = try #require(await exporter.bake(photo))
        let output = ReferencePairTests.pairs.appendingPathComponent("exceed-metadata.jpg")
        try baked.write(to: output)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    /// (b) The scene the mock camera shows, as the viewfinder shows it (filling the 390×844 screen from its
    /// centre, the look at the screen's points), baked through `LookRenderer` for every fitted camera.
    @Test(.enabled(if: ReferencePairTests.hasPairs), arguments: ReferencePairTests.fittedCameras)
    func bakesTheViewfinderScene(camera: CameraStyle) throws {
        let renderer = try LookRenderer()
        let scene = try #require(UIImage(named: "scene-back")?.cgImage)
        let original = CIImage(cgImage: scene)
        let screen = CGSize(width: 390, height: 844)
        let fill = max(screen.width / original.extent.width, screen.height / original.extent.height)
        let window = CGSize(width: (screen.width / fill).rounded(), height: (screen.height / fill).rounded())
        let region = CGRect(
            x: ((original.extent.width - window.width) / 2).rounded(), y: ((original.extent.height - window.height) / 2).rounded(),
            width: window.width, height: window.height
        )
        let crop = original.cropped(to: region).transformed(by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
        let model = LookRenderModel(camera: camera, adjustments: .neutral, framed: false, stampEnabled: false)
        let rendered = renderer.render(crop, model: model, scale: window.width / screen.width)
        let output = ReferencePairTests.pairs.appendingPathComponent("exceed-viewfinder-\(camera.rawValue).png")
        try renderer.context.writePNGRepresentation(of: rendered, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }
}
