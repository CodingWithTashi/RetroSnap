"""Fit a camera's colour stage from its reference pairs.

    venv/bin/python tools/fit.py <id> <input photo> <reference picture crop> <outdir> [--mask x0,y0,x1,y1] [--inset f] [--reg r]
    venv/bin/python tools/fit.py <id> <outdir> --pair <prefix> [--pair <prefix> ...] [--mask [<pair>=]x0,y0,x1,y1] [--inset [<pair>=]f] [--weight <pair>=w] [--reg r]

The first form takes one new picture. It aligns the reference crop with the input (scale and offset, found by
maximising the correlation of luminance gradients), saves the matched input crop beside it as `<id>-input.png`
and `<id>-reference.png` (the pair, at the reference's own resolution), and fits on that pair. `<id>` is the
camera's id for the picture it was first fitted on, and `<id>-<n>` for a picture added since.

The second form fits on pairs already aligned, for example `--pair ref/pairs/negative --pair ref/pairs/negative-1`,
and writes the result under `<id>`. The colour stage is fitted over the pairs' union, each pair counting the same
whatever its size, so the recipe is as right on one picture as on the other; `--weight` makes one pair count
more when a camera cannot meet the tolerance on both and the worse of the two medians is what to minimise.
A pair's mask and inset come from its own JSON (written by the first form) unless given here, qualified with
the pair's name when they differ.

The fit: the colour stage (3x3 matrix + offset, six-knot monotone tone curve per channel, the look's vignette) by
least squares on CIELAB differences, with mild regularisation toward identity. `--reg` is the pull toward the
identity matrix (default 0.02); raise it when `tools/sanity.py` shows the fit swinging hues it never saw.
`--mask` keeps a date stamp out of the fit (a rectangle in reference pixels), `--inset` a mount's shadow (a
fraction of the width, default 0.02).

Writes `<outdir>/<id>.json` (the numbers for `CameraLook`, with the ΔE2000 of the fit on each pair; the
headline `deltaE_median` is the worst pair's) and `<outdir>/<id>-report.png` (input | fit | reference for each
pair, and the curves), and prints the median and 95th percentile ΔE2000 of the fit against each reference.
"""
import json
import os
import sys
import numpy as np
from PIL import Image, ImageOps, ImageDraw
from scipy import ndimage, optimize

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, KNOT_X, curve, delta_e2000, srgb_to_lab  # noqa: E402

BOX = 4


def load(path):
    return np.asarray(ImageOps.exif_transpose(Image.open(path)).convert("RGB")).astype(np.float64) / 255


def save(path, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).round().astype(np.uint8)).save(path)


def luminance(rgb):
    return rgb @ np.array([0.2126, 0.7152, 0.0722])


def edges(gray):
    g = ndimage.gaussian_filter(gray, 1.0)
    gy, gx = np.gradient(g)
    e = np.hypot(gx, gy)
    return (e - e.mean()) / (e.std() + 1e-9)


def sample(src, scale, x0, y0, w, h):
    """The source window at (x0, y0) of size (w/scale, h/scale), resampled to w x h (bilinear)."""
    ys = y0 + (np.arange(h) + 0.5) / scale - 0.5
    xs = x0 + (np.arange(w) + 0.5) / scale - 0.5
    yy, xx = np.meshgrid(ys, xs, indexing="ij")
    if src.ndim == 2:
        return ndimage.map_coordinates(src, [yy, xx], order=1, mode="nearest")
    return np.stack([ndimage.map_coordinates(src[..., c], [yy, xx], order=1, mode="nearest") for c in range(3)], -1)


def align(inp, ref):
    """(scale, x0, y0): ref ≈ input[y0:, x0:] scaled by `scale`. The input is pre-blurred to the
    reference's scale so that sampling does not alias."""
    h, w = ref.shape[:2]
    H, W = inp.shape[:2]
    # The reference shows either the input's full width or its full height, from the centre.
    s_guess = max(w / W, h / H)
    small = 4
    ref_e = edges(luminance(ref[::small, ::small]))
    sigma = 0.5 / s_guess
    inp_l = ndimage.gaussian_filter(luminance(inp), sigma)

    def score(params):
        s, x0, y0 = params
        win = sample(inp_l, s / small, x0, y0, ref_e.shape[1], ref_e.shape[0])
        e = edges(win)
        return -np.mean(e * ref_e)

    best = None
    cx, cy = (W - w / s_guess) / 2, (H - h / s_guess) / 2
    for s in s_guess * np.linspace(0.97, 1.03, 13):
        for x0 in cx + np.linspace(-90, 90, 7):
            for y0 in cy + np.linspace(-90, 90, 7):
                v = score((s, x0, y0))
                if best is None or v < best[0]:
                    best = (v, (s, x0, y0))
    res = optimize.minimize(score, best[1], method="Nelder-Mead", options={"xatol": 0.05, "fatol": 1e-5})
    s, x0, y0 = res.x
    return s, x0, y0, -res.fun


def make_pair(name, input_path, ref_path, outdir):
    """Align one reference crop with its input and write the pair. Returns (pair input, reference, alignment)."""
    inp = load(input_path)
    ref = load(ref_path)
    h, w = ref.shape[:2]
    s, x0, y0, corr = align(inp, ref)
    print(f"{name}: reference {w}x{h}; input window {w / s:.0f}x{h / s:.0f} at ({x0:.1f}, {y0:.1f}), "
          f"scale {s:.4f}, edge correlation {corr:.3f}")
    # The pair at the reference's resolution: the input blurred to that scale first.
    blurred = np.stack([ndimage.gaussian_filter(inp[..., c], 0.5 / s) for c in range(3)], -1)
    pair_in = np.clip(sample(blurred, s, x0, y0, w, h), 0, 1)
    save(f"{outdir}/{name}-input.png", pair_in)
    save(f"{outdir}/{name}-reference.png", ref)
    return pair_in, ref, {"scale": s, "x0": x0, "y0": y0, "edge_correlation": corr}


def samples(pair_in, ref, inset, mask_rect):
    """The pair as box-filtered pixels (grain and residual misalignment average out), without the border and
    the masked rectangle: (input colours, reference colours, positions in 0...1)."""
    h, w = ref.shape[:2]
    hh, ww = h // BOX, w // BOX
    a = pair_in[: hh * BOX, : ww * BOX].reshape(hh, BOX, ww, BOX, 3).mean(axis=(1, 3))
    b = ref[: hh * BOX, : ww * BOX].reshape(hh, BOX, ww, BOX, 3).mean(axis=(1, 3))
    v, u = np.mgrid[0:hh, 0:ww]
    uv = np.stack([(u + 0.5) / ww, (v + 0.5) / hh], -1)
    keep = np.ones((hh, ww), bool)
    m = int(round(inset * ww))
    keep[:m, :], keep[-m:, :], keep[:, :m], keep[:, -m:] = False, False, False, False
    if mask_rect:
        mx0, my0, mx1, my1 = [c // BOX for c in mask_rect]
        keep[my0:my1, mx0:mx1] = False
    return a[keep], b[keep], uv[keep]


def fit(pairs, reg, weights=None):
    """The colour stage that fits every pair in `pairs` (name -> (A, B, UV)) at once, each pair counting the
    same (or as `weights` says: name -> weight, 1 by default), whatever its size."""
    lam_m, lam_o, lam_c = reg, reg, 0.01
    labs = {name: srgb_to_lab(B) for name, (_, B, _) in pairs.items()}
    weights = {name: (weights or {}).get(name, 1.0) for name in pairs}
    total = sum(weights.values())

    def residuals(p):
        parts = []
        for name, (A, _, UV) in pairs.items():
            out = ColourStage.apply(p, A, UV)
            parts.append((srgb_to_lab(out) - labs[name]).ravel() * np.sqrt(weights[name] / (len(A) * total)))
        M, o, knots, vig = ColourStage.unpack(p)
        parts += [lam_m * (M - np.eye(3)).ravel(), lam_o * o,
                  lam_c * np.diff(knots, 2, axis=1).ravel(),
                  # Curves stay increasing, and end near black and white unless the data insists.
                  20 * np.minimum(np.diff(knots, axis=1), 0).ravel()]
        return np.concatenate(parts)

    res = optimize.least_squares(residuals, ColourStage.identity(), method="trf", x_scale="jac", max_nfev=400, verbose=0)
    return res.x


def measure(p, pairs):
    """Per pair: the ΔE2000 of the fit and of the plain input against the reference."""
    out = {}
    for name, (A, B, UV) in pairs.items():
        lab_b = srgb_to_lab(B)
        de = delta_e2000(srgb_to_lab(ColourStage.apply(p, A, UV)), lab_b)
        de0 = delta_e2000(srgb_to_lab(A), lab_b)
        out[name] = {"deltaE_median": float(np.median(de)), "deltaE_p95": float(np.percentile(de, 95)),
                     "deltaE_mean": float(de.mean()), "deltaE_input_median": float(np.median(de0)),
                     "deltaE_input_p95": float(np.percentile(de0, 95)), "samples": int(len(A))}
    return out


def report(path, p, images, pairs, label):
    """input | fit | reference for each pair, the curves, and the measured luminance response."""
    tiles = []
    for name, (pair_in, ref) in images.items():
        h, w = ref.shape[:2]
        tile_w = int(min(600, 700 * w / h))
        tile_h = int(round(h * tile_w / w))
        full_uv = np.stack([(np.arange(w) + 0.5)[None, :].repeat(h, 0) / w, (np.arange(h) + 0.5)[:, None].repeat(w, 1) / h], -1)
        fit_full = ColourStage.apply(p, pair_in, full_uv)
        row = [Image.fromarray((x * 255).round().astype(np.uint8)).resize((tile_w, tile_h), Image.LANCZOS)
               for x in (pair_in, fit_full, ref)]
        tiles.append((name, row, tile_w, tile_h))
    width = max(t[2] * 3 + 40 for t in tiles)
    width = max(width, 1840)
    rows_h = sum(t[3] + 30 for t in tiles)
    plot_h = 260
    out = Image.new("RGB", (width, rows_h + plot_h + 60), (40, 40, 40))
    d = ImageDraw.Draw(out)
    y = 0
    for name, row, tile_w, tile_h in tiles:
        for i, t in enumerate(row):
            out.paste(t, (10 + i * (tile_w + 10), y + 30))
        for i, text in enumerate((f"{name}: input", f"fit  ΔE median {label[name]['deltaE_median']:.2f}  p95 {label[name]['deltaE_p95']:.2f}", "reference")):
            d.text((10 + i * (tile_w + 10), y + 10), text, fill=(230, 230, 230))
        y += tile_h + 30
    M, o, knots, vig = ColourStage.unpack(p)
    px, py, size = 10, y + 20, plot_h - 10
    d.rectangle([px, py, px + size, py + size], outline=(120, 120, 120))
    xs = np.linspace(0, 1, 200)
    for c, colr in enumerate(((255, 90, 90), (90, 220, 90), (110, 140, 255))):
        ys = curve(xs, knots[c])
        d.line([(px + x * size, py + size - v * size) for x, v in zip(xs, ys)], fill=colr, width=2)
    d.line([(px, py + size), (px + size, py)], fill=(90, 90, 90))
    d.text((px, py + size + 4), "tone curves after the matrix (r g b)", fill=(200, 200, 200))
    px2 = px + size + 40
    d.rectangle([px2, py, px2 + size, py + size], outline=(120, 120, 120))
    lin = np.concatenate([luminance(A) for A, _, _ in pairs.values()])
    lout = np.concatenate([luminance(B) for _, B, _ in pairs.values()])
    bins = np.linspace(0, 1, 33)
    idx = np.digitize(lin, bins) - 1
    for i in range(32):
        sel = idx == i
        if sel.sum() > 20:
            x = (bins[i] + bins[i + 1]) / 2
            v = np.median(lout[sel])
            d.ellipse([px2 + x * size - 3, py + size - v * size - 3, px2 + x * size + 3, py + size - v * size + 3], fill=(240, 200, 80))
    d.line([(px2, py + size), (px2 + size, py)], fill=(90, 90, 90))
    d.text((px2, py + size + 4), "measured luminance: input -> reference (median per bin)", fill=(200, 200, 200))
    d.text((px2 + size + 40, py), ColourStage.describe(p), fill=(220, 220, 220))
    out.save(path)


def parse_options(argv):
    """--mask, --inset, --weight, --reg, --pair; --mask, --inset and --weight qualified by a pair's name when
    there are several."""
    masks, insets, weights, reg, pair_prefixes = {}, {}, {}, 0.02, []
    i = 0
    while i < len(argv):
        flag = argv[i]
        if flag in ("--mask", "--inset", "--weight"):
            value = argv[i + 1]
            name, _, value = value.rpartition("=")
            parsed = [int(v) for v in value.split(",")] if flag == "--mask" else float(value)
            {"--mask": masks, "--inset": insets, "--weight": weights}[flag][name or None] = parsed
            i += 2
        elif flag == "--reg":
            reg = float(argv[i + 1])
            i += 2
        elif flag == "--pair":
            pair_prefixes.append(argv[i + 1])
            i += 2
        else:
            i += 1
    return masks, insets, weights, reg, pair_prefixes


def setting(table, name, default):
    """The value for this pair: its own, else the unqualified one, else the default."""
    if name in table:
        return table[name]
    return table.get(None, default)


def main(argv):
    cam = argv[1]
    if "--pair" in argv:
        outdir = argv[2]
        masks, insets, weights, reg, prefixes = parse_options(argv[3:])
        images, pairs, alignments = {}, {}, {}
        for prefix in prefixes:
            name = os.path.basename(prefix)
            pair_in = np.asarray(Image.open(prefix + "-input.png").convert("RGB")).astype(np.float64) / 255
            ref = np.asarray(Image.open(prefix + "-reference.png").convert("RGB")).astype(np.float64) / 255
            own = json.load(open(prefix + ".json")) if os.path.exists(prefix + ".json") else {}
            mask = setting(masks, name, own.get("mask"))
            inset = setting(insets, name, own.get("inset", 0.02))
            images[name] = (pair_in, ref)
            pairs[name] = samples(pair_in, ref, inset, mask)
            alignments[name] = {k: own[k] for k in ("scale", "x0", "y0") if k in own} | {"mask": mask, "inset": inset}
            print(f"{cam}: pair {name} {ref.shape[1]}x{ref.shape[0]}, inset {inset}, mask {mask}, {len(pairs[name][0])} samples")
    else:
        input_path, ref_path, outdir = argv[2:5]
        masks, insets, weights, reg, _ = parse_options(argv[5:])
        mask, inset = masks.get(None), insets.get(None, 0.02)
        pair_in, ref, alignment = make_pair(cam, input_path, ref_path, outdir)
        images = {cam: (pair_in, ref)}
        pairs = {cam: samples(pair_in, ref, inset, mask)}
        alignments = {cam: alignment | {"mask": mask, "inset": inset}}
        print(f"  fitting on {len(pairs[cam][0])} pairs")

    weights = {name: setting(weights, name, 1.0) for name in pairs}
    p = fit(pairs, reg, weights)
    numbers = measure(p, pairs)
    for name, n in numbers.items():
        print(f"  {name}: ΔE2000 input vs reference: median {n['deltaE_input_median']:.2f}, p95 {n['deltaE_input_p95']:.2f}")
        print(f"  {name}: ΔE2000 fit vs reference:   median {n['deltaE_median']:.2f}, p95 {n['deltaE_p95']:.2f}, mean {n['deltaE_mean']:.2f}")
    print("  " + ColourStage.describe(p).replace("\n", "\n  "))

    M, o, knots, vig = ColourStage.unpack(p)
    worst = max(numbers.values(), key=lambda n: n["deltaE_median"])
    record = {"camera": cam, "reg": reg,
              "pairs": [{"name": name, "weight": weights[name]} | alignments[name] | n for name, n in numbers.items()],
              "matrix": M.tolist(), "offset": o.tolist(), "knots": knots.tolist(), "knotX": KNOT_X.tolist(), "vignette": vig,
              "deltaE_median": worst["deltaE_median"], "deltaE_p95": worst["deltaE_p95"],
              "deltaE_input_median": worst["deltaE_input_median"]}
    if len(pairs) == 1:
        record |= alignments[cam]
    with open(f"{outdir}/{cam}.json", "w") as f:
        json.dump(record, f, indent=2)
    report(f"{outdir}/{cam}-report.png", p, images, pairs, numbers)


if __name__ == "__main__":
    main(sys.argv)
