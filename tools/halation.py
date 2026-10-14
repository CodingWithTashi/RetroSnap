"""Fit a camera's halation from its reference pairs: the glow the reference spreads around highlights, measured
as what the colour-only fit leaves unexplained next to bright input pixels.

    venv/bin/python tools/halation.py <id> ref/pairs/<pair> [ref/pairs/<pair> ...] [--fit ref/pairs/<id>.json] [--fine] [--wide] [--blur r]

For each pair the colour stage in the camera's fit is applied to the input with the glow in front of it, exactly
as the pipeline does (the highlights above a threshold, as `rs_halationGlow` keeps them, blurred by the radius
in points and screened over the picture, then the colour stage): a grid of threshold, radius, amount and tint is
scored by the mean ΔE2000 of the result against the reference over 4x4 boxes (the mean, not the median: the glow
touches a minority of pixels), summed over the pairs. Prints the best setting as the `Halation(...)` literal,
with the lightness the reference adds next to highlights and what the setting adds. `--blur r` is the camera's
`blurRadius` in points (`tools/softness.py`), applied after the glow and before the colour stage as the pipeline
does, so a blurred camera's spread highlights are not taken for glow; `--wide` adds 10 and 16 pt to the fine
grid's radii.
"""
import json
import os
import re
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, delta_e2000, srgb_to_lab  # noqa: E402

LUMA = np.array([0.2126, 0.7152, 0.0722])
TINTS = {"white": (1.0, 1.0, 1.0), "cool": (0.88, 0.94, 1.0), "warm": (1.0, 0.54, 0.31)}

# The picture's width in points as the Viewer shows it (the frame's window in a 390pt canvas), by camera and
# orientation, so a radius in points becomes pixels on the pair.
WINDOW_POINTS = {
    "negative": (390 * 36 / 38, 390 * 24 / 31.96),
    "plastic35": (390.0, 390.0),
    "slide": (390 * 0.81 * 0.67, 390 * 0.81 * 0.46),
    "mediumFormat": (1.25 * 390 / 1.325, 390 / 1.135),
    "tlr": (390 / 1.086, 390 / 1.086),
    # Batch 2: the bare 3:2 crop is the whole canvas; the mini print's window on its 2:3 sheet (lying down the
    # sheet is 260 pt tall and the window 1.0129 of that; standing up 0.7597 of 390); the square print's window.
    "film": (390.0, 390.0),
    "compactPro": (390.0, 390.0),
    "classicSLR": (390.0, 390.0),
    "inst": (260 * 1.0129, 390 * 0.7597),
    "instSquare": (390 * 0.7628, 390 * 0.7628),
}


# The first pass over every setting; `--fine` looks closer where the first pass ends up (tight, white glows).
COARSE_GRID = {"threshold": (0.6, 0.7, 0.8, 0.9), "radius": (3, 6, 10, 16, 24), "amount": (0.15, 0.3, 0.5, 0.75, 1.0), "tint": tuple(TINTS)}
FINE_GRID = {"threshold": (0.4, 0.5, 0.6, 0.7), "radius": (0.75, 1.5, 2.5, 4, 6), "amount": (0.15, 0.25, 0.4, 0.6), "tint": ("white", "cool")}
WIDE_GRID = {"threshold": (0.4, 0.5, 0.6, 0.7), "radius": (0.75, 1.5, 2.5, 4, 6, 10, 16), "amount": (0.15, 0.25, 0.4, 0.6), "tint": ("white", "cool")}


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255


def box(a, n=4):
    h, w = a.shape[0] // n, a.shape[1] // n
    return a[: h * n, : w * n].reshape(h, n, w, n, 3).mean(axis=(1, 3))


def glow_of(photo, threshold, amount, tint):
    lum = photo @ LUMA
    k = np.clip((lum - threshold) / max(1 - threshold, 0.001), 0, 1)
    return np.clip(np.asarray(tint)[None, None, :] * (k * k * amount)[..., None], 0, 1)


def spread_of(photo, threshold, sigma):
    """The glow's shape for one threshold and radius: the blurred k², which every amount and tint then scales.
    The clip in `glow_of` never bites while amount and tint are at most 1, and the blur is linear, so this is
    the same glow computed once per (threshold, radius) instead of once per setting."""
    lum = photo @ LUMA
    k = np.clip((lum - threshold) / max(1 - threshold, 0.001), 0, 1)
    return ndimage.gaussian_filter(k * k, sigma, mode="nearest")


def with_halation(photo, threshold, amount, tint, sigma, spread=None):
    if spread is None:
        spread = spread_of(photo, threshold, sigma)
    blurred = spread[..., None] * (np.asarray(tint) * amount)[None, None, :]
    return photo + blurred - photo * blurred


def blurred(photo, sigma):
    if sigma <= 0:
        return photo
    return np.stack([ndimage.gaussian_filter(photo[..., c], sigma, mode="nearest") for c in range(3)], -1)


def main(argv):
    cam = argv[0]
    fit_path = f"ref/pairs/{cam}.json"
    prefixes = []
    blur = 0.0
    i = 1
    while i < len(argv):
        if argv[i] == "--fit":
            fit_path = argv[i + 1]
            i += 2
        elif argv[i] in ("--fine", "--wide"):
            i += 1
        elif argv[i] == "--blur":
            blur = float(argv[i + 1])
            i += 2
        else:
            prefixes.append(argv[i])
            i += 1
    p = ColourStage.from_json(json.load(open(fit_path)))
    pairs = []
    for prefix in prefixes:
        inp, ref = load(prefix + "-input.png"), load(prefix + "-reference.png")
        # A full-resolution export is measured at a quarter of its size, a screenshot-sized pair at half: the
        # glow is a few points wide either way, and the grid is scored on 4x4 boxes of what is left.
        step = 4 if ref.shape[1] > 2800 else 2 if ref.shape[1] > 1400 else 1
        if step > 1:
            # Copies, so the full-size arrays are freed rather than kept alive behind the views.
            inp, ref = inp[::step, ::step].copy(), ref[::step, ::step].copy()
        h, w = ref.shape[:2]
        landscape = w >= h
        window = WINDOW_POINTS[cam][0 if landscape else 1]
        scale = w / window
        uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
        m = int((0.06 if cam == "slide" else 0.03) * w)
        lab_ref = srgb_to_lab(box(ref)[m // 4: -(m // 4) or None, m // 4: -(m // 4) or None])
        lum_in = inp @ LUMA
        bright = lum_in > 0.9
        near = ndimage.binary_dilation(bright, iterations=12) & ~ndimage.binary_dilation(bright, iterations=2) & (lum_in < 0.55)
        pairs.append((os.path.basename(prefix), inp, ref, uv, scale, m, lab_ref, near))
        plain = ColourStage.apply(p, blurred(inp, blur * scale), uv)
        d = srgb_to_lab(ref) - srgb_to_lab(plain)
        print(f"{os.path.basename(prefix)}: {w}x{h}, {scale:.2f} px/pt; next to highlights the reference is "
              f"dL {d[near][:, 0].mean():+.2f} da {d[near][:, 1].mean():+.2f} db {d[near][:, 2].mean():+.2f} off the colour-only fit "
              f"(n {near.sum()}); colour-only mean ΔE {delta_e2000(srgb_to_lab(box(plain)[m // 4: -(m // 4) or None, m // 4: -(m // 4) or None]), lab_ref).mean():.3f}")

    spreads = {}  # (threshold, radius) -> the glow's shape per pair, shared by the amounts and tints of the grid's inner loops

    def score(threshold, amount, tint, radius):
        total = 0.0
        if spreads.get("key") != (threshold, radius):
            spreads.clear()
            spreads["key"] = (threshold, radius)
            for name, inp, ref, uv, scale, m, lab_ref, near in pairs:
                spreads[name] = spread_of(inp, threshold, radius * scale)
        for name, inp, ref, uv, scale, m, lab_ref, near in pairs:
            out = ColourStage.apply(p, blurred(with_halation(inp, threshold, amount, TINTS[tint], radius * scale, spreads[name]), blur * scale), uv)
            de = delta_e2000(srgb_to_lab(box(out)[m // 4: -(m // 4) or None, m // 4: -(m // 4) or None]), lab_ref)
            total += de.mean()
        return total / len(pairs)

    base = score(0.9, 0.0, "white", 1)
    best = (base, None)
    results = []
    grid = WIDE_GRID if "--wide" in sys.argv else FINE_GRID if "--fine" in sys.argv else COARSE_GRID
    for threshold in grid["threshold"]:
        for radius in grid["radius"]:
            for amount in grid["amount"]:
                for tint in grid["tint"]:
                    s = score(threshold, amount, tint, radius)
                    results.append((s, threshold, radius, amount, tint))
                    if s < best[0]:
                        best = (s, (threshold, radius, amount, tint))
    results.sort()
    print(f"\n{cam}: colour-only mean ΔE {base:.3f}; best with halation {best[0]:.3f}")
    for s, t, r, a, tint in results[:8]:
        print(f"  mean ΔE {s:.3f}: threshold {t}, radius {r}pt, amount {a}, tint {tint}")
    if best[1]:
        t, r, a, tint = best[1]
        hexes = {"white": "0xFFFFFF", "cool": "0xE0F0FF", "warm": "0xFF8A50"}
        print(f"\nHalation(threshold: {t}, radius: {r}, amount: {a}, tintHex: {hexes[tint]})")
        for name, inp, ref, uv, scale, m, lab_ref, near in pairs:
            out = ColourStage.apply(p, blurred(with_halation(inp, t, a, TINTS[tint], r * scale), blur * scale), uv)
            d = srgb_to_lab(out) - srgb_to_lab(ColourStage.apply(p, blurred(inp, blur * scale), uv))
            print(f"  {name}: this setting adds dL {d[near][:, 0].mean():+.2f} da {d[near][:, 1].mean():+.2f} db {d[near][:, 2].mean():+.2f} next to highlights")


if __name__ == "__main__":
    main(sys.argv[1:])
