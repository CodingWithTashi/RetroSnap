"""Refit a camera's parametric colour stage on every pair it has, three ways, and pick one: `--reg 3`,
`--reg 8 --hue-reg 2` and `--reg 8 --hue-reg 6`, each fitted by `fit.py --pair` over all the camera's pairs
(`tools/pairs.py`), then run through `sanity.py`'s hue sweep; the fit kept is the one with the smaller worst median
whose swing on *unseen* hues is under 20°, else the one with the smaller unseen swing. A hue is unseen when fewer
than 0.5% of the camera's input samples have it at a chroma over 25 (CIELAB); a swing on a hue the pictures show
is the camera's measured behaviour, not extrapolation.

    venv/bin/python -I tools/refit.py <id> [...] [--jobs 3] [--samples 20000] [--out ref/pairs/refit] [--pick]

Writes `<out>/<id>-reg3.json` and `<id>-reg8.json` with their reports, prints the table, and with `--pick` copies
the chosen fit to `ref/pairs/<id>.json` (and its report), where the table fit, `compare.py` and the recipe read it.
A pair's date-back mask and the slide's inset come from each pair's own JSON, except for the first pair of a
camera whose JSON is the joint fit: those are given here (`FIRST_PAIR_MASK`).
"""
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import CAMERAS, PAIRS, pairs as pairs_of  # noqa: E402
from sanity import hue_chroma  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
# One BLAS thread per fit: several fits at once, each spawning a thread per core, thrash the machine.
ENV = os.environ | {"OPENBLAS_NUM_THREADS": "1", "OMP_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"}
R = os.path.join(TOOLS, "..", "ref", "pairs")
# The first pair's date back, in its crop's pixels: the exports' landscape box, and the CPM35 selfie screenshot's.
FIRST_PAIR_MASK = {"film": "2900,2240,3470,2440", "compactPro": "2900,2240,3470,2440", "classicSLR": "2900,2240,3470,2440",
                   "plastic35": "760,650,1010,745"}
SETTINGS = {"reg3": ["--reg", "3"], "reg8": ["--reg", "8", "--hue-reg", "2"], "reg8h6": ["--reg", "8", "--hue-reg", "6"]}


def coverage(cam):
    """The share of the camera's input samples (4x4 boxes of every pair) in each 30° hue bin at a chroma over 25."""
    import numpy as np
    from PIL import Image
    from colour import srgb_to_lab
    shares, total = np.zeros(12), 0
    for pair in pairs_of(cam):
        a = np.asarray(Image.open(os.path.join(R, pair + "-input.png")).convert("RGB")).astype(float) / 255
        h, w = a.shape[0] // 4, a.shape[1] // 4
        lab = srgb_to_lab(a[: h * 4, : w * 4].reshape(h, 4, w, 4, 3).mean(axis=(1, 3))).reshape(-1, 3)
        chroma = np.hypot(lab[:, 1], lab[:, 2])
        hue = np.degrees(np.arctan2(lab[:, 2], lab[:, 1])) % 360
        for k in range(12):
            shares[k] += ((chroma > 25) & (hue >= k * 30) & (hue < (k + 1) * 30)).sum()
        total += len(lab)
    return shares / total


def swing(path, seen=None):
    """The worst hue shift on `sanity.py`'s sweep, in degrees, over every hue, and over the unseen ones (`seen`:
    the 12 coverage shares; a bin under 0.5% is unseen; the sweep's hue is the input colour's CIELAB hue)."""
    import numpy as np
    from colour import ColourStage
    d = json.load(open(path))
    p = ColourStage.from_json(d)
    hues = np.arange(0, 360, 30)
    sweep = []
    for h in hues:
        c = 0.9 * 0.8
        x = c * (1 - abs((h / 60) % 2 - 1))
        m = 0.9 - c
        r, g, b = [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)][int(h // 60)]
        sweep.append((r + m, g + m, b + m))
    sweep = np.array(sweep)
    h0, _, _ = hue_chroma(sweep)
    h1, _, _ = hue_chroma(ColourStage.apply(p, sweep))
    shifts = np.abs((h1 - h0 + 180) % 360 - 180)
    if seen is None:
        return float(shifts.max()), float(shifts.max())
    unseen = np.array([seen[int(h // 30) % 12] < 0.005 for h in h0])
    return float(shifts.max()), float(shifts[unseen].max()) if unseen.any() else 0.0


def run(cam, setting, out, samples):
    name = f"{cam}-{setting}"
    target = os.path.join(out, name + ".json")
    if os.path.exists(target):
        return name, "kept"
    args = [sys.executable, "-I", os.path.join(TOOLS, "fit.py"), name, out, "--samples", str(samples)] + SETTINGS[setting]
    for pair in pairs_of(cam):
        args += ["--pair", os.path.join(R, pair)]
    if cam in FIRST_PAIR_MASK:
        args += ["--mask", f"{cam}={FIRST_PAIR_MASK[cam]}"]
    if cam == "slide":
        args += ["--inset", "0.06"]
    done = subprocess.run(args, capture_output=True, text=True, env=ENV)
    open(os.path.join(out, name + "-fit.log"), "w").write(done.stdout + done.stderr)
    return name, "done" if done.returncode == 0 else "FAILED"


def main(argv):
    opts = {"--jobs": "3", "--samples": "20000", "--out": os.path.join(R, "refit")}
    cams, pick = [], False
    i = 0
    while i < len(argv):
        if argv[i] in opts:
            opts[argv[i]] = argv[i + 1]; i += 2
        elif argv[i] == "--pick":
            pick = True; i += 1
        else:
            cams.append(argv[i]); i += 1
    cams = cams or CAMERAS
    out = opts["--out"]
    os.makedirs(out, exist_ok=True)
    jobs = [(cam, setting) for cam in cams for setting in SETTINGS]
    with ThreadPoolExecutor(int(opts["--jobs"])) as pool:
        for name, state in pool.map(lambda j: run(*j, out, int(opts["--samples"])), jobs):
            print(f"{name}: {state}", flush=True)
    print()
    print(f"{'camera':13s} {'fit':6s} {'pair medians':60s} {'worst':>6s} {'swing':>6s} {'unseen':>6s}")
    for cam in cams:
        rows = {}
        seen = coverage(cam)
        for setting in SETTINGS:
            path = os.path.join(out, f"{cam}-{setting}.json")
            if not os.path.exists(path):
                continue
            d = json.load(open(path))
            medians = {p["name"]: p["deltaE_median"] for p in d["pairs"]}
            whole, unseen = swing(path, seen)
            rows[setting] = (d["deltaE_median"], unseen, medians, whole)
            print(f"{cam:13s} {setting:6s} {' '.join(f'{v:.2f}' for v in medians.values()):60s} {d['deltaE_median']:6.2f} {whole:6.1f} {unseen:6.1f}")
        if not rows:
            continue
        print(f"{cam:13s} unseen hue bins (under 0.5%): " + " ".join(f"{k * 30}" for k in range(12) if seen[k] < 0.005))
        sane = {k: v for k, v in rows.items() if v[1] < 20}
        chosen = min(sane, key=lambda k: sane[k][0]) if sane else min(rows, key=lambda k: rows[k][1])
        print(f"{cam:13s} pick   {chosen} (worst median {rows[chosen][0]:.2f}, unseen swing {rows[chosen][1]:.1f} deg{'' if sane else ': none under 20 deg, the smaller unseen swing'})")
        if pick:
            shutil.copy(os.path.join(out, f"{cam}-{chosen}.json"), os.path.join(R, f"{cam}.json"))
            shutil.copy(os.path.join(out, f"{cam}-{chosen}-report.png"), os.path.join(R, f"{cam}-report.png"))
            d = json.load(open(os.path.join(R, f"{cam}.json")))
            d["camera"] = cam
            json.dump(d, open(os.path.join(R, f"{cam}.json"), "w"), indent=2)


if __name__ == "__main__":
    main(sys.argv[1:])
