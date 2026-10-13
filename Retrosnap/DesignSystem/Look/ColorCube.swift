import CoreGraphics
import CoreImage
import Foundation
import os
import SwiftUI

/// A camera's colour as a 3D lookup table, measured from its reference pairs by `tools/lut.py` and shipped as
/// `Resources/Looks/<name>.cube` (Adobe/Resolve text, red fastest). Both renderers interpolate it trilinearly in
/// gamma-encoded sRGB: the SwiftUI shader from the table laid out as a 2D texture, Core Image from `CIColorCube`.
nonisolated struct ColorCube: Sendable {
    let name: String
    /// Nodes along each axis.
    let size: Int
    /// RGB per node, blue slowest and red fastest: node (r, g, b) is at `((b * size + g) * size + r) * 3`.
    let values: [Float]

    /// The table at a colour, by trilinear interpolation, as the shaders do it.
    func apply(red: Double, green: Double, blue: Double) -> (red: Double, green: Double, blue: Double) {
        let last = Double(size - 1)
        func split(_ v: Double) -> (Int, Double) {
            let p = min(max(v, 0), 1) * last
            let i = min(Int(p.rounded(.down)), size - 2)
            return (i, p - Double(i))
        }
        let (ri, rf) = split(red), (gi, gf) = split(green), (bi, bf) = split(blue)
        var out = [0.0, 0.0, 0.0]
        for db in 0...1 {
            for dg in 0...1 {
                for dr in 0...1 {
                    let w = (dr == 1 ? rf : 1 - rf) * (dg == 1 ? gf : 1 - gf) * (db == 1 ? bf : 1 - bf)
                    let base = (((bi + db) * size + (gi + dg)) * size + (ri + dr)) * 3
                    for c in 0..<3 {
                        out[c] += w * Double(values[base + c])
                    }
                }
            }
        }
        return (out[0], out[1], out[2])
    }

    /// The table as `CIColorCube` takes it: RGBA floats, red fastest.
    var cubeData: Data {
        var floats = [Float]()
        floats.reserveCapacity(size * size * size * 4)
        for node in 0..<(size * size * size) {
            floats.append(values[node * 3])
            floats.append(values[node * 3 + 1])
            floats.append(values[node * 3 + 2])
            floats.append(1)
        }
        return floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// The table as a texture for the SwiftUI shader: `size` rows (green) of `size * size` columns (blue slices of
    /// red), 16 bits per channel in sRGB so that nothing is converted on the way to the shader.
    var texture: CGImage? {
        let width = size * size
        let height = size
        var pixels = [UInt16](repeating: 0, count: width * height * 4)
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let node = ((b * size + g) * size + r) * 3
                    let pixel = (g * width + b * size + r) * 4
                    for c in 0..<3 {
                        pixels[pixel + c] = UInt16((min(max(values[node + c], 0), 1) * 65535).rounded())
                    }
                    pixels[pixel + 3] = 65535
                }
            }
        }
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
        return CGImage(
            width: width, height: height, bitsPerComponent: 16, bitsPerPixel: 64, bytesPerRow: width * 8,
            space: space, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// The table in `Resources/Looks/<name>.cube` of the app bundle, or nil when it is missing or malformed.
    static func load(named name: String, in bundle: Bundle = .main) -> ColorCube? {
        guard let url = bundle.url(forResource: name, withExtension: "cube"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return parse(text, name: name)
    }

    static func parse(_ text: String, name: String) -> ColorCube? {
        var size = 0
        var values = [Float]()
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first, first != "#" else { continue }
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                size = Int(trimmed.split(separator: " ").last ?? "") ?? 0
                values.reserveCapacity(size * size * size * 3)
            } else if first.isNumber || first == "-" || first == "." {
                let parts = trimmed.split(separator: " ").compactMap { Float($0) }
                guard parts.count == 3 else { return nil }
                values.append(contentsOf: parts)
            }
        }
        guard size >= 2, values.count == size * size * size * 3 else { return nil }
        return ColorCube(name: name, size: size, values: values)
    }
}

/// The tables loaded so far, by name, for every thread that draws a look.
nonisolated enum ColorCubes {
    private struct Loaded: Sendable {
        let cube: ColorCube
        let texture: CGImage?
        let cubeData: Data
    }

    private static let loaded = OSAllocatedUnfairLock<[String: Loaded]>(initialState: [:])

    static func cube(named name: String) -> ColorCube? {
        entry(named: name)?.cube
    }

    /// The table as the SwiftUI shader samples it.
    static func texture(named name: String) -> CGImage? {
        entry(named: name)?.texture
    }

    /// The table as `CIColorCube` takes it.
    static func cubeData(named name: String) -> (data: Data, size: Int)? {
        entry(named: name).map { ($0.cubeData, $0.cube.size) }
    }

    private static func entry(named name: String) -> Loaded? {
        if let hit = loaded.withLock({ $0[name] }) { return hit }
        guard let cube = ColorCube.load(named: name) else { return nil }
        let made = Loaded(cube: cube, texture: cube.texture, cubeData: cube.cubeData)
        loaded.withLock { $0[name] = made }
        return made
    }
}
