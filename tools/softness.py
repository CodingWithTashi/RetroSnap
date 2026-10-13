"""Fit a camera's blur from its reference pairs: the Gaussian radius, in points, that makes the input through
the camera's colour keep as much fine detail as the reference does (`tools/grain.py`'s "detail kept": the
high-pass standard deviation of 24x24 blocks where the input has texture, in the middle of the picture and
toward its corners).

    venv/bin/python -I tools/softness.py <id> ref/pairs/<pair> [ref/pairs/<pair> ...]

The input is blurred and then put through the camera's colour (its table `ref/pairs/<id>.cube` when it has one,
else its parametric fit `<id>.json`), in the pipeline's order, before its detail is measured: a look that
compresses contrast where the picture has texture (CT2F's tone curve keeps 0.72 of the input's detail with
no blur at all) would otherwise be taken for a blur. The reference's own grain inflates its high-pass a
little, so the radius found is a floor. Prints, per pair, the reference's detail kept in the middle and at the
corners, the radius that matches each, and the camera's `blurRadius` (the middle's, over the pairs) with
whether the corners want a `Softness` on top. Pairs wider than 1400 px are measured at half size.
"""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage  # noqa: E402
from halation import WINDOW_POINTS  # noqa: E402
from lut import evaluate, read_cube  # noqa: E402


def load(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255
    if rgb.shape[1] > 1400:
        rgb = rgb[::2, ::2].copy()
    return rgb


def luminance(rgb):
    return rgb @ [0.2126, 0.7152, 0.0722] * 255


def look_for(cam):
    """The camera's colour: a function of an sRGB picture, its table when it ships one, else its parametric fit."""
    cube_path = f"ref/pairs/{cam}.cube"
    if os.path.exists(cube_path):
        cube, size = read_cube(cube_path)
        return lambda rgb: evaluate(cube, size, rgb)
    p = ColourStage.from_json(json.load(open(f"ref/pairs/{cam}.json")))
    def apply(rgb):
        h, w = rgb.shape[:2]
        uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
        return ColourStage.apply(p, rgb, uv)
    return apply


def highpass(lum, sigma=2.5):
    return lum - ndimage.gaussian_filter(lum, sigma)


def detail(ha, hb, n=24):
    """(middle, corners): the median over textured blocks of hb's high-pass std over ha's."""
    H, W = ha.shape
    rows = []
    for y in range(0, H - n, n):
        for x in range(0, W - n, n):
            fa = ha[y:y + n, x:x + n]
            if fa.std() > 4:
                r = np.hypot((x + n / 2) / W - 0.5, (y + n / 2) / H - 0.5) / 0.70710678
                rows.append((r, hb[y:y + n, x:x + n].std() / fa.std()))
    rows = np.array(rows)
    mid = rows[rows[:, 0] < 0.5, 1]
    corner = rows[rows[:, 0] >= 0.5, 1]
    return (np.median(mid) if len(mid) else np.nan, np.median(corner) if len(corner) else np.nan)


def main(cam, prefixes):
    look = look_for(cam)
    radii = []
    for prefix in prefixes:
        rgb, ref = load(prefix + "-input.png"), load(prefix + "-reference.png")
        h, w = ref.shape[:2]
        scale = w / WINDOW_POINTS[cam][0 if w >= h else 1]
        a = luminance(rgb)
        ha, hb = highpass(a), highpass(luminance(ref))
        kept_mid, kept_corner = detail(ha, hb)
        # The input blurred by sigma (pixels) and then through the look: its detail kept, for a sweep of sigmas.
        sigmas = np.array([0.0, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.6, 2.0, 2.5, 3.0])
        kept = []
        for s in sigmas:
            blurred = np.stack([ndimage.gaussian_filter(rgb[..., c], s) for c in range(3)], -1) if s else rgb
            kept.append(detail(ha, highpass(luminance(look(blurred))))[0])
        kept = np.array(kept)
        def radius_for(target):
            if np.isnan(target) or target >= kept[0]:
                return 0.0
            i = int(np.argmax(kept < target))
            s = np.interp(target, [kept[i], kept[i - 1]], [sigmas[i], sigmas[i - 1]])
            return s / scale
        r_mid, r_corner = radius_for(kept_mid), radius_for(kept_corner)
        radii.append((r_mid, r_corner))
        print(f"{os.path.basename(prefix)}: {w}x{h}, {scale:.2f} px/pt; reference keeps {kept_mid:.2f} of the input's detail in the "
              f"middle and {kept_corner:.2f} at the corners; the look alone keeps {kept[0]:.2f} -> blur sigma {r_mid:.3f} pt in the middle, "
              f"{r_corner:.3f} pt at the corners")
    r = np.array(radii)
    print(f"{cam}: blurRadius {np.median(r[:, 0]):.2f} pt (median of the middles); corners {np.median(r[:, 1]):.2f} pt"
          + (" -> no Softness: the corners are no softer than the middle" if np.median(r[:, 1]) <= np.median(r[:, 0]) * 1.25 else " -> the corners are softer: a Softness on top"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
