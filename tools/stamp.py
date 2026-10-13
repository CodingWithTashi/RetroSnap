"""Measure a camera's date stamp from the reference app's exports: where it sits, how big it is, its colour and
its glow, as fractions of the film's frame so the same numbers draw it at any size.

    venv/bin/python -I tools/stamp.py <export> [<export> ...] [--crops <dir>]

The stamp is the orange-red ink the reference burns into the lower right of the film's landscape frame; on a
portrait picture the frame is turned a quarter clockwise, so it runs down the left edge. For each export the
script finds the ink (red well above green and blue), splits it into glyphs along the text's direction, and
prints: the cap height as a fraction of the frame's short side, the baseline's distance from the frame's bottom
edge (short side) and the right margin (long side), each glyph's width in cap heights, the ink colour where it
is brightest (sRGB), and how far the glow reaches. `--crops` also saves each stamp at 1:1 and as an ink mask,
turned upright, for drawing the glyphs. The box it prints is the `--mask` for `tools/fit.py`.
"""
import io
import os
import sys
import numpy as np
from PIL import Image, ImageCms, ImageOps
from scipy import ndimage


def load(path):
    image = ImageOps.exif_transpose(Image.open(path))
    icc = image.info.get("icc_profile")
    image = image.convert("RGB")
    if icc:
        profile = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        if "sRGB" not in (ImageCms.getProfileDescription(profile) or ""):
            image = ImageCms.profileToProfile(image, profile, ImageCms.createProfile("sRGB"), outputMode="RGB")
    return np.asarray(image).astype(np.float64)


def ink_mask(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r > 150) & (r - g > 70) & (r - b > 90) & (g < 180)


def main(paths, crops=None):
    for path in paths:
        rgb = load(path)
        H, W = rgb.shape[:2]
        landscape = W >= H
        # The landscape frame: for a portrait export, turn the picture a quarter anticlockwise so the stamp reads
        # left to right along the bottom (the frame was turned clockwise to stand up).
        frame = rgb if landscape else np.rot90(rgb, k=1)  # anticlockwise
        fh, fw = frame.shape[:2]
        corner = frame[int(fh * 0.7):, int(fw * 0.5):]
        mask = ink_mask(corner)
        mask = ndimage.binary_opening(mask, iterations=1)
        labels, n = ndimage.label(mask)
        sizes = ndimage.sum(mask, labels, range(1, n + 1))
        keep = np.isin(labels, 1 + np.flatnonzero(sizes > 30))
        if not keep.any():
            print(f"{os.path.basename(path)}: no stamp found"); continue
        ys, xs = np.nonzero(keep)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        oy, ox = int(fh * 0.7), int(fw * 0.5)
        cap = y1 - y0
        # Glyphs: columns with ink, split at gaps wider than a fifth of the cap height.
        cols = keep[y0:y1, x0:x1].any(axis=0)
        glyphs, start = [], None
        gap = 0
        for i, c in enumerate(cols):
            if c:
                if start is None:
                    start = i
                gap = 0
            elif start is not None:
                gap += 1
                if gap > cap * 0.22:
                    glyphs.append((start, i - gap)); start = None; gap = 0
        if start is not None:
            glyphs.append((start, len(cols)))
        # Ink colour: the brightest fifth of the ink pixels.
        inside = ndimage.binary_erosion(keep, iterations=2)
        ink = corner[inside if inside.sum() > 100 else keep]
        bright = ink
        # Glow: the orange tint outside the ink, by distance from it, until it fades.
        dist = ndimage.distance_transform_edt(~keep)
        base = corner[(dist > cap * 1.5) & (dist < cap * 2.5)]
        base_r = np.median(base[..., 0] - base[..., 2])
        glow = []
        for d in range(1, int(cap * 0.8)):
            sel = (dist > d - 0.5) & (dist <= d + 0.5)
            if sel.sum() < 50:
                break
            glow.append((d, float(np.median(corner[sel][..., 0] - corner[sel][..., 2]) - base_r)))
        reach = next((d for d, v in glow if v < 8), None)
        short, long_ = (fh, fw)
        bottom = fh - (y1 + oy)
        right = fw - (x1 + ox)
        print(f"{os.path.basename(path)}: {W}x{H} {'landscape' if landscape else 'portrait, frame turned'}")
        print(f"  ink box in the landscape frame: x {x0 + ox}..{x1 + ox}, y {y0 + oy}..{y1 + oy} (cap {cap} px)")
        print(f"  cap height {cap / short:.4f} of the short side; baseline {bottom / short:.4f} of the short side up; "
              f"right margin {right / long_:.4f} of the long side; text width {(x1 - x0) / cap:.3f} caps")
        print("  glyphs (left, width in caps, gap before in caps):", " ".join(
            f"[{a / cap:.2f},{(b - a) / cap:.2f},{((a - glyphs[i - 1][1]) if i else 0) / cap:.2f}]" for i, (a, b) in enumerate(glyphs)))
        print(f"  ink colour (inside the glyphs, sRGB): median {np.median(bright, axis=0).round(1)}, p90 {np.percentile(bright, 90, axis=0).round(1)}; ink pixels {keep.sum()}, inside {len(ink)}")
        print(f"  glow (red minus blue above the surroundings, by distance in px): " + " ".join(f"{d}:{v:.0f}" for d, v in glow[:12])
              + (f"; fades under 8 at {reach} px ({reach / cap:.2f} caps)" if reach else ""))
        # The box for --mask, in the export's own pixels, with room for the glow.
        pad = int(cap * 0.6)
        bx0, by0, bx1, by1 = x0 + ox - pad, y0 + oy - pad, x1 + ox + pad, y1 + oy + pad
        if landscape:
            mx0, my0, mx1, my1 = bx0, by0, bx1, by1
        else:
            # The export was turned anticlockwise to make the frame: frame x is the export's y, and frame y counts
            # from the export's right edge, so the box goes back the same way.
            mx0, my0, mx1, my1 = fh - by1, bx0, fh - by0, bx1
        print(f"  --mask {max(mx0, 0)},{max(my0, 0)},{min(mx1, W)},{min(my1, H)}")
        if crops:
            os.makedirs(crops, exist_ok=True)
            name = os.path.splitext(os.path.basename(path))[0].replace(" ", "_")
            tile = corner[y0 - pad:y1 + pad, x0 - pad:x1 + pad]
            Image.fromarray(tile.round().astype(np.uint8)).save(f"{crops}/{name}-stamp.png")
            Image.fromarray((keep[y0 - pad:y1 + pad, x0 - pad:x1 + pad] * 255).astype(np.uint8)).save(f"{crops}/{name}-ink.png")


if __name__ == "__main__":
    args = sys.argv[1:]
    crops = None
    if "--crops" in args:
        i = args.index("--crops"); crops = args[i + 1]; del args[i:i + 2]
    main(args, crops)
