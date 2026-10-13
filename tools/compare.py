"""Measure RetroSnap's render of a reference pair against the reference, and against the Python fit.

    venv/bin/python tools/compare.py ref/pairs/<pair> [...] [--fit <json>]

A pair is `<id>` (the picture the camera was first fitted on) or `<id>-<n>` (a picture added since). Reads
`<pair>-input.png`, `<pair>-reference.png` and `<pair>-retrosnap.png` (written by `ReferencePairTests`), and the
camera's fit `<id>.json` beside them: the fit that is transcribed into `CameraLook.swift`, whatever pair it was
fitted on (`--fit` names another). Prints median and 95th percentile ΔE2000, on 4x4 box-filtered pixels so grain
averages out: RetroSnap against the reference (the number that matters), the camera's fit against the reference
(what the colour stage alone reaches on this picture), RetroSnap against that fit (pipeline parity: should be
well under 1), and for a later pair also its own single-picture fit (`<pair>.json`), the best the colour stage
could do on this picture alone.
"""
import json
import os
import re
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, delta_e2000, srgb_to_lab  # noqa: E402


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255


def box(a, n=4):
    h, w = a.shape[0] // n, a.shape[1] // n
    return a[: h * n, : w * n].reshape(h, n, w, n, 3).mean(axis=(1, 3))


def params(d):
    p = np.zeros(ColourStage.SIZE)
    p[0:9] = np.array(d["matrix"]).ravel()
    p[9:12] = d["offset"]
    p[12:30] = np.array(d["knots"]).ravel()
    p[30] = d["vignette"]
    return p


def camera_of(pair):
    """`negative-1` -> `negative`."""
    return re.sub(r"-\d+$", "", pair)


def report(name, a, b, inset):
    h, w = a.shape[:2]
    m = int(round(inset * w))
    de = delta_e2000(srgb_to_lab(a[m:h - m, m:w - m]), srgb_to_lab(b[m:h - m, m:w - m]))
    print(f"  {name:<34} median {np.median(de):5.2f}   p95 {np.percentile(de, 95):5.2f}   mean {de.mean():5.2f}")
    return float(np.median(de))


def main(prefix, fit_path=None):
    folder, pair = os.path.split(prefix)
    cam = camera_of(pair)
    fit_path = fit_path or os.path.join(folder, cam + ".json")
    d = json.load(open(fit_path))
    inp, ref, ours = load(prefix + "-input.png"), load(prefix + "-reference.png"), load(prefix + "-retrosnap.png")
    h, w = ref.shape[:2]
    uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
    fit = ColourStage.apply(params(d), inp, uv)
    inset = 0.06 if cam == "slide" else 0.02
    print(f"{pair}: {w}x{h}, fit {fit_path}")
    ours_ref = report("RetroSnap vs reference", box(ours), box(ref), inset)
    report("fit vs reference", box(fit), box(ref), inset)
    report("RetroSnap vs fit (parity)", box(ours), box(fit), inset)
    if pair != cam and os.path.exists(prefix + ".json"):
        own = ColourStage.apply(params(json.load(open(prefix + ".json"))), inp, uv)
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
    for p in args:
        main(p, fit_path)
