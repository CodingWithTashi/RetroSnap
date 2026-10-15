"""The whites under RetroSnap's render against the reference: the near-white pixels of the input in the region a
viewer looks at (`WHITES_REGION` in `tools/pairs.py`: the backlit picture's window, the market's price card, the
grey wall; mapped onto each pair through its alignment), as mean L, a, b of the reference and of RetroSnap, their
difference, and the median ΔE2000 over those pixels. A cast on a white is what a viewer sees first after the face.

    venv/bin/python -I tools/whites.py <id> [...] [--fit]

With `--fit` the camera's colour (its table) over the input stands in for the render.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageOps

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import delta_e2000, srgb_to_lab  # noqa: E402
from lut import evaluate, read_cube  # noqa: E402
from pairs import INPUTS, PAIRS, WHITES_NAME, WHITES_REGION, alignment_of, input_path, region_in_pair  # noqa: E402
from images import box, load_rgb as load  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def whites_mask(pair, suffix, A):
    """The 4x4 boxes inside the picture's white region whose input is light and near neutral."""
    hh, ww = A.shape[:2]
    own = alignment_of(pair)
    photo = ImageOps.exif_transpose(Image.open(input_path(suffix)))
    l, t, r, b = region_in_pair(WHITES_REGION[suffix], own, photo.size, (ww * 4, hh * 4))
    yy, xx = np.mgrid[0:hh, 0:ww]
    inside = (yy * 4 >= t) & (yy * 4 < b) & (xx * 4 >= l) & (xx * 4 < r)
    chroma = np.hypot(A[..., 1], A[..., 2])
    # The wall is a light grey, the window and the card are white.
    lo = 60 if suffix == "-6" else 82
    return inside & (A[..., 0] > lo) & (chroma < 10)


def main(argv):
    use_fit = "--fit" in argv
    for cam in [a for a in argv if not a.startswith("--")]:
        for suffix in PAIRS[cam]:
            if suffix not in WHITES_REGION:
                continue
            pair = cam + suffix
            if not os.path.exists(f"{R}/{pair}-input.png"):
                continue
            inp, ref = load(f"{R}/{pair}-input.png"), load(f"{R}/{pair}-reference.png")
            if use_fit:
                cube, size = read_cube(f"{R}/{cam}.cube")
                out = evaluate(cube, size, inp)
            else:
                out = load(f"{R}/{pair}-retrosnap.png")
            A, B, O = srgb_to_lab(box(inp)), srgb_to_lab(box(ref)), srgb_to_lab(box(out))
            sel = whites_mask(pair, suffix, A)
            if sel.sum() < 20:
                print(f"{cam:13s} {pair:14s} {WHITES_NAME[suffix]}: too few white pixels ({sel.sum()})")
                continue
            d = (O - B)[sel]
            print(f"{cam:13s} {pair:14s} {WHITES_NAME[suffix]:14s} (n {sel.sum():5d}): reference L {B[..., 0][sel].mean():5.1f} a {B[..., 1][sel].mean():+.1f} "
                  f"b {B[..., 2][sel].mean():+.1f} | {'fit' if use_fit else 'RetroSnap'} L {O[..., 0][sel].mean():5.1f} a {O[..., 1][sel].mean():+.1f} b {O[..., 2][sel].mean():+.1f} "
                  f"| diff dL {d[:, 0].mean():+.1f} da {d[:, 1].mean():+.1f} db {d[:, 2].mean():+.1f} | dE {np.median(delta_e2000(O[sel], B[sel])):.2f}")


if __name__ == "__main__":
    main(sys.argv[1:])
