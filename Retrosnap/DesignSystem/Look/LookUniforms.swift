import Foundation

/// The numbers the Metal look functions take, worked out once from a render model.
/// The SwiftUI shaders and the Core Image kernels both read them from here.
nonisolated struct LookUniforms: Hashable, Sendable {
    /// One CSS filter step as the shader reads it.
    struct Operation: Hashable, Sendable {
        /// 0 none, 1 sepia, 2 saturate, 3 contrast, 4 brightness, 5 hue-rotate.
        let kind: Double
        /// The filter's amount; radians for hue-rotate.
        let amount: Double

        static let none = Operation(kind: 0, amount: 0)
    }

    /// Raw sRGB components and an opacity, so the shader sees the same numbers CSS does.
    struct Color: Hashable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double

        init(hex: UInt32, opacity: Double) {
            (red, green, blue) = rgbComponents(hex: hex)
            self.opacity = opacity
        }
    }

    /// Four numbers, as one `float4` argument of a shader.
    struct Vector: Hashable, Sendable {
        let x: Double
        let y: Double
        let z: Double
        let w: Double
    }

    /// The length of the filter chain in the shader.
    static let operationCount = 5

    let operations: [Operation]
    let tint: Color
    let warm: Color
    let flash: Double
    let fade: Double
    let chroma: Double
    let scan: Double
    let vignette: Double
    let grain: Double
    let brightness: Double
    let contrast: Double
    /// The colour stage as the shader's twelve `float4`s: the matrix rows with their offsets, then for each channel
    /// the curve's six values and six tangents. Nil for a camera drawn by its filter chain.
    let colorStage: [Vector]?
    /// Film grain: clump size, amount, colour; zero amount when there is none.
    let filmGrain: Vector
    /// Halation: threshold, amount; and its tint.
    let halation: Vector
    let halationTint: Vector
    /// Softness: inner, outer, strength.
    let soft: Vector

    init(_ model: LookRenderModel) {
        operations = Self.operations(model.filters)
        tint = Color(hex: model.tintHex, opacity: model.tintOpacity)
        warm = Color(hex: model.warmHex, opacity: model.warmOpacity)
        flash = model.flashOpacity
        fade = model.fadeOpacity
        chroma = model.chromaOpacity
        scan = model.scanOpacity
        vignette = model.vignetteOpacity
        grain = model.grainOpacity
        brightness = model.brightness
        contrast = model.contrast
        colorStage = model.color.map(Self.vectors)
        filmGrain = model.filmGrain.map { Vector(x: $0.size, y: $0.amount, z: $0.color, w: 0) } ?? Vector(x: 1, y: 0, z: 0, w: 0)
        halation = model.halation.map { Vector(x: $0.threshold, y: $0.amount, z: 0, w: 0) } ?? Vector(x: 1, y: 0, z: 0, w: 0)
        let glow = Color(hex: model.halation?.tintHex ?? 0, opacity: 1)
        halationTint = Vector(x: glow.red, y: glow.green, z: glow.blue, w: 1)
        soft = model.soft.map { Vector(x: $0.inner, y: $0.outer, z: $0.strength, w: 0) } ?? Vector(x: 0, y: 1, z: 0, w: 0)
    }

    /// A filter chain as exactly `operationCount` steps, padded with steps that do nothing.
    static func operations(_ filters: [LookFilter]) -> [Operation] {
        let steps = filters.prefix(operationCount).map { filter in
            switch filter {
            case .sepia(let amount): Operation(kind: 1, amount: amount)
            case .saturate(let amount): Operation(kind: 2, amount: amount)
            case .contrast(let amount): Operation(kind: 3, amount: amount)
            case .brightness(let amount): Operation(kind: 4, amount: amount)
            case .hueRotate(let degrees): Operation(kind: 5, amount: degrees * .pi / 180)
            }
        }
        return steps + Array(repeating: .none, count: operationCount - steps.count)
    }

    /// The colour stage packed for the shader: three matrix rows, then per channel the values at knots 0-3,
    /// the values at knots 4-5 with the tangents at knots 0-1, and the tangents at knots 2-5.
    static func vectors(_ stage: ColorStage) -> [Vector] {
        var vectors = stage.matrix.map { Vector(x: $0[0], y: $0[1], z: $0[2], w: $0[3]) }
        for values in stage.curves {
            let m = tangents(of: values)
            vectors.append(Vector(x: values[0], y: values[1], z: values[2], w: values[3]))
            vectors.append(Vector(x: values[4], y: values[5], z: m[0], w: m[1]))
            vectors.append(Vector(x: m[2], y: m[3], z: m[4], w: m[5]))
        }
        return vectors
    }

    /// Fritsch–Carlson tangents at the knots: the cubic through them is monotone wherever the values are.
    /// The same sums as `hermite_tangents` in `tools/colour.py`.
    static func tangents(of values: [Double]) -> [Double] {
        let x = ColorStage.knotPositions
        let n = values.count
        var d = [Double](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            d[i] = (values[i + 1] - values[i]) / (x[i + 1] - x[i])
        }
        var m = [Double](repeating: 0, count: n)
        m[0] = d[0]
        m[n - 1] = d[n - 2]
        for i in 1..<(n - 1) {
            m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2
        }
        for i in 0..<(n - 1) {
            if d[i] == 0 {
                m[i] = 0
                m[i + 1] = 0
                continue
            }
            let a = m[i] / d[i]
            let b = m[i + 1] / d[i]
            let s = a * a + b * b
            if s > 9 {
                let t = 3 / s.squareRoot()
                m[i] = t * a * d[i]
                m[i + 1] = t * b * d[i]
            }
        }
        return m
    }
}
