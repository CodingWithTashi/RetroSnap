import SwiftUI

/// The only place the Metal look shaders are called as SwiftUI effects, so names and argument order live in one spot.
nonisolated enum LookShaders {
    /// The colour: a fitted camera's colour stage, or the design's CSS filter chain.
    static func color(_ model: LookRenderModel) -> Shader {
        let uniforms = LookUniforms(model)
        guard let stage = uniforms.colorStage else { return filterChain(uniforms.operations) }
        let v = stage.map(vector)
        return ShaderLibrary.rsColor(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11])
    }

    static func filterChain(_ filters: [LookFilter]) -> Shader {
        filterChain(LookUniforms.operations(filters))
    }

    private static func filterChain(_ operations: [LookUniforms.Operation]) -> Shader {
        let steps = operations.map { Shader.Argument.float2($0.kind, $0.amount) }
        return ShaderLibrary.rsFilterChain(steps[0], steps[1], steps[2], steps[3], steps[4])
    }

    static func overlays(_ model: LookRenderModel) -> Shader {
        let uniforms = LookUniforms(model)
        return ShaderLibrary.rsOverlays(
            .boundingRect,
            color(uniforms.tint),
            color(uniforms.warm),
            .float4(uniforms.flash, uniforms.fade, uniforms.chroma, uniforms.scan),
            .float2(uniforms.vignette, uniforms.grain),
            vector(uniforms.filmGrain)
        )
    }

    /// The glow halation spreads: run over the picture, then blurred and screened over it.
    static func halationGlow(_ model: LookRenderModel) -> Shader {
        let uniforms = LookUniforms(model)
        return ShaderLibrary.rsHalationGlow(vector(uniforms.halation), vector(uniforms.halationTint))
    }

    /// The mask through which the blurred copy shows: run over a white rectangle the size of the picture.
    static func softMask(_ model: LookRenderModel) -> Shader {
        ShaderLibrary.rsSoftMask(.boundingRect, vector(LookUniforms(model).soft))
    }

    static func adjust(brightness: Double, contrast: Double) -> Shader {
        ShaderLibrary.rsAdjust(.float(brightness), .float(contrast))
    }

    private static func color(_ color: LookUniforms.Color) -> Shader.Argument {
        .float4(color.red, color.green, color.blue, color.opacity)
    }

    private static func vector(_ vector: LookUniforms.Vector) -> Shader.Argument {
        .float4(vector.x, vector.y, vector.z, vector.w)
    }
}
