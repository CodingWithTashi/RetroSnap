"""Measure RetroSnap's render of a reference pair against the reference, and against the Python fit.

    venv/bin/python tools/compare.py ref/pairs/<pair> [...] [--fit <json>] [--plain]

A pair is `<id>` (the picture the camera was first fitted on) or `<id>-<n>` (a picture added since). Reads
`<pair>-input.png`, `<pair>-reference.png` and `<pair>-retrosnap.png` (written by `ReferencePairTests`), and the
camera's fit `<id>.json` beside them: the fit that is transcribed into `CameraLook.swift`, whatever pair it was
fitted on (`--fit` names another). Prints median and 95th percentile ΔE2000, on 4x4 box-filtered pixels so grain
averages out: RetroSnap against the reference (the number that matters), the camera's fit against the reference
(what the colour stage alone reaches on this picture), RetroSnap against that fit (pipeline parity: should be
well under 1), and for a later pair also its own single-picture fit (`<pair>.json`), the best the colour stage
could do on this picture alone.

The fit side is the camera's colour (its table, else its parametric stage) over the input after the camera's
halation and blur as `CameraLook.swift` has them (`tools/pairs.py` reads the recipe), the way `lut.py` fitted the
table and the pipeline draws it, so parity means the same for a blurred camera as for a sharp one; `--plain`
leaves the glow and the blur out, which is what parity measured before the refinement round.
"""
import json
import os
import re
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, delta_e2000, srgb_to_lab  # noqa: E402
from halation import TINTS, WINDOW_POINTS, blurred, with_halation  # noqa: E402
from lut import DARK, evaluate, read_cube  # noqa: E402
from pairs import recipe  # noqa: E402
from images import box, load_rgb as load  # noqa: E402


def camera_of(pair):
    """`negative-1` -> `negative`."""
    return re.sub(r"-\d+$", "", pair)


def report(name, a, b, inset):
    h, w = a.shape[:2]
    m = int(round(inset * w))
    de = delta_e2000(srgb_to_lab(a[m:h - m, m:w - m]), srgb_to_lab(b[m:h - m, m:w - m]))
    print(f"  {name:<34} median {np.median(de):5.2f}   p95 {np.percentile(de, 95):5.2f}   mean {de.mean():5.2f}")
    return float(np.median(de))


def through_optics(inp, cam, w, h, plain):
    """The input after the camera's halation glow and blur, as the pipeline feeds its colour."""
    if plain:
        return inp
    look = recipe(cam)
    scale = w / WINDOW_POINTS[cam][0 if w >= h else 1]
    if look["halation"]:
        t, r, a, tint = look["halation"]
        inp = with_halation(inp, t, a, TINTS[tint], r * scale)
    if look["blur"]:
        inp = blurred(inp, look["blur"] * scale)
    return inp


def main(prefix, fit_path=None, plain=False):
    folder, pair = os.path.split(prefix)
    cam = camera_of(pair)
    fit_path = fit_path or os.path.join(folder, cam + ".json")
    d = json.load(open(fit_path))
    inp, ref, ours = load(prefix + "-input.png"), load(prefix + "-reference.png"), load(prefix + "-retrosnap.png")
    h, w = ref.shape[:2]
    uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
    seen = through_optics(inp, cam, w, h, plain)
    cube_path = os.path.join(folder, cam + ".cube")
    if os.path.exists(cube_path):
        # The camera's colour is its table (`tools/lut.py`), with the look's vignette put back.
        cube, size = read_cube(cube_path)
        fit = evaluate(cube, size, seen)
        dd = (uv - 0.5) / 0.70710678
        k = (0.9 * np.clip((np.hypot(dd[..., 0], dd[..., 1]) - 0.48) / 0.52, 0, 1) * d["vignette"])[..., None]
        fit = fit * (1 - k) + DARK * k
        fit_path = cube_path
    else:
        fit = ColourStage.apply(ColourStage.from_json(d), seen, uv)
    inset = 0.06 if cam == "slide" else 0.02
    print(f"{pair}: {w}x{h}, fit {fit_path}" + ("" if plain else " after the recipe's halation and blur"))
    ours_ref = report("RetroSnap vs reference", box(ours), box(ref), inset)
    report("fit vs reference", box(fit), box(ref), inset)
    report("RetroSnap vs fit (parity)", box(ours), box(fit), inset)
    if pair != cam and os.path.exists(prefix + ".json"):
        own = ColourStage.apply(ColourStage.from_json(json.load(open(prefix + ".json"))), inp, uv)
        report("own single-picture fit vs reference", box(own), box(ref), inset)
    report("input vs reference", box(inp), box(ref), inset)
    return ours_ref


if __name__ == "__main__":
    args = sys.argv[1:]
    fit_path = None
    if "--fit" in args:
        i = args.index("--fit")
        fit_path = args[i + 1]
        del args[i:i + 2]
    plain = "--plain" in args
    for p in [a for a in args if a != "--plain"]:
        main(p, fit_path, plain)
