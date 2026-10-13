import CoreGraphics
import Foundation
import Testing
@testable import Retrosnap

/// The colour tables: parsed from `.cube` text, interpolated as `tools/lut.py` does, and shipped for every
/// fitted camera.
@MainActor
struct ColorCubeTests {
    private let identity = """
    TITLE "identity"
    LUT_3D_SIZE 2
    0 0 0
    1 0 0
    0 1 0
    1 1 0
    0 0 1
    1 0 1
    0 1 1
    1 1 1
    """

    @Test func aTableIsParsedWithRedFastest() throws {
        let cube = try #require(ColorCube.parse(identity, name: "identity"))
        #expect(cube.size == 2)
        #expect(cube.values.count == 24)
        // Node (r 1, g 0, b 0) is the second triple.
        #expect(cube.values[3] == 1 && cube.values[4] == 0 && cube.values[5] == 0)
        let mid = cube.apply(red: 0.25, green: 0.5, blue: 0.75)
        #expect(isClose(mid.red, 0.25, tolerance: 1e-6))
        #expect(isClose(mid.green, 0.5, tolerance: 1e-6))
        #expect(isClose(mid.blue, 0.75, tolerance: 1e-6))
        #expect(ColorCube.parse("LUT_3D_SIZE 2\n0 0 0\n", name: "short") == nil)
    }

    @Test func theTextureAndTheCubeDataLayTheNodesOutForTheShaders() throws {
        let cube = try #require(ColorCube.parse(identity, name: "identity"))
        let data = cube.cubeData
        #expect(data.count == 8 * 4 * MemoryLayout<Float>.size)
        let floats = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        // The second node (r 1, g 0, b 0) as RGBA.
        #expect(floats[4] == 1 && floats[5] == 0 && floats[6] == 0 && floats[7] == 1)
        let texture = try #require(cube.texture)
        #expect(texture.width == 4 && texture.height == 2 && texture.bitsPerComponent == 16)
    }

    @Test(arguments: [
        (CameraStyle.tlr, 219.1, 106.5, 16.6),
        (.negative, 215.5, 126.1, 43.9),
        (.plastic35, 198.2, 121.0, 51.8),
        (.slide, 186.8, 116.0, 46.4),
        (.mediumFormat, 197.3, 112.0, 40.5),
(.film, 196.4, 140.8, 43.2),
        (.instant, 209.6, 143.1, 59.4),
        (.compactPro, 220.8, 176.2, 92.6),
        (.classicSLR, 214.7, 129.2, 42.2),
        (.instSquare, 210.0, 147.3, 61.1),
    ])
    func everyFittedCameraShipsItsTable(camera: CameraStyle, red: Double, green: Double, blue: Double) throws {
        let name = try #require(camera.look.colorCube)
        let cube = try #require(ColorCubes.cube(named: name))
        #expect(cube.size == 17)
        #expect(cube.values.allSatisfy { $0 >= 0 && $0 <= 1 })
        // The fixtures' orange, as `tools/lut.py` evaluates the same table.
        let out = cube.apply(red: 200 / 255, green: 120 / 255, blue: 40 / 255)
        #expect(isClose(out.red * 255, red, tolerance: 0.2))
        #expect(isClose(out.green * 255, green, tolerance: 0.2))
        #expect(isClose(out.blue * 255, blue, tolerance: 0.2))
        #expect(ColorCubes.texture(named: name) != nil)
        #expect(ColorCubes.cubeData(named: name)?.size == 17)
    }

    @Test func aCameraWithoutATableHasNone() {
        #expect(CameraStyle.disposable.look.colorCube == nil)
        #expect(ColorCubes.cube(named: "no-such-table") == nil)
    }
}
