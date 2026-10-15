"""Loading pictures and averaging them into blocks, shared by the measuring scripts."""
import io

import numpy as np
from PIL import Image, ImageCms, ImageOps


def load_rgb(path):
    """A picture as stored, RGB in 0...1."""
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255


def load_srgb(path):
    """A picture upright and converted to sRGB when tagged with another profile, RGB in 0...255."""
    image = ImageOps.exif_transpose(Image.open(path))
    icc = image.info.get("icc_profile")
    image = image.convert("RGB")
    if icc:
        profile = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        if "sRGB" not in (ImageCms.getProfileDescription(profile) or ""):
            image = ImageCms.profileToProfile(image, profile, ImageCms.createProfile("sRGB"), outputMode="RGB")
    return np.asarray(image).astype(np.float64)


def box(a, n=4):
    h, w = a.shape[0] // n, a.shape[1] // n
    return a[: h * n, : w * n].reshape(h, n, w, n, 3).mean(axis=(1, 3))
