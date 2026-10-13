"""Colour maths shared by the calibration scripts: sRGB <-> CIELAB, ΔE2000, and the parametric
colour stage exactly as `RetroLook.metal` evaluates it (matrix, monotone tone curves, then the per-hue
shift, saturation and lightness terms)."""
import numpy as np

# The tone curves' knot positions. Fixed, so a recipe only stores the six values per channel.
KNOT_X = np.array([0.0, 0.1, 0.25, 0.45, 0.7, 1.0])
# The hue terms' sector centres, in degrees around the hue circle; the same for every camera.
HUE_SECTORS = 8
HUE_CENTRES = np.arange(HUE_SECTORS) * (360.0 / HUE_SECTORS)
# Luma weights the hue terms work against (Rec. 709 on gamma-encoded values, as the shader does).
_LUMA = np.array([0.2126, 0.7152, 0.0722])
# The chroma below which the hue terms fade out, so near-neutral pixels keep their (noisy) hue.
HUE_CHROMA_FADE = (0.02, 0.10)


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


def hue_weights(angle_deg):
    """How much each sector's terms count at these hue angles (..., HUE_SECTORS): triangular bumps a sector
    wide, which add up to one everywhere. `rs_hueWeights` in the shader is the same."""
    width = 360.0 / HUE_SECTORS
    d = (angle_deg[..., None] - HUE_CENTRES + 180.0) % 360.0 - 180.0
    return np.clip(1.0 - np.abs(d) / width, 0.0, 1.0)


def hue_adjust(rgb, shift, sat, light):
    """The per-hue terms on gamma-encoded sRGB: the pixel's hue (from its red and blue differences to luma)
    picks a shift in radians, a chroma gain and a luma gain from the sectors; neutrals are left alone.
    `rs_hueAdjust` in the shader does the same."""
    y = rgb @ _LUMA
    u = rgb[..., 0] - y
    v = rgb[..., 2] - y
    chroma = np.hypot(u, v)
    angle = np.degrees(np.arctan2(v, u)) % 360.0
    w = hue_weights(angle)
    t = np.clip((chroma - HUE_CHROMA_FADE[0]) / (HUE_CHROMA_FADE[1] - HUE_CHROMA_FADE[0]), 0, 1)
    fade = t * t * (3 - 2 * t)
    d_angle = (w @ shift) * fade
    gain = 1 + ((w @ sat) - 1) * fade
    lum = 1 + ((w @ light) - 1) * fade
    new_angle = np.radians(angle) + d_angle
    c2 = chroma * gain
    u2 = c2 * np.cos(new_angle)
    v2 = c2 * np.sin(new_angle)
    y2 = y * lum
    r = y2 + u2
    b = y2 + v2
    g = (y2 - _LUMA[0] * r - _LUMA[2] * b) / _LUMA[1]
    return np.clip(np.stack([r, g, b], axis=-1), 0, 1)


def vignette(rgb, uv, amount):
    """The look's vignette: radial-gradient(ellipse at center, transparent 48%, rgba(20,10,0,.9) 100%)."""
    d = (uv - 0.5) / 0.70710678
    t = np.hypot(d[..., 0], d[..., 1])
    a = 0.9 * np.clip((t - 0.48) / 0.52, 0, 1) * amount
    dark = np.array([20, 10, 0]) / 255
    return rgb * (1 - a[..., None]) + dark * a[..., None]


class ColourStage:
    """matrix (3x3 + offset) -> per-channel monotone curves -> per-hue shift / saturation / lightness
    -> vignette. 31 + 24 parameters."""
    BASE = 9 + 3 + 18 + 1
    SIZE = BASE + 3 * HUE_SECTORS

    @staticmethod
    def identity():
        p = np.zeros(ColourStage.SIZE)
        p[0:9] = np.eye(3).ravel()
        p[12:30] = np.tile(KNOT_X, 3)
        p[31:31 + HUE_SECTORS] = 0.0
        p[31 + HUE_SECTORS:31 + 2 * HUE_SECTORS] = 1.0
        p[31 + 2 * HUE_SECTORS:] = 1.0
        return p

    @staticmethod
    def unpack(p):
        n = HUE_SECTORS
        hue = (p[31:31 + n], p[31 + n:31 + 2 * n], p[31 + 2 * n:31 + 3 * n])
        return p[0:9].reshape(3, 3), p[9:12], p[12:30].reshape(3, 6), p[30], hue

    @staticmethod
    def apply(p, rgb, uv=None):
        M, o, knots, vig, (shift, sat, light) = ColourStage.unpack(p)
        x = np.clip(rgb @ M.T + o, 0, 1)
        y = np.stack([curve(x[..., c], knots[c]) for c in range(3)], axis=-1)
        if np.any(shift != 0) or np.any(sat != 1) or np.any(light != 1):
            y = hue_adjust(y, shift, sat, light)
        if uv is not None and vig != 0:
            y = vignette(y, uv, vig)
        return np.clip(y, 0, 1)

    @staticmethod
    def from_json(d):
        """The parameters a fit's JSON records (an older JSON without hue terms reads as identity terms)."""
        p = ColourStage.identity()
        p[0:9] = np.array(d["matrix"]).ravel()
        p[9:12] = d["offset"]
        p[12:30] = np.array(d["knots"]).ravel()
        p[30] = d["vignette"]
        hue = d.get("hue")
        if hue:
            n = HUE_SECTORS
            p[31:31 + n] = hue["shift"]
            p[31 + n:31 + 2 * n] = hue["saturation"]
            p[31 + 2 * n:31 + 3 * n] = hue["lightness"]
        return p

    @staticmethod
    def to_json(p):
        M, o, knots, vig, (shift, sat, light) = ColourStage.unpack(p)
        return {"matrix": M.tolist(), "offset": o.tolist(), "knots": knots.tolist(), "knotX": KNOT_X.tolist(),
                "vignette": float(vig),
                "hue": {"centres": HUE_CENTRES.tolist(), "shift": shift.tolist(), "saturation": sat.tolist(),
                        "lightness": light.tolist()}}

    @staticmethod
    def describe(p):
        M, o, knots, vig, (shift, sat, light) = ColourStage.unpack(p)
        lines = ["matrix (rows r g b, then offset):"]
        for row, off in zip(M, o):
            lines.append("  " + " ".join(f"{v:+.4f}" for v in row) + f"   {off:+.4f}")
        for name, k in zip("rgb", knots):
            lines.append(f"curve {name}: " + " ".join(f"{v:.4f}" for v in k))
        lines.append(f"vignette: {vig:.3f}")
        lines.append("hue sectors " + " ".join(f"{int(c):3d}" for c in HUE_CENTRES))
        lines.append("  shift deg " + " ".join(f"{np.degrees(v):+5.1f}" for v in shift))
        lines.append("  saturation" + " ".join(f"{v:5.2f}" for v in sat))
        lines.append("  lightness " + " ".join(f"{v:5.2f}" for v in light))
        return "\n".join(lines)
