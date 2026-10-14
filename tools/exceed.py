"""The brief's "Exceed" list, each item as a number against the reference app's output.

    venv/bin/python -I tools/exceed.py clipping <id> [...]        # (d) the share of clipped pixels, ours against the reference's, per pair
    venv/bin/python -I tools/exceed.py banding <id> [...]         # (c) distinct levels across the wall and the backlit sky, ours against the reference's
    venv/bin/python -I tools/exceed.py grain                      # (a) the grain's amplitude and clump size in points at 12 and 48 MP (`ExceedTests`)
    venv/bin/python -I tools/exceed.py metadata                   # (e) the EXIF our export carries against the reference app's, for the same input
    venv/bin/python -I tools/exceed.py viewfinder <id> <camera screenshot>   # (b) the camera screen's viewfinder against the bake of the same scene

`clipping` counts, inside the pair's inset, the 4x4 boxes whose mean is at 254 or above in any channel and in all
three, in RetroSnap's render (`<pair>-retrosnap.png`) and in the reference. `banding` takes the flat pictures
(the wall, `-6`; the backlit window, `-4`): along the picture's middle column and row, the number of distinct 8-bit
levels each channel takes after a 9-px running mean (a stepped gradient takes few), and the longest run of one
level, ours against the reference's. `grain` reads `ref/pairs/exceed-grain-12mp.png` and `-48mp.png`, the same
point-sized region of the same photo baked at both sizes, and measures the high-pass amplitude and the
autocorrelation's half-lag in points. `metadata` reads `ref/pairs/exceed-metadata.jpg` and the reference app's
export of the same input and lists which of the lens, exposure, date, orientation and place tags each carries.
`viewfinder` cuts the viewfinder's middle from the screenshot (between the top and bottom scrims) and compares it
with `ref/pairs/exceed-viewfinder-<id>.png`, the bake of the scene the mock camera shows, as `screen_vs_bake.py`
compares the Viewer.
"""
import os
import sys

import numpy as np
from PIL import ExifTags, Image, ImageOps
from scipy import ndimage

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import delta_e2000, srgb_to_lab  # noqa: E402
from pairs import INPUTS, PAIRS, input_path, recipe, suffix_of  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(float)


def box(a, n=4):
    h, w = a.shape[0] // n, a.shape[1] // n
    return a[: h * n, : w * n].reshape(h, n, w, n, 3).mean(axis=(1, 3))


def clipping(cams):
    print(f"{'pair':16s} {'picture':9s} {'ours any':>9s} {'ref any':>9s} {'ours all':>9s} {'ref all':>9s}   (share of 4x4 boxes at 254 or above)")
    for cam in cams:
        for suffix in PAIRS[cam]:
            pair = cam + suffix
            if not os.path.exists(f"{R}/{pair}-retrosnap.png"):
                continue
            ref, ours = box(load(f"{R}/{pair}-reference.png")), box(load(f"{R}/{pair}-retrosnap.png"))
            m = int((0.06 if cam == "slide" else 0.02) * ref.shape[1] * 4) // 4
            ref, ours = ref[m:-m or None, m:-m or None], ours[m:-m or None, m:-m or None]
            def share(a, how):
                return (a >= 254).any(axis=2).mean() if how == "any" else (a >= 254).all(axis=2).mean()
            flag = "" if share(ours, "any") <= share(ref, "any") + 0.0005 else "  <- ours clips more"
            print(f"{pair:16s} {INPUTS[suffix][0]:9s} {share(ours, 'any') * 100:8.2f}% {share(ref, 'any') * 100:8.2f}% {share(ours, 'all') * 100:8.2f}% {share(ref, 'all') * 100:8.2f}%{flag}")


def levels(line):
    """Distinct 8-bit levels a smoothed line takes, and the longest run of one level, per channel."""
    out = []
    for c in range(3):
        v = np.round(ndimage.uniform_filter1d(line[:, c], 9)).astype(int)
        distinct = len(np.unique(v))
        runs, start = [], 0
        for i in range(1, len(v) + 1):
            if i == len(v) or v[i] != v[start]:
                runs.append(i - start); start = i
        out.append((distinct, max(runs)))
    return out


def banding(cams):
    print(f"{'pair':16s} {'line':7s} {'ours levels r/g/b':>20s} {'ref levels r/g/b':>20s} {'ours longest run':>18s} {'ref longest run':>16s}")
    for cam in cams:
        for suffix in ("-6", "-4"):
            pair = cam + suffix
            if suffix not in PAIRS[cam] or not os.path.exists(f"{R}/{pair}-retrosnap.png"):
                continue
            ref, ours = load(f"{R}/{pair}-reference.png"), load(f"{R}/{pair}-retrosnap.png")
            h, w = ref.shape[:2]
            region = {"-6": (slice(int(0.1 * h), int(0.9 * h)), slice(int(0.1 * w), int(0.9 * w))),
                      "-4": (slice(int(0.15 * h), int(0.55 * h)), slice(int(0.35 * w), int(0.65 * w)))}[suffix]
            for name, take in (("column", lambda a: a[region[0], (region[1].start + region[1].stop) // 2]), ("row", lambda a: a[(region[0].start + region[0].stop) // 2, region[1]])):
                lo, lr = levels(take(ours)), levels(take(ref))
                print(f"{pair:16s} {name:7s} {'/'.join(str(x[0]) for x in lo):>20s} {'/'.join(str(x[0]) for x in lr):>20s} {max(x[1] for x in lo):>14d} px {max(x[1] for x in lr):>12d} px")


def grain_numbers(path, scale):
    """High-pass amplitude (0...255) and the autocorrelation half-lag in points of a flat region, at `scale` px/pt."""
    lum = load(path) @ [0.2126, 0.7152, 0.0722]
    sigma = 2.5 * scale
    hp = lum - ndimage.gaussian_filter(lum, sigma)
    amp = hp.std()
    f = hp - hp.mean()
    v = (f * f).mean()
    acc = [(f[:, lag:] * f[:, : f.shape[1] - lag]).mean() / v for lag in range(0, int(8 * scale) + 1)]
    half = next((lag for lag, a in enumerate(acc) if a < 0.5), len(acc))
    return amp, half / scale, acc


def grain():
    for mp, scale in (("12mp", None), ("48mp", None)):
        path = f"{R}/exceed-grain-{mp}.png"
        if not os.path.exists(path):
            print(f"{path} missing: run ExceedTests"); return
    # The region is the same in points at both sizes; the 48 MP crop has twice the pixels along each side.
    a12 = Image.open(f"{R}/exceed-grain-12mp.png"); a48 = Image.open(f"{R}/exceed-grain-48mp.png")
    s12 = a12.width / 200; s48 = a48.width / 200
    for name, path, scale in (("12 MP", f"{R}/exceed-grain-12mp.png", s12), ("48 MP", f"{R}/exceed-grain-48mp.png", s48)):
        amp, half, acc = grain_numbers(path, scale)
        print(f"{name}: {scale:.2f} px/pt; grain amplitude {amp:.2f}/255 (high-pass at 2.5 pt), clump half-lag {half:.2f} pt; autocorrelation by point " +
              " ".join(f"{acc[int(round(k * scale))]:.2f}" for k in range(0, 5) if int(round(k * scale)) < len(acc)))


def metadata():
    ours = f"{R}/exceed-metadata.jpg"
    theirs = os.path.join(R, "..", "photo", PAIRS["film"][""]["file"])
    if not os.path.exists(ours):
        print(f"{ours} missing: run ExceedTests"); return
    tags = {"lens": ("LensModel", "FocalLength", "FocalLengthIn35mmFilm"), "exposure": ("ExposureTime", "FNumber", "ISOSpeedRatings"),
            "date": ("DateTimeOriginal", "OffsetTimeOriginal"), "camera": ("Make", "Model")}
    def read(path):
        im = Image.open(path); ex = im.getexif()
        ifd0 = {ExifTags.TAGS.get(k, k): v for k, v in ex.items()}
        exif = {ExifTags.TAGS.get(k, k): v for k, v in ex.get_ifd(0x8769).items()}
        gps = dict(ex.get_ifd(0x8825))
        return im, ifd0 | exif, gps
    for who, path in (("RetroSnap", ours), ("reference", theirs)):
        im, all_tags, gps = read(path)
        print(f"{who}: {os.path.basename(path)[:40]} {im.size}, orientation {all_tags.get('Orientation')}, icc {'yes' if im.info.get('icc_profile') else 'no'}, GPS tags {len(gps)}")
        for group, names in tags.items():
            print(f"   {group}: " + ", ".join(f"{n}={str(all_tags.get(n))[:28]}" for n in names))


def viewfinder(cam, shot):
    bake = Image.open(f"{R}/exceed-viewfinder-{cam}.png").convert("RGB")
    screen = Image.open(shot).convert("RGB")
    scale = screen.width / 390
    # The viewfinder fills the screen; the scrims shade its top 150 pt and bottom 330 pt, and a square camera dims the
    # bands outside its picture (227 pt), so 240 to 500 pt is compared.
    top, bottom = int(240 * scale), int(500 * scale)
    region = screen.crop((0, top, screen.width, bottom))
    factor = bake.width / screen.width
    cut = bake.crop((0, int(top * factor), bake.width, int(bottom * factor))).resize(region.size, Image.LANCZOS)
    a = np.asarray(region).astype(float) / 255
    b = np.asarray(cut).astype(float) / 255
    de = delta_e2000(srgb_to_lab(box(a)), srgb_to_lab(box(b)))
    print(f"{cam}: viewfinder {region.size[0]}x{region.size[1]} vs bake: mean abs diff {np.abs(a - b).mean() * 255:.2f}/255 per channel, "
          f"ΔE2000 median {np.median(de):.2f} p95 {np.percentile(de, 95):.2f}")
    side = Image.new("RGB", (region.width * 2 + 10, region.height), (60, 60, 60))
    side.paste(region, (0, 0)); side.paste(cut, (region.width + 10, 0))
    side.save(f"{R}/exceed-viewfinder-{cam}-vs-screen.png")


if __name__ == "__main__":
    what, rest = sys.argv[1], sys.argv[2:]
    {"clipping": lambda: clipping(rest), "banding": lambda: banding(rest), "grain": grain, "metadata": metadata,
     "viewfinder": lambda: viewfinder(rest[0], rest[1])}[what]()
