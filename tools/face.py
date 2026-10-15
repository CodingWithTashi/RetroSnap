"""The face under a fit or under RetroSnap's render: the skin-tone pixels of the pictures that have a face (the
selfie, the tungsten interior, the backlit window: `FACE_REGION` in `tools/pairs.py`, mapped onto each pair through
its alignment), the reference against the parametric fit's prediction, or against RetroSnap's render with
`--render`, with the overall medians. A viewer judges a picture by the face first, and whole-picture medians hide it.

    venv/bin/python -I tools/face.py <id> [ref/pairs/<id>.json] [--render] [--mask <dir>]

`--mask` saves each face's pixel selection over the pair, to check that the region is the face and nothing else.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageOps

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, delta_e2000, srgb_to_lab  # noqa: E402
from pairs import FACE_LIGHTNESS, FACE_REGION, INPUTS, PAIRS, alignment_of, input_path, region_in_pair, suffix_of  # noqa: E402
from images import box, load_rgb as load  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def face_mask(pair, A):
    """Skin-tone boxes (4x4) of the pair's input, inside the picture's face region: None when it has no face."""
    suffix = suffix_of(pair)
    if suffix not in FACE_REGION:
        return None
    hh, ww = A.shape[:2]
    own = alignment_of(pair)
    yy, xx = np.mgrid[0:hh, 0:ww]
    if own is None:
        # No alignment on record (batch 1's first pairs): the selfie's face is in the upper middle of the pair.
        inside = (yy < 0.62 * hh) & (xx > 0.3 * ww) & (xx < 0.8 * ww)
    else:
        photo = ImageOps.exif_transpose(Image.open(input_path(suffix)))
        l, t, r, b = region_in_pair(FACE_REGION[suffix], own, photo.size, (ww * 4, hh * 4))
        inside = (yy * 4 >= t) & (yy * 4 < b) & (xx * 4 >= l) & (xx * 4 < r)
    lo, hi = FACE_LIGHTNESS[suffix]
    chroma = np.hypot(A[..., 1], A[..., 2])
    skin = ((A[..., 0] > lo) & (A[..., 0] < hi) & (A[..., 1] > 4) & (A[..., 1] < 28) & (A[..., 2] > 8) & (A[..., 2] < 38)
            & (chroma > 8) & (chroma < 40))
    return inside & skin


def main(argv):
    cam = argv[0]
    render = "--render" in argv
    mask_dir = argv[argv.index("--mask") + 1] if "--mask" in argv else None
    fit_path = next((a for a in argv[1:] if a.endswith(".json")), f"{R}/{cam}.json")
    p = ColourStage.from_json(json.load(open(fit_path)))
    for suffix in PAIRS[cam]:
        pair = cam + suffix
        if not os.path.exists(f"{R}/{pair}-input.png"):
            continue
        inp, ref = load(f"{R}/{pair}-input.png"), load(f"{R}/{pair}-reference.png")
        h, w = ref.shape[:2]
        if render:
            out = load(f"{R}/{pair}-retrosnap.png")
        else:
            uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
            out = ColourStage.apply(p, inp, uv)
        A, B, O = srgb_to_lab(box(inp)), srgb_to_lab(box(ref)), srgb_to_lab(box(out))
        m = int((0.06 if cam == "slide" else 0.02) * w) // 4
        de_all = np.median(delta_e2000(O[m:-m or None, m:-m or None], B[m:-m or None, m:-m or None]))
        skin = face_mask(pair, A)
        who = "RetroSnap" if render else "fit"
        if skin is None or skin.sum() < 20:
            print(f"{cam:13s} {pair:14s} {INPUTS[suffix][0]:9s} median dE {de_all:.2f}" + ("" if skin is None else " | face: too few skin pixels"))
            continue
        d = (O - B)[skin]
        print(f"{cam:13s} {pair:14s} {INPUTS[suffix][0]:9s} median dE {de_all:.2f} | face (n {skin.sum()}): reference L {B[..., 0][skin].mean():.1f} "
              f"a {B[..., 1][skin].mean():+.1f} b {B[..., 2][skin].mean():+.1f} | {who} L {O[..., 0][skin].mean():.1f} a {O[..., 1][skin].mean():+.1f} "
              f"b {O[..., 2][skin].mean():+.1f} | diff dL {d[:, 0].mean():+.1f} da {d[:, 1].mean():+.1f} db {d[:, 2].mean():+.1f} "
              f"| face dE {np.median(delta_e2000(O[skin], B[skin])):.2f}")
        if mask_dir:
            os.makedirs(mask_dir, exist_ok=True)
            shown = box(inp).copy()
            shown[skin] = shown[skin] * 0.3 + np.array([1.0, 0.0, 0.0]) * 0.7
            Image.fromarray((shown * 255).round().astype(np.uint8)).save(f"{mask_dir}/{pair}-face.png")


if __name__ == "__main__":
    main(sys.argv[1:])
