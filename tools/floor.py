"""The per-pixel floor of a pair: how far the reference scatters around the mean colour it gives each input colour,
which no model that maps colour to colour can beat. The pair's 4x4 boxes (inside the inset) are binned by their
input colour on a 33-node grid; for every bin with at least three samples the reference's mean is taken and the
median ΔE2000 of the reference from that mean is the floor. Beside it, RetroSnap's median from
`<pair>-retrosnap.png` when it exists, and the gap.

    venv/bin/python -I tools/floor.py <id> [...] [--pairs <pair> ...]

What is left above the floor is the reference's own spatial rendering (local contrast, a glow, its resampling) or
a misaligned pair; what is under it the colour mapping could still take.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from colour import delta_e2000, srgb_to_lab  # noqa: E402
from pairs import INPUTS, camera_of, pairs as pairs_of, suffix_of  # noqa: E402
from images import box, load_rgb as load  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def floor_of(pair, nodes=33):
    cam = camera_of(pair)
    inp, ref = box(load(f"{R}/{pair}-input.png")), box(load(f"{R}/{pair}-reference.png"))
    h, w = ref.shape[:2]
    m = int((0.06 if cam == "slide" else 0.02) * w * 4) // 4
    A, B = inp[m:-m or None, m:-m or None].reshape(-1, 3), ref[m:-m or None, m:-m or None].reshape(-1, 3)
    idx = np.clip(np.round(A * (nodes - 1)).astype(int), 0, nodes - 1)
    key = (idx[:, 0] * nodes + idx[:, 1]) * nodes + idx[:, 2]
    order = np.argsort(key)
    key_sorted = key[order]
    starts = np.flatnonzero(np.r_[True, key_sorted[1:] != key_sorted[:-1]])
    counts = np.diff(np.r_[starts, len(key_sorted)])
    lab = srgb_to_lab(B)
    sums = np.add.reduceat(lab[order], starts, axis=0)
    means = sums / counts[:, None]
    bin_of = np.repeat(np.arange(len(starts)), counts)
    big = counts[bin_of] >= 3
    de = delta_e2000(lab[order][big], means[bin_of][big])
    ours = None
    if os.path.exists(f"{R}/{pair}-retrosnap.png"):
        O = box(load(f"{R}/{pair}-retrosnap.png"))[m:-m or None, m:-m or None].reshape(-1, 3)
        ours = float(np.median(delta_e2000(srgb_to_lab(O), lab)))
    return float(np.median(de)), ours, int(big.sum()), len(A)


def main(argv):
    if "--pairs" in argv:
        names = argv[argv.index("--pairs") + 1:]
    else:
        names = [p for cam in argv for p in pairs_of(cam)]
    print(f"{'pair':16s} {'picture':9s} {'floor':>6s} {'ours':>6s} {'gap':>6s}   (median ΔE2000 on 4x4 boxes; samples in bins of 3 or more)")
    for pair in names:
        if not os.path.exists(f"{R}/{pair}-input.png"):
            continue
        fl, ours, n, total = floor_of(pair)
        gap = f"{ours - fl:+6.2f}" if ours is not None else "     -"
        print(f"{pair:16s} {INPUTS[suffix_of(pair)][0]:9s} {fl:6.2f} {ours if ours is not None else float('nan'):6.2f} {gap}   ({n} of {total})")


if __name__ == "__main__":
    main(sys.argv[1:])
