"""Scan a reference screenshot for the picture's rectangle.

Prints the rows and columns where the screenshot stops being its background (black, or the
slide's light grey), which is where the camera's canvas or picture starts.

    venv/bin/python tools/refscan.py "ref/photo/S 67/IMG_5889.PNG"
"""
import sys
import numpy as np
from PIL import Image


def runs(mask):
    """Start/end index pairs of the True runs in a 1-D mask."""
    out, start = [], None
    for i, m in enumerate(mask):
        if m and start is None:
            start = i
        elif not m and start is not None:
            out.append((start, i - 1))
            start = None
    if start is not None:
        out.append((start, len(mask) - 1))
    return out


def main(path):
    img = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = img.shape
    lum = img.mean(axis=2)
    # Background: the most common colour of the screenshot's top band (black, or the slide's grey).
    top = img[: h // 8].reshape(-1, 3)
    bg = np.median(top, axis=0)
    diff = np.abs(img - bg).max(axis=2)
    content = diff > 24
    rows = content.mean(axis=1) > 0.5
    cols = content.mean(axis=0) > 0.5
    print(f"{path}: {w}x{h}, background rgb {bg.round(0)}")
    print("row runs (>50% of the row differs from the background):", runs(rows))
    print("col runs:", runs(cols))
    # Also the brightest/darkest bands: where the picture (not the black frame) is.
    picture = lum > 40
    prow = picture.mean(axis=1) > 0.6
    pcol = picture.mean(axis=0) > 0.6
    print("bright row runs (>60% of the row brighter than 40):", runs(prow))
    print("bright col runs:", runs(pcol))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
        print()
