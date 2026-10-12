import SwiftUI

/// The only place the Metal look shaders are called as SwiftUI effects, so names and argument order live in one spot.
nonisolated enum LookShaders {
    static func filterChain(_ filters: [LookFilter]) -> Shader {
        let operations = LookUniforms.operations(filters).map { Shader.Argument.float2($0.kind, $0.amount) }
        return ShaderLibrary.rsFilterChain(operations[0], operations[1], operations[2], operations[3], operations[4])
    }

    static func overlays(_ model: LookRenderModel) -> Shader {
        let uniforms = LookUniforms(model)
        return ShaderLibrary.rsOverlays(
            .boundingRect,
            color(uniforms.tint),
            color(uniforms.warm),
            .float4(uniforms.flash, uniforms.fade, uniforms.chroma, uniforms.scan),
            .float2(uniforms.vignette, uniforms.grain)
        )
    }

    static func adjust(brightness: Double, contrast: Double) -> Shader {
        ShaderLibrary.rsAdjust(.float(brightness), .float(contrast))
    }

    private static func color(_ color: LookUniforms.Color) -> Shader.Argument {
        .float4(color.red, color.green, color.blue, color.opacity)
    }
}
