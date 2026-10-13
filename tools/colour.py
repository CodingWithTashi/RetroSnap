"""Colour maths shared by the calibration scripts: sRGB <-> CIELAB, ΔE2000, and the parametric
colour stage exactly as `RetroLook.metal` evaluates it (matrix, then monotone cubic tone curves)."""
import numpy as np

# The tone curves' knot positions. Fixed, so a recipe only stores the six values per channel.
KNOT_X = np.array([0.0, 0.1, 0.25, 0.45, 0.7, 1.0])


def srgb_to_linear(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * c ** (1 / 2.4) - 0.055)


_M_RGB_XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
                       [0.2126729, 0.7151522, 0.0721750],
                       [0.0193339, 0.1191920, 0.9503041]])
_WHITE = np.array([0.95047, 1.0, 1.08883])


def srgb_to_lab(rgb):
    """rgb: (..., 3) gamma-encoded sRGB in 0...1."""
    xyz = srgb_to_linear(rgb) @ _M_RGB_XYZ.T / _WHITE
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


def delta_e2000(lab1, lab2):
    """CIEDE2000 between two (..., 3) Lab arrays, kL = kC = kH = 1."""
    L1, a1, b1 = lab1[..., 0], lab1[..., 1], lab1[..., 2]
    L2, a2, b2 = lab2[..., 0], lab2[..., 1], lab2[..., 2]
    C1 = np.hypot(a1, b1)
    C2 = np.hypot(a2, b2)
    Cm = (C1 + C2) / 2
    G = 0.5 * (1 - np.sqrt(Cm ** 7 / (Cm ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360
    dLp = L2 - L1
    dCp = C2p - C1p
    dh = h2p - h1p
    dh = np.where(np.abs(dh) > 180, dh - 360 * np.sign(dh), dh)
    dh = np.where(C1p * C2p == 0, 0, dh)
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2))
    Lm = (L1 + L2) / 2
    Cmp = (C1p + C2p) / 2
    hsum = h1p + h2p
    hm = np.where(np.abs(h1p - h2p) > 180, (hsum + 360) / 2, hsum / 2)
    hm = np.where(hm >= 360, hm - 360, hm)
    hm = np.where(C1p * C2p == 0, hsum, hm)
    T = (1 - 0.17 * np.cos(np.radians(hm - 30)) + 0.24 * np.cos(np.radians(2 * hm))
         + 0.32 * np.cos(np.radians(3 * hm + 6)) - 0.20 * np.cos(np.radians(4 * hm - 63)))
    dtheta = 30 * np.exp(-(((hm - 275) / 25) ** 2))
    RC = 2 * np.sqrt(Cmp ** 7 / (Cmp ** 7 + 25 ** 7))
    SL = 1 + 0.015 * (Lm - 50) ** 2 / np.sqrt(20 + (Lm - 50) ** 2)
    SC = 1 + 0.045 * Cmp
    SH = 1 + 0.015 * Cmp * T
    RT = -np.sin(np.radians(2 * dtheta)) * RC
    return np.sqrt((dLp / SL) ** 2 + (dCp / SC) ** 2 + (dHp / SH) ** 2 + RT * (dCp / SC) * (dHp / SH))


def hermite_tangents(y, x=KNOT_X):
    """Fritsch–Carlson tangents: the cubic through these knots is monotone wherever the knots are.
    `LookUniforms.tangents` in the app does the same sums."""
    y = np.asarray(y, dtype=np.float64)
    d = np.diff(y) / np.diff(x)
    m = np.zeros_like(y)
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, len(y) - 1):
        m[i] = 0.0 if d[i - 1] * d[i] <= 0 else (d[i - 1] + d[i]) / 2
    for i in range(len(d)):
        if d[i] == 0:
            m[i] = m[i + 1] = 0.0
            continue
        a, b = m[i] / d[i], m[i + 1] / d[i]
        s = a * a + b * b
        if s > 9:
            t = 3 / np.sqrt(s)
            m[i], m[i + 1] = t * a * d[i], t * b * d[i]
    return m


def curve(v, y, m=None, x=KNOT_X):
    """Evaluate the monotone cubic through knots (x, y) with tangents m at v (any shape), clamped."""
    if m is None:
        m = hermite_tangents(y, x)
    v = np.clip(v, 0, 1)
    i = np.clip(np.searchsorted(x, v, side="right") - 1, 0, len(x) - 2)
    h = x[i + 1] - x[i]
    t = (v - x[i]) / h
    t2, t3 = t * t, t * t * t
    h00 = 2 * t3 - 3 * t2 + 1
    h10 = t3 - 2 * t2 + t
    h01 = -2 * t3 + 3 * t2
    h11 = t3 - t2
    return np.clip(h00 * y[i] + h10 * h * m[i] + h01 * y[i + 1] + h11 * h * m[i + 1], 0, 1)


def vignette(rgb, uv, amount):
    """The look's vignette: radial-gradient(ellipse at center, transparent 48%, rgba(20,10,0,.9) 100%)."""
    d = (uv - 0.5) / 0.70710678
    t = np.hypot(d[..., 0], d[..., 1])
    a = 0.9 * np.clip((t - 0.48) / 0.52, 0, 1) * amount
    dark = np.array([20, 10, 0]) / 255
    return rgb * (1 - a[..., None]) + dark * a[..., None]


class ColourStage:
    """matrix (3x3 + offset) -> per-channel monotone curves -> vignette. 31 parameters."""
    SIZE = 9 + 3 + 18 + 1

    @staticmethod
    def identity():
        p = np.zeros(ColourStage.SIZE)
        p[0:9] = np.eye(3).ravel()
        p[12:30] = np.tile(KNOT_X, 3)
        return p

    @staticmethod
    def unpack(p):
        return p[0:9].reshape(3, 3), p[9:12], p[12:30].reshape(3, 6), p[30]

    @staticmethod
    def apply(p, rgb, uv=None):
        M, o, knots, vig = ColourStage.unpack(p)
        x = np.clip(rgb @ M.T + o, 0, 1)
        y = np.stack([curve(x[..., c], knots[c]) for c in range(3)], axis=-1)
        if uv is not None and vig != 0:
            y = vignette(y, uv, vig)
        return np.clip(y, 0, 1)

    @staticmethod
    def describe(p):
        M, o, knots, vig = ColourStage.unpack(p)
        lines = ["matrix (rows r g b, then offset):"]
        for row, off in zip(M, o):
            lines.append("  " + " ".join(f"{v:+.4f}" for v in row) + f"   {off:+.4f}")
        for name, k in zip("rgb", knots):
            lines.append(f"curve {name}: " + " ".join(f"{v:.4f}" for v in k))
        lines.append(f"vignette: {vig:.3f}")
        return "\n".join(lines)
