"""The phone's rendering of the look screen against the simulator's (the screenshots that
`testLookScreensAreKeptAsScreenshotsForTheDeviceProbe` keeps when run on a connected phone, exported with
`xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`, against `tools/shoot.sh`'s look shots): both colour-managed to sRGB, the phone's
screenshot resized to the simulator's, compared on 8x8 boxes below the status bar. Prints the median ΔE2000 and
the mean L/a/b difference (phone minus simulator) by luminance band: a phone that works in another colour space
shows up as a chroma scaling, a brightness difference as dL.

    venv/bin/python -I tools/device_probe.py <phone look-<id>.png> <simulator look-<id>.png>
"""
import io, sys
import numpy as np
from PIL import Image, ImageCms
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import srgb_to_lab, delta_e2000
def load_srgb(path):
    im = Image.open(path)
    icc = im.info.get("icc_profile")
    im = im.convert("RGB")
    if icc:
        prof = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        desc = ImageCms.getProfileDescription(prof) or ""
        if "sRGB" not in desc:
            im = ImageCms.profileToProfile(im, prof, ImageCms.createProfile("sRGB"), outputMode="RGB")
        print(f"{path}: profile {desc!r}, size {im.size}")
    else:
        print(f"{path}: untagged, size {im.size}")
    return im
def box(a, n=8):
    h, w = a.shape[0] // n, a.shape[1] // n
    return a[: h * n, : w * n].reshape(h, n, w, n, 3).mean(axis=(1, 3))
phone, sim = load_srgb(sys.argv[1]), load_srgb(sys.argv[2])
phone = phone.resize(sim.size, Image.LANCZOS)
a = np.asarray(phone).astype(float) / 255; b = np.asarray(sim).astype(float) / 255
top = int(0.08 * a.shape[0]); bottom = int(0.97 * a.shape[0])
A, B = srgb_to_lab(box(a[top:bottom])), srgb_to_lab(box(b[top:bottom]))
de = delta_e2000(A, B)
print(f"median ΔE2000 phone vs simulator {np.median(de):.2f}, p95 {np.percentile(de, 95):.2f}")
for lo, hi in [(0, 30), (30, 55), (55, 75), (75, 101)]:
    sel = (B[..., 0] >= lo) & (B[..., 0] < hi)
    if sel.sum() < 30: continue
    d = (A - B)[sel]
    ca, cb = np.hypot(A[..., 1], A[..., 2])[sel].mean(), np.hypot(B[..., 1], B[..., 2])[sel].mean()
    print(f"  L {lo:2d}-{hi:3d}: n {sel.sum():5d}  dL {d[:, 0].mean():+5.2f}  da {d[:, 1].mean():+5.2f}  db {d[:, 2].mean():+5.2f}   chroma phone {ca:5.1f} vs simulator {cb:5.1f} (ratio {ca / max(cb, 1e-6):.3f})")
