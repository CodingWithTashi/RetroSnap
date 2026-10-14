"""Fit a camera's colour as a 3D lookup table from its reference pairs, on top of the parametric fit.

    venv/bin/python tools/lut.py <id> <outdir> --pair <prefix> [--pair ...] [--size 17] [--prior 4] [--smooth 20]
                                 [--weight <pair>=w] [--skin k] [--halation t,r,a,tint] [--blur r]

The table maps the picture after the halation glow and the camera's blur (`--blur`, its `blurRadius` in points; sRGB, gamma-encoded) to the reference with the look's vignette
taken out, so the vignette and the glow stay the spatial layers they are. Trilinear interpolation is linear in the
table's values, so the fit is one sparse least-squares solve per channel: every box-filtered sample of every pair
(each pair counting the same, as `fit.py` does, `--weight` leaning toward one, `--skin` favouring skin tones)
pulls the eight nodes around its input colour toward its reference colour; `--prior` pulls every node toward
what the camera's parametric fit (`<id>.json`: matrix, curves, hue terms) gives there, so colours the pictures
never showed follow that fit; `--smooth` keeps the table's departure from the parametric fit smooth between
neighbouring nodes. Writes `<outdir>/<id>.cube` (Adobe/Resolve text, red fastest), `<outdir>/<id>-lut.json`
(the settings and each pair's median and p95 ΔE2000 over 4x4 boxes) and prints them.
"""
import json
import os
import re
import sys
import numpy as np
from PIL import Image
from scipy import ndimage, sparse
from scipy.sparse.linalg import splu

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, delta_e2000, srgb_to_lab  # noqa: E402
from fit import samples, subsample  # noqa: E402
from halation import TINTS, with_halation, WINDOW_POINTS  # noqa: E402

DARK = np.array([20, 10, 0]) / 255


def parse(argv):
    cam, outdir = argv[0], argv[1]
    opts = {"pairs": [], "size": 17, "prior": 4.0, "smooth": 20.0, "weights": {}, "skin": 0.0, "fit": None, "halation": None, "blur": 0.0}
    i = 2
    while i < len(argv):
        flag = argv[i]
        if flag == "--pair":
            opts["pairs"].append(argv[i + 1]); i += 2
        elif flag == "--size":
            opts["size"] = int(argv[i + 1]); i += 2
        elif flag == "--prior":
            opts["prior"] = float(argv[i + 1]); i += 2
        elif flag == "--smooth":
            opts["smooth"] = float(argv[i + 1]); i += 2
        elif flag == "--skin":
            opts["skin"] = float(argv[i + 1]); i += 2
        elif flag == "--fit":
            opts["fit"] = argv[i + 1]; i += 2
        elif flag == "--halation":
            # threshold,radius,amount,tint as the recipe has them; the pairs are measured after this glow
            t, r, a, tint = argv[i + 1].split(",")
            opts["halation"] = (float(t), float(r), float(a), tint); i += 2
        elif flag == "--weight":
            name, _, value = argv[i + 1].rpartition("=")
            opts["weights"][name] = float(value); i += 2
        elif flag == "--blur":
            opts["blur"] = float(argv[i + 1]); i += 2
        else:
            i += 1
    return cam, outdir, opts


def unvignette(ref, uv, amount):
    d = (uv - 0.5) / 0.70710678
    t = np.hypot(d[..., 0], d[..., 1])
    k = (0.9 * np.clip((t - 0.48) / 0.52, 0, 1) * amount)[..., None]
    return np.clip((ref - DARK * k) / np.maximum(1 - k, 1e-3), 0, 1)


def trilinear_matrix(rgb, size):
    """The sparse (samples x nodes) matrix of trilinear weights; node index = (r * size + g) * size + b."""
    n = len(rgb)
    pos = np.clip(rgb, 0, 1) * (size - 1)
    lo = np.minimum(np.floor(pos).astype(int), size - 2)
    f = pos - lo
    rows, cols, vals = [], [], []
    for dr in (0, 1):
        wr = f[:, 0] if dr else 1 - f[:, 0]
        for dg in (0, 1):
            wg = f[:, 1] if dg else 1 - f[:, 1]
            for db in (0, 1):
                wb = f[:, 2] if db else 1 - f[:, 2]
                rows.append(np.arange(n))
                cols.append(((lo[:, 0] + dr) * size + (lo[:, 1] + dg)) * size + (lo[:, 2] + db))
                vals.append(wr * wg * wb)
    return sparse.csr_matrix((np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))), shape=(n, size ** 3))


def laplacian(size):
    """Differences between every pair of neighbouring nodes, as a sparse (edges x nodes) matrix."""
    idx = np.arange(size ** 3).reshape(size, size, size)
    rows, cols, vals = [], [], []
    e = 0
    for axis in range(3):
        a = np.moveaxis(idx, axis, 0)
        src, dst = a[:-1].ravel(), a[1:].ravel()
        m = len(src)
        rows += [np.arange(e, e + m), np.arange(e, e + m)]
        cols += [src, dst]
        vals += [np.ones(m), -np.ones(m)]
        e += m
    return sparse.csr_matrix((np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))), shape=(e, size ** 3))


def read_cube(path):
    """A .cube file as (nodes x 3) with the node index (r * size + g) * size + b, and its size."""
    rows = [list(map(float, line.split())) for line in open(path)
            if line and (line[0].isdigit() or line[0] in "-.")]
    size = round(len(rows) ** (1 / 3))
    table = np.array(rows).reshape(size, size, size, 3)  # the file runs blue slowest, red fastest
    return np.transpose(table, (2, 1, 0, 3)).reshape(-1, 3), size


def evaluate(cube, size, rgb):
    """The table applied to colours (..., 3) by trilinear interpolation, as the app does it."""
    flat = rgb.reshape(-1, 3)
    T = trilinear_matrix(flat, size)
    return np.stack([T @ cube[:, c] for c in range(3)], -1).reshape(rgb.shape)


def main(argv):
    cam, outdir, o = parse(argv)
    size = o["size"]
    fit_path = o["fit"] or f"ref/pairs/{cam}.json"
    fit_json = json.load(open(fit_path))
    p = ColourStage.from_json(fit_json)
    vig = fit_json["vignette"]
    os.makedirs(outdir, exist_ok=True)
    # The parametric fit at the nodes: the prior.
    g = np.linspace(0, 1, size)
    nodes = np.stack(np.meshgrid(g, g, g, indexing="ij"), -1).reshape(-1, 3)  # r slowest, b fastest
    prior = ColourStage.apply(p, nodes)
    # Samples.
    data = []
    weights = {os.path.basename(pr): o["weights"].get(os.path.basename(pr), 1.0) for pr in o["pairs"]}
    total = sum(weights.values())
    for prefix in o["pairs"]:
        name = os.path.basename(prefix)
        inp = np.asarray(Image.open(prefix + "-input.png").convert("RGB")).astype(np.float64) / 255
        ref = np.asarray(Image.open(prefix + "-reference.png").convert("RGB")).astype(np.float64) / 255
        own = json.load(open(prefix + ".json")) if os.path.exists(prefix + ".json") else {}
        h, w = ref.shape[:2]
        # The camera is the pair's (a leave-one-out table is named `<id>-loo-<n>`).
        camera = re.sub(r"-\d+$", "", name)
        window = WINDOW_POINTS[camera][0 if w >= h else 1]
        if o["halation"]:
            t, r, a, tint = o["halation"]
            inp = with_halation(inp, t, a, TINTS[tint], r * (w / window))
        if o["blur"]:
            inp = np.stack([ndimage.gaussian_filter(inp[..., c], o["blur"] * (w / window), mode="nearest") for c in range(3)], -1)
        A, B, UV = samples(inp, ref, own.get("inset", 0.02), own.get("mask"))
        # The pair is measured on these same 4x4 boxes (as `compare.py` box-filters a render), with the vignette
        # put back; the full-size arrays are let go here, so seven 10-megapixel pairs fit in memory at once.
        A_all_boxes, B_all_boxes, UV_all_boxes = A, B, UV
        del inp, ref
        B = unvignette(B, UV, vig)
        A, B, UV = subsample((A, B, UV), 300_000)
        wt = np.full(len(A), weights[name] / (len(A) * total) * 1e5)
        if o["skin"]:
            lab = srgb_to_lab(A)
            chroma = np.hypot(lab[..., 1], lab[..., 2])
            skin = ((lab[..., 0] > 35) & (lab[..., 0] < 85) & (lab[..., 1] > 4) & (lab[..., 1] < 30)
                    & (lab[..., 2] > 8) & (lab[..., 2] < 40) & (chroma > 10) & (chroma < 40))
            wt = wt * (1 + o["skin"] * skin)
        data.append((name, A, B, UV, wt, (A_all_boxes, B_all_boxes, UV_all_boxes), (w, h)))
        print(f"{cam}: pair {name} {w}x{h}, {len(A)} samples, weight {weights[name]}", flush=True)
    A_all = np.concatenate([d[1] for d in data]); B_all = np.concatenate([d[2] for d in data]); W_all = np.concatenate([d[4] for d in data])
    T = trilinear_matrix(A_all, size)
    L = laplacian(size)
    Wd = sparse.diags(W_all)
    # Normal equations: (T'WT + prior I + smooth L'L) x = T'W b + prior x0 + smooth L'L x0
    per_node = W_all.sum() / size ** 3
    lam_p, lam_s = o["prior"] * per_node, o["smooth"] * per_node
    M = (T.T @ Wd @ T) + lam_p * sparse.identity(size ** 3) + lam_s * (L.T @ L)
    solver = splu(M.tocsc())
    cube = np.zeros((size ** 3, 3))
    for c in range(3):
        rhs = T.T @ (W_all * B_all[:, c]) + lam_p * prior[:, c] + lam_s * (L.T @ (L @ prior[:, c]))
        cube[:, c] = np.clip(solver.solve(rhs), 0, 1)
    # Measure on each pair's 4x4 boxes (inside its inset and mask, as compare.py measures a render), the vignette
    # put back.
    results = {}
    for name, A, B, UV, wt, (A_boxes, B_boxes, UV_boxes), (w, h) in data:
        out = evaluate(cube, size, A_boxes)
        d = (UV_boxes - 0.5) / 0.70710678
        k = (0.9 * np.clip((np.hypot(d[..., 0], d[..., 1]) - 0.48) / 0.52, 0, 1) * vig)[..., None]
        out = out * (1 - k) + DARK * k
        de = delta_e2000(srgb_to_lab(out), srgb_to_lab(B_boxes))
        results[name] = {"deltaE_median": float(np.median(de)), "deltaE_p95": float(np.percentile(de, 95)), "deltaE_mean": float(de.mean())}
        print(f"  {name}: table vs reference median {np.median(de):.2f} p95 {np.percentile(de, 95):.2f} mean {de.mean():.2f}", flush=True)
    # Write the .cube (red fastest) and the JSON.
    rgb_cube = cube.reshape(size, size, size, 3)  # [r][g][b]
    with open(f"{outdir}/{cam}.cube", "w") as f:
        f.write(f"TITLE \"RetroSnap {cam}\"\nLUT_3D_SIZE {size}\nDOMAIN_MIN 0.0 0.0 0.0\nDOMAIN_MAX 1.0 1.0 1.0\n")
        for b in range(size):
            for gg in range(size):
                for r in range(size):
                    v = rgb_cube[r, gg, b]
                    f.write(f"{v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
    worst = max(results.values(), key=lambda x: x["deltaE_median"])
    json.dump({"camera": cam, "size": size, "prior": o["prior"], "smooth": o["smooth"], "skin": o["skin"], "halation": o["halation"], "blur": o["blur"],
               "fit": fit_path, "vignette": vig, "pairs": [{"name": n, "weight": weights[n]} | r for n, r in results.items()],
               "deltaE_median": worst["deltaE_median"]}, open(f"{outdir}/{cam}-lut.json", "w"), indent=2)
    print(f"wrote {outdir}/{cam}.cube")


if __name__ == "__main__":
    main(sys.argv[1:])
