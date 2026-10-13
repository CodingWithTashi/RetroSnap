"""Find the picture inside a reference screenshot and save it as a crop.

The screenshot shows the reference app's result screen: its canvas on a black (or light) background,
with a banner and a close button below. Given a rough rectangle for the picture, the script snaps each
edge to the strongest luminance step within 60 px of it and writes the crop.

    venv/bin/python tools/refcrop.py <screenshot> <left> <top> <right> <bottom> <out.png> [--deskew]

The crop keeps the screenshot's colour profile (Display P3 on an iPhone), which `fit.py` converts to sRGB.
`--deskew` is for a canvas the reference app lays at an angle (the D Slide mount): the script measures the
tilt of the picture's left and top edges, turns the screenshot straight about the rectangle's centre
(bicubic), prints the angle, and then snaps and crops as usual.
"""
import sys
import numpy as np
from PIL import Image, ImageOps


def snap(profile, guess, window=60):
    """The index near `guess` where the profile changes most."""
    lo, hi = max(1, guess - window), min(len(profile) - 1, guess + window)
    grad = np.abs(np.diff(profile[lo - 1:hi + 1]))
    return lo + int(np.argmax(grad))


def tilt(lum, left, top, right, bottom, window=40):
    """The angle of the picture, in degrees counter-clockwise on screen, from where its left edge is on each
    row and its top edge on each column (the two edges a mount's shadow disturbs least). Each edge is the
    strongest luminance step within `window` px of the guess, fitted with a line over the middle half."""
    ys = np.arange(top + (bottom - top) // 4, bottom - (bottom - top) // 4, 8)
    xs_at = [left - window + int(np.argmax(np.abs(np.diff(lum[y, left - window:left + window])))) for y in ys]
    left_slope = np.polyfit(ys, xs_at, 1)[0]
    xs = np.arange(left + (right - left) // 4, right - (right - left) // 4, 8)
    ys_at = [top - window + int(np.argmax(np.abs(np.diff(lum[top - window:top + window, x])))) for x in xs]
    top_slope = np.polyfit(xs, ys_at, 1)[0]
    # A picture turned counter-clockwise has its left edge drifting right going down (x up with y) and
    # its top edge rising to the right (y down with x).
    return float(np.degrees((np.arctan(left_slope) - np.arctan(top_slope)) / 2))


def main(path, left, top, right, bottom, out, deskew=False):
    # Upright, and with the picture's colour profile kept, so `fit.py` can convert the crop to sRGB.
    opened = ImageOps.exif_transpose(Image.open(path))
    icc = opened.info.get("icc_profile")
    image = opened.convert("RGB")
    if deskew:
        angle = tilt(np.asarray(image).astype(np.float32).mean(axis=2), left, top, right, bottom)
        centre = ((left + right) / 2, (top + bottom) / 2)
        image = image.rotate(-angle, resample=Image.BICUBIC, center=centre)
        print(f"{path}: picture tilted {angle:+.2f} degrees; turned straight about ({centre[0]:.0f}, {centre[1]:.0f})")
    img = np.asarray(image).astype(np.float32)
    lum = img.mean(axis=2)
    # Row and column profiles taken well inside the other axis's guess, so frame text does not count.
    inset_x = slice(left + (right - left) // 4, right - (right - left) // 4)
    inset_y = slice(top + (bottom - top) // 4, bottom - (bottom - top) // 4)
    rows = lum[:, inset_x].mean(axis=1)
    cols = lum[inset_y, :].mean(axis=0)
    t = snap(rows, top)
    b = snap(rows, bottom)
    l = snap(cols, left)
    r = snap(cols, right)
    # diff index i is the step between i and i+1: the picture starts after the step at its top/left edge.
    t, l = t + 1, l + 1
    w, h = r - l, b - t
    print(f"{path}: picture x {l}..{r} y {t}..{b} -> {w}x{h}, ratio {w / h:.4f}")
    Image.fromarray(img[t:b, l:r].astype(np.uint8)).save(out, icc_profile=icc)


if __name__ == "__main__":
    a = sys.argv
    main(a[1], int(a[2]), int(a[3]), int(a[4]), int(a[5]), a[6], deskew="--deskew" in a[7:])
