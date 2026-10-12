#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include <CoreImage/CoreImage.h>
using namespace metal;

// The camera looks from the design's Photo component. The maths is written once, as plain functions,
// and entered two ways: as SwiftUI colour effects for the screen, and as Core Image kernels for the
// files and video frames that leave the app.
// All maths runs on gamma-encoded sRGB and clamps after every step, as CSS filters and blend modes do.

// MARK: CSS filter functions (W3C Filter Effects)

// op.x: 0 none, 1 sepia, 2 saturate, 3 contrast, 4 brightness, 5 hue-rotate (radians). op.y: amount.
static float3 rs_filter(float3 c, float2 op) {
    int kind = int(op.x);
    float a = op.y;
    if (kind == 1) {
        float t = 1.0 - clamp(a, 0.0, 1.0);
        c = float3((0.393 + 0.607 * t) * c.r + (0.769 - 0.769 * t) * c.g + (0.189 - 0.189 * t) * c.b,
                   (0.349 - 0.349 * t) * c.r + (0.686 + 0.314 * t) * c.g + (0.168 - 0.168 * t) * c.b,
                   (0.272 - 0.272 * t) * c.r + (0.534 - 0.534 * t) * c.g + (0.131 + 0.869 * t) * c.b);
    } else if (kind == 2) {
        c = float3((0.213 + 0.787 * a) * c.r + (0.715 - 0.715 * a) * c.g + (0.072 - 0.072 * a) * c.b,
                   (0.213 - 0.213 * a) * c.r + (0.715 + 0.285 * a) * c.g + (0.072 - 0.072 * a) * c.b,
                   (0.213 - 0.213 * a) * c.r + (0.715 - 0.715 * a) * c.g + (0.072 + 0.928 * a) * c.b);
    } else if (kind == 3) {
        c = (c - 0.5) * a + 0.5;
    } else if (kind == 4) {
        c = c * a;
    } else if (kind == 5) {
        float co = cos(a);
        float si = sin(a);
        c = float3((0.213 + co * 0.787 - si * 0.213) * c.r + (0.715 - co * 0.715 - si * 0.715) * c.g + (0.072 - co * 0.072 + si * 0.928) * c.b,
                   (0.213 - co * 0.213 + si * 0.143) * c.r + (0.715 + co * 0.285 + si * 0.140) * c.g + (0.072 - co * 0.072 - si * 0.283) * c.b,
                   (0.213 - co * 0.213 - si * 0.787) * c.r + (0.715 - co * 0.715 + si * 0.715) * c.g + (0.072 + co * 0.928 + si * 0.072) * c.b);
    }
    return clamp(c, 0.0, 1.0);
}

static float3 rs_filterChain(float3 c, float2 op0, float2 op1, float2 op2, float2 op3, float2 op4) {
    c = rs_filter(c, op0);
    c = rs_filter(c, op1);
    c = rs_filter(c, op2);
    c = rs_filter(c, op3);
    c = rs_filter(c, op4);
    return c;
}

// MARK: Blend modes (W3C Compositing and Blending)

static float3 rs_overlay(float3 cb, float3 cs) {
    float3 lo = 2.0 * cb * cs;
    float3 hi = 1.0 - 2.0 * (1.0 - cb) * (1.0 - cs);
    return select(hi, lo, cb <= 0.5);
}

static float3 rs_softLight(float3 cb, float3 cs) {
    float3 d = select(sqrt(cb), ((16.0 * cb - 12.0) * cb + 4.0) * cb, cb <= 0.25);
    float3 lo = cb - (1.0 - 2.0 * cs) * cb * (1.0 - cb);
    float3 hi = cb + (2.0 * cs - 1.0) * (d - cb);
    return select(hi, lo, cs <= 0.5);
}

static float3 rs_screen(float3 cb, float3 cs) {
    return cb + cs - cb * cs;
}

// MARK: Grain (feTurbulence fractalNoise, baseFrequency 0.85, 2 octaves)

static uint rs_hash(uint x, uint y, uint seed) {
    uint h = x * 374761393u + y * 668265263u + seed * 2246822519u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return h ^ (h >> 16);
}

static float2 rs_gradient(int2 cell, uint seed) {
    float angle = float(rs_hash(uint(cell.x), uint(cell.y), seed) & 0xFFFFu) / 65536.0 * 6.28318530718;
    return float2(cos(angle), sin(angle));
}

static float rs_perlin(float2 p, uint seed) {
    float2 cellF = floor(p);
    float2 f = p - cellF;
    int2 cell = int2(cellF);
    float2 u = f * f * (3.0 - 2.0 * f);
    float n00 = dot(rs_gradient(cell, seed), f);
    float n10 = dot(rs_gradient(cell + int2(1, 0), seed), f - float2(1.0, 0.0));
    float n01 = dot(rs_gradient(cell + int2(0, 1), seed), f - float2(0.0, 1.0));
    float n11 = dot(rs_gradient(cell + int2(1, 1), seed), f - float2(1.0, 1.0));
    return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
}

static float rs_fractalNoise(float2 p, uint seed) {
    float sum = rs_perlin(p, seed) + rs_perlin(p * 2.0, seed) * 0.5;
    return clamp((sum + 1.0) * 0.5, 0.0, 1.0);
}

static float rs_linearToSRGB(float v) {
    return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055;
}

// MARK: Look layers

// p: the point inside the photo box, from its top-left corner. size: the box. tint/warm: rgb + opacity.
// fx: flash, fade, chroma, scanline opacities. fx2: vignette, grain opacities.
static float3 rs_overlays(float3 c, float2 p, float2 size, float4 tint, float4 warm, float4 fx, float2 fx2) {
    float2 uv = p / size;

    // Tint, overlay.
    c = mix(c, rs_overlay(c, tint.rgb), tint.a);

    // On-camera flash: radial-gradient(ellipse at 50% 42%, rgba(255,252,240,.95), transparent 62%), soft-light.
    {
        float t = length((uv - float2(0.5, 0.42)) / float2(0.70710678, 0.82024387));
        float a = 0.95 * (1.0 - clamp(t / 0.62, 0.0, 1.0));
        c = mix(c, rs_softLight(c, float3(1.0, 0.98823529, 0.94117647)), a * fx.x);
    }

    // Fade: flat #FFF1E2.
    c = mix(c, float3(1.0, 0.94509804, 0.88627451), fx.y);

    // Colour bleed: red in from the left edge, cyan in from the right, screen.
    {
        float left = 0.55 * (1.0 - clamp(uv.x / 0.22, 0.0, 1.0));
        float right = 0.55 * clamp((uv.x - 0.78) / 0.22, 0.0, 1.0);
        c = mix(c, rs_screen(c, float3(1.0, 0.15686275, 0.2745098)), left * fx.z);
        c = mix(c, rs_screen(c, float3(0.0, 0.8627451, 0.82352941)), right * fx.z);
    }

    // Scanlines: 1pt dark, 2pt clear, counted from the bottom edge.
    {
        float row = fmod(size.y - p.y, 3.0);
        c = mix(c, float3(0.0), (row < 1.0 ? 0.45 : 0.0) * fx.w);
    }

    // Vignette: radial-gradient(ellipse at center, transparent 48%, rgba(20,10,0,.9) 100%).
    {
        float t = length((uv - 0.5) / 0.70710678);
        float a = 0.9 * clamp((t - 0.48) / 0.52, 0.0, 1.0);
        c = mix(c, float3(0.07843137, 0.03921569, 0.0), a * fx2.x);
    }

    // Warmth slider, soft-light.
    c = mix(c, rs_softLight(c, warm.rgb), warm.a);

    // Grain, overlay. SVG filters work in linearRGB, so the grey is converted before blending;
    // the alpha channel is noise too, as fractalNoise produces.
    if (fx2.y > 0.0) {
        float2 g = p * 0.85;
        float luminance = 0.2126 * rs_fractalNoise(g, 1u) + 0.7152 * rs_fractalNoise(g, 2u) + 0.0722 * rs_fractalNoise(g, 3u);
        float grey = rs_linearToSRGB(luminance);
        float coverage = rs_fractalNoise(g, 4u);
        c = mix(c, rs_overlay(c, float3(grey)), coverage * fx2.y);
    }

    return clamp(c, 0.0, 1.0);
}

// The Light and Contrast sliders: filter: brightness() contrast() over the finished photo.
static float3 rs_adjust(float3 c, float brightness, float contrast) {
    c = clamp(c * brightness, 0.0, 1.0);
    return clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
}

// MARK: SwiftUI colour effects (the screen)

[[ stitchable ]] half4 rsFilterChain(float2 position, half4 color,
                                     float2 op0, float2 op1, float2 op2, float2 op3, float2 op4) {
    if (color.a <= 0.0h) { return color; }
    float alpha = float(color.a);
    float3 c = rs_filterChain(float3(color.rgb) / alpha, op0, op1, op2, op3, op4);
    return half4(half3(c * alpha), color.a);
}

// bounds: the photo box.
[[ stitchable ]] half4 rsOverlays(float2 position, half4 color, float4 bounds,
                                  float4 tint, float4 warm, float4 fx, float2 fx2) {
    if (color.a <= 0.0h) { return color; }
    float alpha = float(color.a);
    float2 size = max(bounds.zw, float2(1.0));
    float3 c = rs_overlays(float3(color.rgb) / alpha, position - bounds.xy, size, tint, warm, fx, fx2);
    return half4(half3(c * alpha), color.a);
}

[[ stitchable ]] half4 rsAdjust(float2 position, half4 color, float brightness, float contrast) {
    if (color.a <= 0.0h) { return color; }
    float alpha = float(color.a);
    float3 c = rs_adjust(float3(color.rgb) / alpha, brightness, contrast);
    return half4(half3(c * alpha), color.a);
}

// MARK: Core Image kernels (files and video frames)

[[ stitchable ]] float4 rsFilterChainKernel(coreimage::sample_t color,
                                            float2 op0, float2 op1, float2 op2, float2 op3, float2 op4) {
    if (color.a <= 0.0) { return color; }
    float3 c = rs_filterChain(color.rgb / color.a, op0, op1, op2, op3, op4);
    return float4(c * color.a, color.a);
}

// size: the photo box in points. scale: pixels per point, so grain, scanlines and gradients keep the
// size they have on screen. Core Image counts rows from the bottom; the look counts them from the top.
[[ stitchable ]] float4 rsOverlaysKernel(coreimage::sample_t color, float2 size, float scale,
                                         float4 tint, float4 warm, float4 fx, float2 fx2,
                                         coreimage::destination destination) {
    if (color.a <= 0.0) { return color; }
    float2 pixel = destination.coord();
    float2 p = float2(pixel.x / scale, size.y - pixel.y / scale);
    float3 c = rs_overlays(color.rgb / color.a, p, size, tint, warm, fx, fx2);
    return float4(c * color.a, color.a);
}

[[ stitchable ]] float4 rsAdjustKernel(coreimage::sample_t color, float brightness, float contrast) {
    if (color.a <= 0.0) { return color; }
    float3 c = rs_adjust(color.rgb / color.a, brightness, contrast);
    return float4(c * color.a, color.a);
}
