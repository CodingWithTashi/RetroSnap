"""Hold a baked file against the screen: the Viewer's screenshot of a framed photo versus the export of the
same photo (`BakeVersusScreenTests` writes `ref/pairs/bake-<id>.png`).

    venv/bin/python tools/screen_vs_bake.py <id> <viewer screenshot> [ref/pairs]

The Viewer shows the canvas 390pt wide, centred in the 592pt between 104pt and 148pt from the bottom of the
design's 390x844 frame (a 3:4 canvas therefore starts 140pt down); the canvas's own shape comes from the bake.
At the simulator's 3x that region is cut from the screenshot, the bake is resized to it and compared: mean
absolute difference per channel and median ΔE2000 over 4x4 boxes (grain and resampling average out).
"""
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import delta_e2000, srgb_to_lab  # noqa: E402


def box(a, n=4):
    h, w = a.shape[0] // n, a.shape[1] // n
    return a[: h * n, : w * n].reshape(h, n, w, n, 3).mean(axis=(1, 3))


def main(cam, shot, pairs="ref/pairs"):
    screen = Image.open(shot).convert("RGB")
    scale = screen.width / 390
    bake = Image.open(f"{pairs}/bake-{cam}.png").convert("RGB")
    height = min(592.0, 390 * bake.height / bake.width)
    width = height * bake.width / bake.height
    top = int(round((104 + (592 - height) / 2) * scale))
    left = int(round((390 - width) / 2 * scale))
    region = screen.crop((left, top, left + int(round(width * scale)), top + int(round(height * scale))))
    bake = bake.resize(region.size, Image.LANCZOS)
    a = np.asarray(region).astype(np.float64) / 255
    b = np.asarray(bake).astype(np.float64) / 255
    diff = np.abs(a - b)
    de = delta_e2000(srgb_to_lab(box(a)), srgb_to_lab(box(b)))
    print(f"{cam}: screen {region.size[0]}x{region.size[1]} vs bake: mean abs diff {diff.mean() * 255:.2f}/255 per channel, "
          f"ΔE2000 median {np.median(de):.2f} p95 {np.percentile(de, 95):.2f}")
    side = Image.new("RGB", (region.width * 2 + 10, region.height), (60, 60, 60))
    side.paste(region, (0, 0))
    side.paste(bake, (region.width + 10, 0))
    side.save(f"{pairs}/bake-{cam}-vs-screen.png")


if __name__ == "__main__":
    main(*sys.argv[1:])
