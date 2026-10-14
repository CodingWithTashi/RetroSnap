"""The reference's grain amplitude by luminance, over every export pair of the cameras given, against RetroSnap's:
the high-pass standard deviation of flat 24x24 blocks (as `grain.py` takes them) in eight luminance bands, each
pair's profile scaled by its peak, then the median profile over the pairs. The shape is what `FilmGrain`'s
luminance weight in `RetroLook.metal` must follow for the grain ratio to hold on every picture, not only at mid grey.

    venv/bin/python -I tools/grain_profile.py <id> [...] [--all]

Only pairs over 1400 px wide (the reference app's exports) count unless `--all`: a screenshot's grain is the screen's.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import pairs as pairs_of  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def lum(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(float) @ [0.2126, 0.7152, 0.0722]


def profile(prefix):
    la, lb = lum(prefix + "-input.png"), lum(prefix + "-reference.png")
    lc = lum(prefix + "-retrosnap.png") if os.path.exists(prefix + "-retrosnap.png") else None
    hp = lambda x: x - ndimage.gaussian_filter(x, 2.5)
    ha, hb = hp(la), hp(lb)
    hc = hp(lc) if lc is not None else None
    n = 24
    H, W = la.shape
    rows = []
    for y in range(0, H - n, n):
        for x in range(0, W - n, n):
            if ha[y:y + n, x:x + n].std() < 1.5:
                rows.append((lb[y:y + n, x:x + n].mean(), hb[y:y + n, x:x + n].std(), hc[y:y + n, x:x + n].std() if hc is not None else np.nan))
    rows = np.array(rows)
    ref, ours, counts = [], [], []
    for lo in range(0, 256, 32):
        sel = (rows[:, 0] >= lo) & (rows[:, 0] < lo + 32)
        ref.append(np.median(rows[sel, 1]) if sel.sum() >= 5 else np.nan)
        ours.append(np.median(rows[sel, 2]) if sel.sum() >= 5 else np.nan)
        counts.append(int(sel.sum()))
    return np.array(ref), np.array(ours), counts


def main(argv):
    everything = "--all" in argv
    cams = [a for a in argv if not a.startswith("--")]
    centres = np.arange(16, 256, 32) / 255
    all_ref, all_ours = [], []
    print(f"{'pair':16s} " + " ".join(f"{c:5.2f}" for c in centres) + "   (reference / RetroSnap, scaled by the reference's peak)")
    for cam in cams:
        for pair in pairs_of(cam):
            if not os.path.exists(os.path.join(R, pair + "-input.png")):
                continue
            w = Image.open(os.path.join(R, pair + "-reference.png")).width
            if w <= 1400 and not everything:
                continue
            ref, ours, counts = profile(os.path.join(R, pair))
            peak = np.nanmax(ref)
            all_ref.append(ref / peak); all_ours.append(ours / peak)
            print(f"{pair:16s} " + " ".join(f"{v / peak:5.2f}" if not np.isnan(v) else "    -" for v in ref))
            print(f"{'':16s} " + " ".join(f"{v / peak:5.2f}" if not np.isnan(v) else "    -" for v in ours) + f"   peak {peak:.2f}/255, blocks {counts}")
    med_ref, med_ours = np.nanmedian(np.array(all_ref), axis=0), np.nanmedian(np.array(all_ours), axis=0)
    print(f"{'median reference':16s} " + " ".join(f"{v:5.2f}" for v in med_ref))
    print(f"{'median RetroSnap':16s} " + " ".join(f"{v:5.2f}" for v in med_ours))
    w = 4 * centres * (1 - centres)
    print(f"{'4 l (1-l)':16s} " + " ".join(f"{v:5.2f}" for v in w / w.max()))
    for a, b in ((1, 2), (1, 1.5), (0.8, 2), (1, 2.5), (1.2, 2.5)):
        w = centres ** a * (1 - centres) ** b
        print(f"{f'l^{a} (1-l)^{b}':16s} " + " ".join(f"{v:5.2f}" for v in w / w.max()))


if __name__ == "__main__":
    main(sys.argv[1:])
