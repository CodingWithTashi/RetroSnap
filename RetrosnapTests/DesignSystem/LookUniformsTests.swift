import Foundation
import Testing
@testable import Retrosnap

@MainActor
struct LookUniformsTests {

    private func uniforms(_ camera: CameraStyle, _ adjustments: PhotoAdjustments = .neutral) -> LookUniforms {
        LookUniforms(LookRenderModel(camera: camera, adjustments: adjustments, framed: false, stampEnabled: true))
    }

    @Test func filterStepsCarryTheShadersNumbering() {
        let operations = uniforms(.film).operations
        #expect(operations.map(\.kind) == [1, 2, 3, 4, 5])
        #expect(isClose(operations[0].amount, 0.34))
        #expect(isClose(operations[1].amount, 1.3))
        #expect(isClose(operations[2].amount, 1.06))
        #expect(isClose(operations[3].amount, 1.03))
        #expect(isClose(operations[4].amount, -8 * Double.pi / 180))
    }

    @Test func aShorterChainIsPaddedToTheShadersFiveSteps() {
        let operations = uniforms(.digicam).operations
        #expect(operations.map(\.kind) == [3, 2, 4, 0, 0])
        #expect(operations.count == 5)
    }

    @Test func coloursAreRawSRGBWithTheirOpacity() {
        let tint = uniforms(.film).tint
        #expect(isClose(tint.red, 1))
        #expect(isClose(tint.green, 154.0 / 255))
        #expect(isClose(tint.blue, 46.0 / 255))
        #expect(isClose(tint.opacity, 0.2))

        var warm = PhotoAdjustments.neutral
        warm.warmth = -30
        let wash = uniforms(.film, warm).warm
        #expect(isClose(wash.red, 47.0 / 255))
        #expect(isClose(wash.blue, 1))
        #expect(isClose(wash.opacity, 0.3))
    }

    @Test func aFilterChainCameraHasNoColourStage() {
        #expect(uniforms(.film).colorStage == nil)
        #expect(isClose(uniforms(.film).filmGrain.y, 0))
        #expect(isClose(uniforms(.film).halation.y, 0))
        #expect(isClose(uniforms(.film).soft.z, 0))
    }

    @Test func theColourStageIsPackedAsTwelveVectors() {
        let stage = try! #require(uniforms(.negative).colorStage)
        #expect(stage.count == 12)
        // The matrix rows with their offsets.
        #expect(isClose(stage[0].x, 1.0868))
        #expect(isClose(stage[0].w, -0.0158))
        #expect(isClose(stage[2].z, 0.8094))
        // Red: values at knots 0-3, then knots 4-5 and the first two tangents, then the last four tangents.
        let red = CameraStyle.negative.look.color!.curves[0]
        let tangents = LookUniforms.tangents(of: red)
        #expect(isClose(stage[3].x, red[0]))
        #expect(isClose(stage[3].w, red[3]))
        #expect(isClose(stage[4].x, red[4]))
        #expect(isClose(stage[4].y, red[5]))
        #expect(isClose(stage[4].z, tangents[0]))
        #expect(isClose(stage[4].w, tangents[1]))
        #expect(isClose(stage[5].x, tangents[2]))
        #expect(isClose(stage[5].w, tangents[5]))
        // Blue starts at the tenth vector.
        #expect(isClose(stage[9].x, CameraStyle.negative.look.color!.curves[2][0]))
    }

    @Test func tangentsOfAStraightLineAreItsSlope() {
        let line = ColorStage.knotPositions.map { $0 * 0.8 + 0.1 }
        for m in LookUniforms.tangents(of: line) {
            #expect(isClose(m, 0.8, tolerance: 1e-9))
        }
        for m in LookUniforms.tangents(of: [Double](repeating: 0.5, count: 6)) {
            #expect(isClose(m, 0))
        }
    }

    @Test func tangentsNeverOvershootTheirKnots() {
        // A step: Fritsch–Carlson pulls the tangents down to keep the curve monotone.
        let knots = [0.0, 0.0, 0.01, 0.99, 1.0, 1.0]
        let m = LookUniforms.tangents(of: knots)
        #expect(m[0] == 0 && m[1] == 0 && m[4] == 0 && m[5] == 0)
        #expect(m[2] >= 0 && m[3] >= 0)
        let steep = (knots[3] - knots[2]) / (ColorStage.knotPositions[3] - ColorStage.knotPositions[2])
        #expect(m[2] <= 3 * steep && m[3] <= 3 * steep)
    }

    @Test func filmLayersComeFromTheRenderModel() {
        let negative = uniforms(.negative)
        #expect(isClose(negative.filmGrain.x, 0.8))
        #expect(isClose(negative.filmGrain.y, 0.085))
        #expect(isClose(negative.filmGrain.z, 0.35))
        #expect(isClose(negative.halation.x, 0.8))
        #expect(isClose(negative.halation.y, 0.15))
        #expect(isClose(negative.halationTint.x, 1))
        #expect(isClose(negative.halationTint.y, 0x7A / 255.0))
        let plastic = uniforms(.plastic35)
        // No camera has soft corners since the plastic compact's export showed none; the layer packs as absent.
        #expect(isClose(plastic.soft.x, 0))
        #expect(isClose(plastic.soft.y, 1))
        #expect(isClose(plastic.soft.z, 0))
        #expect(isClose(plastic.halation.x, 0.75))
        #expect(isClose(plastic.halation.y, 0.1))
    }

    @Test func layerStrengthsComeFromTheRenderModel() {
        let camcorder = uniforms(.camcorder)
        #expect(isClose(camcorder.flash, 0))
        #expect(isClose(camcorder.fade, 0.05))
        #expect(isClose(camcorder.chroma, 0.5))
        #expect(isClose(camcorder.scan, 0.4))
        #expect(isClose(camcorder.vignette, 0.32))
        #expect(isClose(camcorder.grain, 0.22))

        var edited = PhotoAdjustments.neutral
        edited.exposure = 20
        edited.contrast = -10
        let light = uniforms(.film, edited)
        #expect(isClose(light.brightness, 1.2))
        #expect(isClose(light.contrast, 0.9))
    }
}
