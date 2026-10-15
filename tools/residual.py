"""Map what the camera's colour leaves: the reference minus RetroSnap's render, in CIELAB, over position, luminance
and hue, for every pair of a camera, and name the largest remaining structure.

    venv/bin/python -I tools/residual.py <id> [...] [--fit] [--out <dir>]

A spatial pattern is a layer the recipe does not model (a vignette's shape, a flash fall-off, a leak, soft edges,
or the reference's own local variation); a luminance band is a tone gap; a hue sector is a table gap. For each pair
the residual is taken on 4x4 boxes inside the inset, and three views are measured: by position (a 12x12 grid of
mean dL; a radial profile of dL by distance from the centre, whose range is a vignette-shaped residual; a plane fit
whose tilt across the picture is a gradient such as a flash fall-off or a leak), by the reference's lightness in
bands of 10 L (the band with the largest mean shift), and by the reference's hue in twelve sectors over pixels of
chroma above 10 (the sector with the largest mean shift). The structure with the largest amplitude, in L or ΔE
units, is named per pair and per camera. `--fit` measures the camera's table over the input instead of the render.
`--out` also writes `<pair>-residual.png`: the dL, da and db maps side by side.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import delta_e2000, srgb_to_lab  # noqa: E402
from compare import through_optics  # noqa: E402
from lut import DARK, evaluate, read_cube  # noqa: E402
from pairs import INPUTS, PAIRS, mask_of, suffix_of  # noqa: E402
from images import box, load_rgb as load  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def fitted(cam, inp, w, h):
    cube, size = read_cube(f"{R}/{cam}.cube")
    out = evaluate(cube, size, through_optics(inp, cam, w, h, False))
    uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
    vig = json.load(open(f"{R}/{cam}.json"))["vignette"]
    d = (uv - 0.5) / 0.70710678
    k = (0.9 * np.clip((np.hypot(d[..., 0], d[..., 1]) - 0.48) / 0.52, 0, 1) * vig)[..., None]
    return out * (1 - k) + DARK * k


def analyse(pair, cam, use_fit):
    inp, ref = load(f"{R}/{pair}-input.png"), load(f"{R}/{pair}-reference.png")
    h, w = ref.shape[:2]
    ours = fitted(cam, inp, w, h) if use_fit else load(f"{R}/{pair}-retrosnap.png")
    A, B, O = srgb_to_lab(box(inp)), srgb_to_lab(box(ref)), srgb_to_lab(box(ours))
    m = int((0.06 if cam == "slide" else 0.02) * w) // 4
    B, O, A = B[m:-m or None, m:-m or None], O[m:-m or None, m:-m or None], A[m:-m or None, m:-m or None]
    D = B - O  # reference minus RetroSnap
    dE = delta_e2000(O, B)
    hh, ww = D.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    u, v = (xx + 0.5) / ww - 0.5, (yy + 0.5) / hh - 0.5
    # The date back is in the reference and not in the render: its box is left out of every view.
    valid = np.ones((hh, ww), bool)
    stamp = mask_of(cam, suffix_of(pair))
    if stamp:
        mx0, my0, mx1, my1 = [c // 4 for c in stamp]
        valid[max(0, my0 - m):max(0, my1 - m), max(0, mx0 - m):max(0, mx1 - m)] = False
    D = np.where(valid[..., None], D, 0.0)
    dE = np.where(valid, dE, np.nan)
    out = {"pair": pair, "median_dE": float(np.nanmedian(dE)), "mean_dL": float(D[..., 0].mean()), "mean_da": float(D[..., 1].mean()), "mean_db": float(D[..., 2].mean())}
    # Spatial: a 12x12 grid of mean dL, the radial profile, and a plane fit.
    grid = np.zeros((12, 12))
    for i in range(12):
        for j in range(12):
            cell = D[i * hh // 12:(i + 1) * hh // 12, j * ww // 12:(j + 1) * ww // 12, 0]
            grid[i, j] = cell.mean()
    r = np.hypot(u, v) / 0.70710678
    profile = [float(D[..., 0][(r >= lo) & (r < lo + 0.1)].mean()) for lo in np.arange(0, 1, 0.1) if ((r >= lo) & (r < lo + 0.1)).sum() > 50]
    X = np.stack([np.ones(hh * ww), u.ravel(), v.ravel()], 1)
    coef = np.linalg.lstsq(X, D[..., 0].ravel(), rcond=None)[0]
    plane = X @ coef
    local = D[..., 0].ravel() - plane
    # The residual's own local variation: the std of the dL map after the plane, on 12x12 cells (texture averages out).
    # Each structure's amplitude on one footing: the RMS over the picture of what it would correct.
    radial_pred = np.zeros_like(D[..., 0])
    for lo, value in zip(np.arange(0, 1, 0.1), profile):
        radial_pred[(r >= lo) & (r < lo + 0.1)] = value
    plane_pred = (plane - coef[0]).reshape(hh, ww)
    cell_pred = np.repeat(np.repeat(grid - grid.mean(), hh // 12 + 1, axis=0), ww // 12 + 1, axis=1)[:hh, :ww] - plane_pred
    out["spatial"] = {"grid_range": float(grid.max() - grid.min()), "radial_profile": [round(p, 2) for p in profile],
                      "radial_range": float(max(profile) - min(profile)) if profile else 0.0,
                      "gradient_x": float(coef[1]), "gradient_y": float(coef[2]), "cell_std_after_plane": float(np.std(grid - grid.mean())),
                      "radial_rms": float(np.sqrt((radial_pred[valid] - radial_pred[valid].mean()) ** 2).mean()),
                      "plane_rms": float(np.sqrt((plane_pred[valid] ** 2).mean())), "local_rms": float(np.sqrt((cell_pred[valid] ** 2).mean()))}
    # Luminance bands of the reference's L.
    bands = []
    band_pred = np.zeros_like(D[..., 0])
    for lo in range(0, 100, 10):
        sel = (B[..., 0] >= lo) & (B[..., 0] < lo + 10) & valid
        if sel.sum() > 200:
            band_pred[sel] = D[..., 0][sel].mean()
            bands.append({"band": f"{lo}-{lo + 10}", "n": int(sel.sum()), "dL": float(D[..., 0][sel].mean()), "da": float(D[..., 1][sel].mean()), "db": float(D[..., 2][sel].mean()), "dE": float(np.nanmedian(dE[sel]))})
    out["bands"] = bands
    # Hue sectors of the reference's hue, chroma over 10.
    chroma = np.hypot(B[..., 1], B[..., 2])
    hue = np.degrees(np.arctan2(B[..., 2], B[..., 1])) % 360
    sectors = []
    sector_pred = np.zeros_like(D[..., 0])
    for k in range(12):
        sel = (chroma > 10) & (hue >= k * 30) & (hue < (k + 1) * 30) & valid
        if sel.sum() > 200:
            sector_pred[sel] = np.hypot(D[..., 1][sel].mean(), D[..., 2][sel].mean())
            sectors.append({"sector": f"{k * 30}-{k * 30 + 30}", "n": int(sel.sum()), "dL": float(D[..., 0][sel].mean()), "da": float(D[..., 1][sel].mean()),
                            "db": float(D[..., 2][sel].mean()), "shift": float(np.hypot(D[..., 1][sel].mean(), D[..., 2][sel].mean())), "dE": float(np.nanmedian(dE[sel]))})
    out["sectors"] = sectors
    # Name the largest structure: the RMS over the picture of what each would correct, in L for the spatial and
    # tonal views and in ab for the hue view (over the chromatic pixels it touches, diluted by their share).
    band_rms = float(np.sqrt((band_pred[valid] ** 2).mean()))
    sector_rms = float(np.sqrt((sector_pred[valid] ** 2).mean()))
    worst_band = max(bands, key=lambda b: abs(b["dL"])) if bands else None
    worst_sector = max(sectors, key=lambda t: t["shift"]) if sectors else None
    candidates = [(f"a vignette-shaped residual (radial dL {min(profile):+.1f} to {max(profile):+.1f})", out["spatial"]["radial_rms"]),
                  (f"a gradient across the picture (dL tilt x {coef[1]:+.1f}, y {coef[2]:+.1f})", out["spatial"]["plane_rms"]),
                  ("the reference's own local variation (what no smooth layer explains)", out["spatial"]["local_rms"])]
    if worst_band:
        candidates.append((f"a tone gap, largest at L {worst_band['band']} (dL {worst_band['dL']:+.1f})", band_rms))
    if worst_sector:
        candidates.append((f"a table gap, largest at hue {worst_sector['sector']} (da {worst_sector['da']:+.1f} db {worst_sector['db']:+.1f})", sector_rms))
    out["largest"] = max(candidates, key=lambda c: c[1])
    out["candidates"] = candidates
    return out, grid, D


def main(argv):
    use_fit = "--fit" in argv
    out_dir = argv[argv.index("--out") + 1] if "--out" in argv else None
    cams = [a for a in argv if not a.startswith("--") and (argv.index(a) == 0 or argv[argv.index(a) - 1] != "--out")]
    for cam in cams:
        results = []
        for suffix in PAIRS[cam]:
            pair = cam + suffix
            if not os.path.exists(f"{R}/{pair}-input.png") or (not use_fit and not os.path.exists(f"{R}/{pair}-retrosnap.png")):
                continue
            res, grid, D = analyse(pair, cam, use_fit)
            results.append(res)
            s = res["spatial"]
            print(f"{pair:15s} {INPUTS[suffix][0]:9s} median dE {res['median_dE']:.2f}; mean dL {res['mean_dL']:+.2f} da {res['mean_da']:+.2f} db {res['mean_db']:+.2f}; "
                  f"RMS of what each view would correct: " + ", ".join(f"{c[1]:.2f}" for c in res["candidates"]) + " (radial, tilt, local, tone, hue)")
            print(f"   position: radial dL {s['radial_profile']} (range {s['radial_range']:.2f}); tilt x {s['gradient_x']:+.2f} y {s['gradient_y']:+.2f} L across the picture; "
                  f"12x12 cells range {s['grid_range']:.2f}, std after the plane {s['cell_std_after_plane']:.2f}")
            print("   lightness: " + " ".join(f"[{b['band']}: dL {b['dL']:+.1f} da {b['da']:+.1f} db {b['db']:+.1f}]" for b in res["bands"]))
            print("   hue:       " + " ".join(f"[{t['sector']}: dL {t['dL']:+.1f} da {t['da']:+.1f} db {t['db']:+.1f}]" for t in res["sectors"]))
            print(f"   largest: {res['largest'][0]}, amplitude {res['largest'][1]:.2f}")
            if out_dir:
                os.makedirs(out_dir, exist_ok=True)
                panels = []
                for c, scale in ((0, 6.0), (1, 6.0), (2, 6.0)):
                    img = np.clip(D[..., c] / scale, -1, 1)
                    rgb = np.stack([np.clip(1 + img, 0, 1), np.clip(1 - np.abs(img), 0, 1), np.clip(1 - img, 0, 1)], -1)
                    panels.append((rgb * 255).astype(np.uint8))
                sheet = np.concatenate(panels, axis=1)
                Image.fromarray(sheet).save(f"{out_dir}/{pair}-residual.png")
        if results:
            worst = max(results, key=lambda r: r["largest"][1])
            print(f"{cam}: largest remaining structure over its pictures: {worst['largest'][0]} on {worst['pair']}, amplitude {worst['largest'][1]:.2f}")
            print()


if __name__ == "__main__":
    main(sys.argv[1:])
