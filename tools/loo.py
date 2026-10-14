"""Leave-one-out on a camera's colour table: fit the table on all its pairs but one, measure the one left out,
for each pair in turn, with the prior (the parametric fit) fixed. A held-out median much above the fitted one
(more than 0.5) is a table that has learned its pictures rather than the camera.

    venv/bin/python -I tools/loo.py <id> [...] [--prior 0.3] [--smooth 2] [--skin 3] [--jobs 3] [--out ref/pairs/loo]

The halation and blur are the recipe's (`tools/pairs.py` reads `CameraLook.swift`), as `lut.py` is run for the
shipped table. Prints, per pair, the median of the table fitted on all pairs (`<id>-lut.json`, when it exists)
beside the held-out median, and the worst gap.
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from colour import delta_e2000, srgb_to_lab  # noqa: E402
from compare import box, through_optics  # noqa: E402
from lut import DARK, evaluate, read_cube  # noqa: E402
from pairs import CAMERAS, INPUTS, pairs as pairs_of, recipe, suffix_of  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
# One BLAS thread per fit: several fits at once, each spawning a thread per core, thrash the machine.
ENV = os.environ | {"OPENBLAS_NUM_THREADS": "1", "OMP_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"}
R = os.path.join(TOOLS, "..", "ref", "pairs")


def fit_without(cam, held, out, opts):
    name = f"{cam}-loo{held[len(cam):] or '-0'}"
    if os.path.exists(os.path.join(out, name + ".cube")):
        return name
    look = recipe(cam)
    args = [sys.executable, "-I", os.path.join(TOOLS, "lut.py"), name, out, "--fit", os.path.join(R, cam + ".json"),
            "--prior", opts["--prior"], "--smooth", opts["--smooth"], "--skin", opts["--skin"]]
    if look["halation"]:
        t, r, a, tint = look["halation"]
        args += ["--halation", f"{t},{r},{a},{tint}"]
    if look["blur"]:
        args += ["--blur", str(look["blur"])]
    for pair in pairs_of(cam):
        if pair != held:
            args += ["--pair", os.path.join(R, pair)]
    done = subprocess.run(args, capture_output=True, text=True, cwd=os.path.join(TOOLS, ".."), env=ENV)
    open(os.path.join(out, name + "-fit.log"), "w").write(done.stdout + done.stderr)
    return name


def measure(cam, pair, cube_path):
    inp = np.asarray(Image.open(os.path.join(R, pair + "-input.png")).convert("RGB")).astype(float) / 255
    ref = np.asarray(Image.open(os.path.join(R, pair + "-reference.png")).convert("RGB")).astype(float) / 255
    h, w = ref.shape[:2]
    cube, size = read_cube(cube_path)
    out = evaluate(cube, size, through_optics(inp, cam, w, h, False))
    uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
    vig = json.load(open(os.path.join(R, cam + ".json")))["vignette"]
    d = (uv - 0.5) / 0.70710678
    k = (0.9 * np.clip((np.hypot(d[..., 0], d[..., 1]) - 0.48) / 0.52, 0, 1) * vig)[..., None]
    out = out * (1 - k) + DARK * k
    m = int((0.06 if cam == "slide" else 0.02) * w) // 4
    de = delta_e2000(srgb_to_lab(box(out))[m:-m or None, m:-m or None], srgb_to_lab(box(ref))[m:-m or None, m:-m or None])
    return float(np.median(de))


def main(argv):
    opts = {"--prior": "0.3", "--smooth": "2", "--skin": "3", "--jobs": "3", "--out": os.path.join(R, "loo")}
    cams = []
    i = 0
    while i < len(argv):
        if argv[i] in opts:
            opts[argv[i]] = argv[i + 1]; i += 2
        else:
            cams.append(argv[i]); i += 1
    cams = cams or CAMERAS
    out = opts["--out"]
    os.makedirs(out, exist_ok=True)
    jobs = [(cam, held) for cam in cams for held in pairs_of(cam)]
    with ThreadPoolExecutor(int(opts["--jobs"])) as pool:
        list(pool.map(lambda j: fit_without(*j, out, opts), jobs))
    for cam in cams:
        fitted = {}
        if os.path.exists(os.path.join(R, cam + "-lut.json")):
            fitted = {p["name"]: p["deltaE_median"] for p in json.load(open(os.path.join(R, cam + "-lut.json")))["pairs"]}
        worst = 0.0
        print(f"{cam} (prior {opts['--prior']}, smooth {opts['--smooth']}, skin {opts['--skin']}):")
        for held in pairs_of(cam):
            name = f"{cam}-loo{held[len(cam):] or '-0'}"
            cube_path = os.path.join(out, name + ".cube")
            if not os.path.exists(cube_path):
                print(f"   {held:16s} no table (see {name}-fit.log)"); continue
            ho = measure(cam, held, cube_path)
            fi = fitted.get(held)
            gap = (ho - fi) if fi is not None else float("nan")
            worst = max(worst, gap if fi is not None else 0)
            print(f"   {held:16s} {INPUTS[suffix_of(held)][0]:9s} fitted {fi if fi is None else round(fi, 2)!s:>5}  held-out {ho:5.2f}  gap {gap:+.2f}")
        print(f"   worst gap {worst:+.2f}" + ("  <- over-fitted: raise --prior or --smooth" if worst > 0.5 else ""))


if __name__ == "__main__":
    main(sys.argv[1:])
