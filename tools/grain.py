"""Measure the grain in a reference pair: how much fine texture the reference adds where the input is flat,
and how much RetroSnap's render of the same pair adds, so the two can be held against each other; and the
detail each keeps where the input has some, which is the camera's softness.

    venv/bin/python tools/grain.py ref/pairs/<pair> [...]

For 24x24 blocks where the input has little high-frequency detail, prints the reference's high-pass standard
deviation (in 0...255 units) by luminance band and, when `<pair>-retrosnap.png` exists (from
`ReferencePairTests`), RetroSnap's in the same blocks and the grain ratio RetroSnap/reference at mid grey
(the bands from 64 to 191: the ratio of each band's medians, averaged with the bands weighted by their block
counts, so a band of a few odd blocks cannot swing it). The texture's size is the lag at which the
autocorrelation of the high-pass reference halves, in reference pixels.

Then the detail kept: for 24x24 blocks where the input has fine texture (high-pass std over 4), the median of
the reference's high-pass std over the input's, and RetroSnap's, in the middle of the picture and toward its
corners (inside and outside 0.5 of the half-diagonal). Under 1 is softer than the input; the two columns should
agree, and the corners say whether the look's `Softness` is right.
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)


def luminance(rgb):
    return rgb @ [0.2126, 0.7152, 0.0722]


def highpass(lum, sigma=2.5):
    return lum - ndimage.gaussian_filter(lum, sigma)


def main(prefix):
    la = luminance(load(prefix + "-input.png"))
    lb = luminance(load(prefix + "-reference.png"))
    ours_path = prefix + "-retrosnap.png"
    lc = luminance(load(ours_path)) if os.path.exists(ours_path) else None
    ha, hb = highpass(la), highpass(lb)
    hc = highpass(lc) if lc is not None else None
    n = 24
    H, W = la.shape
    rows = []
    for y in range(0, H - n, n):
        for x in range(0, W - n, n):
            fa = ha[y:y + n, x:x + n]
            if fa.std() < 1.5:
                ours = hc[y:y + n, x:x + n].std() if hc is not None else np.nan
                rows.append((lb[y:y + n, x:x + n].mean(), hb[y:y + n, x:x + n].std(), fa.std(), ours))
    rows = np.array(rows)
    print(f"{prefix}: {len(rows)} flat blocks" + ("" if hc is None else " (reference | RetroSnap)"))
    ratios, counts = [], []
    for lo in range(0, 256, 32):
        sel = (rows[:, 0] >= lo) & (rows[:, 0] < lo + 32)
        if sel.sum() >= 3:
            ref_std = np.median(rows[sel, 1])
            line = (f"  luminance {lo:3d}-{lo + 31:3d}: reference high-pass std {ref_std:5.2f} "
                    f"(input {np.median(rows[sel, 2]):4.2f})")
            if hc is not None:
                ours_std = np.median(rows[sel, 3])
                line += f" | RetroSnap {ours_std:5.2f}"
                if 64 <= lo < 192 and ref_std > 0:
                    ratios.append(ours_std / ref_std)
                    counts.append(int(sel.sum()))
            print(line + f" over {sel.sum()} blocks")
    if ratios:
        ratio = np.average(ratios, weights=counts)
        print(f"  grain ratio RetroSnap/reference at mid grey: {ratio:.2f} (over {len(ratios)} bands from 64 to 191, {sum(counts)} blocks)")
    # Texture size: autocorrelation of the high-pass reference in flat mid-tone blocks.
    acc = np.zeros(8)
    count = 0
    for y in range(0, H - n, n):
        for x in range(0, W - n, n):
            if ha[y:y + n, x:x + n].std() < 1.5 and 60 < lb[y:y + n, x:x + n].mean() < 200:
                f = hb[y:y + n, x:x + n]
                f = f - f.mean()
                v = (f * f).mean()
                if v < 1e-6:
                    continue
                for lag in range(8):
                    acc[lag] += (f[:, lag:] * f[:, : n - lag]).mean() / v
                count += 1
    if count:
        acc /= count
        print("  autocorrelation by lag (px):", " ".join(f"{v:.2f}" for v in acc))
    # Detail kept: textured blocks, by distance from the centre.
    detail = []
    for y in range(0, H - n, n):
        for x in range(0, W - n, n):
            fa = ha[y:y + n, x:x + n]
            if fa.std() > 4:
                r = np.hypot((x + n / 2) / W - 0.5, (y + n / 2) / H - 0.5) / 0.70710678
                ours = hc[y:y + n, x:x + n].std() / fa.std() if hc is not None else np.nan
                detail.append((r, hb[y:y + n, x:x + n].std() / fa.std(), ours))
    detail = np.array(detail)
    for name, sel in (("middle (r < 0.5)", detail[:, 0] < 0.5), ("corners (r >= 0.5)", detail[:, 0] >= 0.5)):
        if sel.sum() >= 5:
            line = f"  detail kept {name:<18}: reference {np.median(detail[sel, 1]):.2f} of the input's"
            if hc is not None:
                line += f" | RetroSnap {np.median(detail[sel, 2]):.2f}"
            print(line + f" over {sel.sum()} textured blocks")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
