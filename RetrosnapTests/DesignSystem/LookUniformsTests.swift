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
