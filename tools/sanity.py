"""How a fitted colour stage treats colours the reference scene never showed: a sweep of saturated hues
and a grey ramp, printed as hue and chroma before and after. A hue that flips or a chroma that explodes
means the fit is extrapolating wildly and wants more regularisation.

    venv/bin/python tools/sanity.py ref/pairs/<id>.json ...
"""
import json
import sys
import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, srgb_to_lab  # noqa: E402


def hue_chroma(rgb):
    lab = srgb_to_lab(rgb)
    return np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) % 360, np.hypot(lab[..., 1], lab[..., 2]), lab[..., 0]


def main(paths):
    hues = np.arange(0, 360, 30)
    sweep = []
    for h in hues:
        # HSV (h, 0.8, 0.9) -> rgb
        c = 0.9 * 0.8
        x = c * (1 - abs((h / 60) % 2 - 1))
        m = 0.9 - c
        r, g, b = [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)][int(h // 60)]
        sweep.append((r + m, g + m, b + m))
    sweep = np.array(sweep)
    greys = np.linspace(0, 1, 11)[:, None].repeat(3, 1)
    for path in paths:
        d = json.load(open(path))
        p = ColourStage.from_json(d)
        out = ColourStage.apply(p, sweep)
        h0, c0, _ = hue_chroma(sweep)
        h1, c1, _ = hue_chroma(out)
        print(f"{d['camera']}:")
        worst = 0
        for h, a, b, ca, cb in zip(hues, h0, h1, c0, c1):
            dh = (b - a + 180) % 360 - 180
            worst = max(worst, abs(dh))
            print(f"  hue {h:3d}: {a:6.1f} -> {b:6.1f} ({dh:+6.1f}), chroma {ca:5.1f} -> {cb:5.1f}")
        g1 = ColourStage.apply(p, greys)
        print("  grey ramp ->", " ".join(f"{v:.2f}" for v in g1.mean(axis=1)))
        print("  grey tint (r-b):", " ".join(f"{v:+.2f}" for v in (g1[:, 0] - g1[:, 2])))
        print(f"  worst hue shift {worst:.1f} degrees")


if __name__ == "__main__":
    main(sys.argv[1:])
