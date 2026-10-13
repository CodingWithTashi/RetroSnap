"""Measure a print camera's canvas from the reference app's export: the sheet, the print on it, the window in
the print, the print's outline and shadow, and the paper's colour, as fractions the app draws from.

    venv/bin/python -I tools/printscan.py <export> [<export> ...] [--corners <dir>]

The export is the whole canvas: a white sheet with the print on it. The print's edges are where the sheet stops
being white (median luminance profiles through the middle of the canvas); the window's edges are the strongest
luminance steps inside the print along many lines, so the picture's own content averages out. Prints the print
and window rectangles in pixels and as fractions of the canvas and of the window, the paper's colour just outside
the window on each side (sRGB), and the luminance across the print's edge on each side (outline and shadow).
`--corners` saves 1:1 crops of the window's and the print's corners for drawing them.
"""
import io
import os
import sys
import numpy as np
from PIL import Image, ImageCms, ImageOps
from scipy import ndimage


def load(path):
    image = ImageOps.exif_transpose(Image.open(path))
    icc = image.info.get("icc_profile")
    image = image.convert("RGB")
    if icc:
        profile = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        if "sRGB" not in (ImageCms.getProfileDescription(profile) or ""):
            image = ImageCms.profileToProfile(image, profile, ImageCms.createProfile("sRGB"), outputMode="RGB")
    return np.asarray(image).astype(np.float64)


def first_below(profile, value, start, step):
    i = start
    while 0 <= i < len(profile):
        if profile[i] < value:
            return i
        i += step
    return None


def strongest_step(lum, axis, lo, hi, lines):
    """The index in lo..hi where the luminance along `axis` steps most, over the median of `lines` rows/columns."""
    prof = np.median(lum[lines, :] if axis == 1 else lum[:, lines], axis=0 if axis == 1 else 1)
    d = np.abs(np.diff(ndimage.gaussian_filter1d(prof, 1.5)))
    d[:lo] = 0
    d[hi:] = 0
    return int(np.argmax(d)) + 1


def main(paths, corners=None):
    for path in paths:
        rgb = load(path)
        H, W = rgb.shape[:2]
        lum = rgb @ [0.2126, 0.7152, 0.0722]
        name = os.path.basename(path)
        # The print: where the sheet (255 white) ends, along the middle row and column.
        row = np.median(lum[H // 2 - 50:H // 2 + 50], axis=0)
        col = np.median(lum[:, W // 2 - 50:W // 2 + 50], axis=1)
        px0 = first_below(row, 253, 0, 1)
        px1 = first_below(row, 253, W - 1, -1) + 1
        py0 = first_below(col, 253, 0, 1)
        py1 = first_below(col, 253, H - 1, -1) + 1
        # The window: the strongest steps inside the print, over many lines through its middle.
        inner_y = np.arange(py0 + (py1 - py0) * 0.3, py0 + (py1 - py0) * 0.6, 7).astype(int)
        inner_x = np.arange(px0 + (px1 - px0) * 0.3, px0 + (px1 - px0) * 0.7, 7).astype(int)
        pad = 40
        wx0 = strongest_step(lum, 1, px0 + pad, px0 + (px1 - px0) // 3, inner_y)
        wx1 = strongest_step(lum, 1, px0 + (px1 - px0) * 2 // 3, px1 - pad, inner_y)
        wy0 = strongest_step(lum, 0, py0 + pad, py0 + (py1 - py0) // 3, inner_x)
        wy1 = strongest_step(lum, 0, py0 + (py1 - py0) * 2 // 3, py1 - pad, inner_x)
        pw, ph, ww, wh = px1 - px0, py1 - py0, wx1 - wx0, wy1 - wy0
        print(f"{name}: canvas {W}x{H}")
        print(f"  print x {px0}..{px1} y {py0}..{py1}: {pw}x{ph}, ratio {pw / ph:.4f}; margins left {px0 / W:.4f} right {(W - px1) / W:.4f} "
              f"top {py0 / H:.4f} bottom {(H - py1) / H:.4f} of the canvas; print {pw / W:.4f} of the canvas width")
        print(f"  window x {wx0}..{wx1} y {wy0}..{wy1}: {ww}x{wh}, ratio {ww / wh:.4f}; borders (of the window width) "
              f"left {(wx0 - px0) / ww:.4f} right {(px1 - wx1) / ww:.4f} top {(wy0 - py0) / ww:.4f} bottom {(py1 - wy1) / ww:.4f}")
        # Paper colour just outside the window, per side (the band from 30 to 90 px out).
        bands = {
            "left": rgb[wy0 + 100:wy1 - 100, max(px0, wx0 - 90):wx0 - 30], "right": rgb[wy0 + 100:wy1 - 100, wx1 + 30:min(px1, wx1 + 90)],
            "top": rgb[max(py0, wy0 - 90):wy0 - 30, wx0 + 100:wx1 - 100], "bottom": rgb[wy1 + 30:min(py1, wy1 + 90), wx0 + 100:wx1 - 100],
            "bottom far": rgb[py1 - 120:py1 - 60, wx0 + 100:wx1 - 100],
        }
        print("  paper (sRGB median): " + "; ".join(f"{k} {np.median(v.reshape(-1, 3), axis=0).round(1)}" for k, v in bands.items() if v.size))
        # Across the print's edges: the luminance from 12 px inside to 40 px outside, in steps of 4.
        for side, prof, edge, direction in (("left", row, px0, -1), ("right", row, px1 - 1, 1), ("top", col, py0, -1), ("bottom", col, py1 - 1, 1)):
            vals = [f"{k:+d}:{prof[edge + direction * k]:.0f}" for k in range(-12, 41, 4) if 0 <= edge + direction * k < len(prof)]
            print(f"  across the {side} edge (px out of the print): " + " ".join(vals))
        if corners:
            os.makedirs(corners, exist_ok=True)
            base = os.path.splitext(name)[0].replace(" ", "_")
            for tag, (x, y) in {"window-tl": (wx0, wy0), "window-br": (wx1, wy1), "print-tl": (px0, py0), "print-br": (px1, py1)}.items():
                crop = rgb[max(0, y - 150):y + 150, max(0, x - 150):x + 150]
                Image.fromarray(crop.round().astype(np.uint8)).save(f"{corners}/{base}-{tag}.png")


if __name__ == "__main__":
    args = sys.argv[1:]
    corners = None
    if "--corners" in args:
        i = args.index("--corners"); corners = args[i + 1]; del args[i:i + 2]
    main(args, corners)
