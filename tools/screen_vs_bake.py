"""Hold a baked file against the screen: the Viewer's screenshot of a framed photo versus the export of the
same photo (`BakeVersusScreenTests` writes `ref/pairs/bake-<id>.png`).

    venv/bin/python tools/screen_vs_bake.py <id> <viewer screenshot> [ref/pairs] [--points 393 852 --safe-top 59]

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
from images import box  # noqa: E402


def main(cam, shot, pairs="ref/pairs", points=(390.0, 844.0), safe_top=47.0):
    """`points` and `safe_top` describe the screen the shot came from: the design's 390x844 with a 47pt safe top
    (the simulator), or a phone's own (`--points 393 852 --safe-top 59` for an iPhone 15), since `DesignLayout`
    keeps the viewer's 104pt top clearance from the safe area and its 148pt from the bottom edge."""
    screen = Image.open(shot).convert("RGB")
    w_pt, h_pt = points
    scale = screen.width / w_pt
    bake = Image.open(f"{pairs}/bake-{cam}.png").convert("RGB")
    box_top = 104 + max(0.0, safe_top - 47)
    box_height = h_pt - box_top - 148
    height = min(box_height, w_pt * bake.height / bake.width)
    width = height * bake.width / bake.height
    top = int(round((box_top + (box_height - height) / 2) * scale))
    left = int(round((w_pt - width) / 2 * scale))
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
    args = sys.argv[1:]
    points, safe_top = (390.0, 844.0), 47.0
    if "--points" in args:
        i = args.index("--points"); points = (float(args[i + 1]), float(args[i + 2])); del args[i:i + 3]
    if "--safe-top" in args:
        i = args.index("--safe-top"); safe_top = float(args[i + 1]); del args[i:i + 2]
    main(*args, points=points, safe_top=safe_top)
