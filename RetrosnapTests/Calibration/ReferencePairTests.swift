import CoreImage
import Foundation
import Testing
@testable import Retrosnap

/// The calibration loop's render step (`docs/camera-lineup.md`, "Measuring a pair"): every reference pair of
/// every fitted camera in `ref/pairs` is drawn through the real pipeline, at the size the Viewer would give the
/// picture, and written beside the pair as `<pair>-retrosnap.png` for `tools/compare.py` to measure.
/// Runs only on a machine that has the reference material, which git ignores.
@MainActor
struct ReferencePairTests {
    /// `ref/pairs` in the repository this file lives in.
    nonisolated static let pairs = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("ref/pairs")

    nonisolated static var hasPairs: Bool {
        FileManager.default.fileExists(atPath: pairs.appendingPathComponent("negative-input.png").path)
    }

    /// The cameras fitted from reference pairs: batch 1, then batch 2 (which re-tuned D Classic and Inst C).
    nonisolated static let fittedCameras: [CameraStyle] = [
        .negative, .plastic35, .slide, .mediumFormat, .tlr, .film, .instant, .compactPro, .classicSLR, .instSquare,
    ]

    /// The pairs a camera has: `<id>` for the picture it was first fitted on, then `<id>-1`, `<id>-2`, … for
    /// each picture added since, as `tools/pairs.py` names them (a camera can skip a number: batch 1 has no
    /// `-2`, the street sign, but has `-3` to `-6`, the refinement round's pictures).
    nonisolated static func pairNames(for camera: CameraStyle) -> [String] {
        let id = camera.rawValue
        return [id] + (1...9).map { "\(id)-\($0)" }.filter {
            FileManager.default.fileExists(atPath: pairs.appendingPathComponent("\($0)-input.png").path)
        }
    }

    @Test(.enabled(if: hasPairs), arguments: fittedCameras)
    func rendersEveryReferencePair(camera: CameraStyle) throws {
        let renderer = try LookRenderer()
        let model = LookRenderModel(camera: camera, adjustments: .neutral, framed: false, stampEnabled: false)
        for name in Self.pairNames(for: camera) {
            let input = Self.pairs.appendingPathComponent("\(name)-input.png")
            let source = try #require(CIImage(contentsOf: input))
            // The pair is the window's content, the way up the input was; scale it as the Viewer shows that
            // window of a 3:4 photo taken that way up, on the camera's own canvas at the Viewer's width.
            let portrait = source.extent.height > source.extent.width
            let photoAspect: CGFloat = portrait ? 3.0 / 4 : 4.0 / 3
            let layout = BakeLayout(source: CGSize(width: 3000 * photoAspect, height: 3000), frame: camera.look.frame)
            let scale = source.extent.width / layout.pointSize.width
            let rendered = renderer.render(source, model: model, scale: scale)
            let output = Self.pairs.appendingPathComponent("\(name)-retrosnap.png")
            try renderer.context.writePNGRepresentation(
                of: rendered, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            )
            #expect(FileManager.default.fileExists(atPath: output.path))
        }
    }
}
