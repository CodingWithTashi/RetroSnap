"""The reference pairs: which input picture and which of the reference app's files each pair is made of, where
the picture sits in a screenshot, and the date back's mask. The one list the other scripts take the pairs from
(`refpairs.py` cuts and aligns them, `frames.py` lays them beside the exports, `verify.sh` measures them).

    venv/bin/python -I tools/pairs.py            # prints every pair

A pair is `<id>` for the picture the camera was first fitted on and `<id>-<n>` for each picture since: `-1` the
dunes, `-2` the street sign (batch 2's cameras only), `-3` the tungsten interior, `-4` the backlit window, `-5` the
market stall, `-6` the grey wall (the refinement round's four, generated pictures with no EXIF). A reference is a
`screenshot` of the result screen (batch 1's cameras: the picture is cut out with `refcrop.py`, `deskew` for a
tilted slide mount), an `export` whose 3:2 crop is the whole file (with the date back's `mask`, in the export's
pixels, for `fit.py`), or a `print` export whose `window` is cut out (`printscan.py` measured it). `canvas` is the
region of a screenshot that holds the camera's whole canvas, for `frames.py`. Rectangles are (left, top, right,
bottom) in the file's upright pixels; a screenshot's `crop` is the rough rectangle `refcrop.py` snaps.
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref")

CAMERAS = ["negative", "plastic35", "slide", "mediumFormat", "tlr", "film", "inst", "compactPro", "classicSLR", "instSquare"]
NAMES = {"negative": "135 NE", "plastic35": "CPM35", "slide": "D Slide", "mediumFormat": "S 67", "tlr": "S Classic",
         "film": "D Classic", "inst": "Inst C", "compactPro": "CT2F", "classicSLR": "Classic U", "instSquare": "Inst SQC"}

# Pair suffix -> (short name, input file, when it was taken: the stamp the reference app printed, or the import day).
INPUTS = {
    "": ("selfie", "IMG_5821.JPG", "2026-10-08T17:00:00Z"),
    "-1": ("dunes", "IMG_5326.JPG", "2026-07-23T17:00:00Z"),
    "-2": ("sign", "IMG_5646.JPG", "2026-08-21T17:00:00Z"),
    "-3": ("tungsten", "gen_tungsten.jpg", "2026-10-13T17:00:00Z"),
    "-4": ("backlit", "gen_backlit.jpg", "2026-10-13T17:00:00Z"),
    "-5": ("market", "gen_market.jpg", "2026-10-13T17:00:00Z"),
    "-6": ("wall", "gen_wall.jpg", "2026-10-13T17:00:00Z"),
}

# The date back's box in a bare 3:2 export (4032x2688 lying down, 2688x4032 standing up), with room for the glow:
# from the stamp's measured place ("Stamps" in docs/camera-lineup.md), the same on every picture.
SEGMENTS_MASK = {"landscape": (2820, 2230, 3480, 2450), "portrait": (200, 2550, 480, 3300)}
MATRIX_MASK = {"landscape": (2650, 2300, 3420, 2500), "portrait": (180, 2620, 430, 3460)}

# The reference app's canvas in a 1179x2556 screenshot, by the input's orientation, for each batch-1 camera.
CANVAS = {
    "negative": {"landscape": (0, 769, 1179, 1787), "portrait": (0, 595, 1179, 1961)},
    "plastic35": {"landscape": (0, 851, 1179, 1636), "portrait": None},
    "slide": {"landscape": (0, 560, 1179, 2016), "portrait": (0, 560, 1179, 2016)},
    "mediumFormat": {"landscape": (0, 780, 1179, 1776), "portrait": (0, 580, 1179, 1976)},
    "tlr": {"landscape": (0, 688, 1179, 1867), "portrait": (0, 688, 1179, 1867)},
}
# Where the picture sits in such a screenshot, by orientation: the reference app lays a given input shape out the
# same way every time, so one rectangle per orientation serves every picture of that shape. Measured by snapping
# the edges on the pictures that have them (the selfie, the wall) and cut as given on the others (`exact`).
CROP = {
    "negative": {"landscape": (0, 890, 1146, 1656), "portrait": (154, 632, 1041, 1947)},
    "mediumFormat": {"landscape": (57, 837, 1153, 1711), "portrait": (48, 635, 1083, 1932)},
    "tlr": {"landscape": (33, 717, 1140, 1832), "portrait": (33, 718, 1141, 1833)},
}


def screenshot(cam, suffix, file, crop=None, deskew=False, exact=None, angle=None):
    orientation = "landscape" if suffix in ("", "-4") else "portrait"
    return {"file": f"{NAMES[cam]}/{file}", "kind": "screenshot", "canvas": CANVAS[cam][orientation],
            "crop": crop or CROP[cam][orientation], "deskew": deskew, "exact": crop is None if exact is None else exact, "angle": angle}


def export(cam, suffix, file, mask):
    orientation = "landscape" if suffix in ("", "-4") else "portrait"
    return {"file": f"{NAMES[cam]}/{file}", "kind": "export", "mask": mask[orientation] if mask else None}


def print_export(cam, file, window):
    return {"file": f"{NAMES[cam]}/{file}", "kind": "print", "window": window}


PAIRS = {
    "negative": {
        "": screenshot("negative", "", "IMG_5894.PNG"), "-1": screenshot("negative", "-1", "output_1.jpeg"),
        "-3": screenshot("negative", "-3", "IMG_5936.PNG"), "-4": screenshot("negative", "-4", "IMG_5935.PNG"),
        "-5": screenshot("negative", "-5", "IMG_5934.PNG"), "-6": screenshot("negative", "-6", "IMG_5937.PNG"),
    },
    "plastic35": {
        "": screenshot("plastic35", "", "IMG_5895.PNG", crop=(0, 851, 1179, 1636)),
        "-1": export("plastic35", "-1", "output_1.jpg", {"portrait": (230, 2690, 400, 3440)}),
        "-3": export("plastic35", "-3", "cpm35 2026-10-13 1837582D29DEC0BFA9.jpg", MATRIX_MASK),
        "-4": export("plastic35", "-4", "cpm35 2026-10-13 1837599A4D487234EE.jpg", MATRIX_MASK),
        "-5": export("plastic35", "-5", "cpm35 2026-10-13 18375908FD64DED3C8.jpg", MATRIX_MASK),
        "-6": export("plastic35", "-6", "cpm35 2026-10-13 183759F3ED44AC5081.jpg", MATRIX_MASK),
    },
    "slide": {
        # The window inside the mount: 0.667 x 0.447 of the mount's side (955 px), turned the way the picture is,
        # about the mount's centre; the market and tungsten mounts lie at an angle (`deskew`).
        "": screenshot("slide", "", "IMG_5890.PNG", crop=(272, 1069, 906, 1507)),
        "-1": screenshot("slide", "-1", "output_1.jpeg", crop=(372, 969, 807, 1608), deskew=True),
        "-3": screenshot("slide", "-3", "IMG_5940.PNG", crop=(359, 946, 786, 1583), deskew=True),
        "-4": screenshot("slide", "-4", "IMG_5939.PNG", crop=(284, 1094, 920, 1510), exact=True),
        # The market mount lies at -2.0 deg (its straight outer edges, `refcrop.tilt` on the mount's rectangle); the
        # window's own edges on that busy picture had read -1.5, which left the pair 6 px out top to bottom.
        "-5": screenshot("slide", "-5", "IMG_5938.PNG", crop=(395, 976, 822, 1613), angle=-2.0),
        "-6": screenshot("slide", "-6", "IMG_5941.PNG", crop=(358, 950, 800, 1570)),
    },
    "mediumFormat": {
        "": screenshot("mediumFormat", "", "IMG_5889.PNG"), "-1": screenshot("mediumFormat", "-1", "output_1.jpeg"),
        "-3": screenshot("mediumFormat", "-3", "IMG_5944.PNG"), "-4": screenshot("mediumFormat", "-4", "IMG_5943.PNG"),
        "-5": screenshot("mediumFormat", "-5", "IMG_5942.PNG"), "-6": screenshot("mediumFormat", "-6", "IMG_5945.PNG"),
    },
    "tlr": {
        "": screenshot("tlr", "", "IMG_5892.PNG"), "-1": screenshot("tlr", "-1", "output_1.jpeg"),
        "-3": screenshot("tlr", "-3", "IMG_5948.PNG"), "-4": screenshot("tlr", "-4", "IMG_5947.PNG"),
        "-5": screenshot("tlr", "-5", "IMG_5946.PNG"), "-6": screenshot("tlr", "-6", "IMG_5949.PNG"),
    },
    "film": {
        "": export("film", "", "dclassic 2026-10-13 12584393BDF746956D.jpg", SEGMENTS_MASK),
        "-1": export("film", "-1", "dclassic 2026-10-13 12585463779A200758.jpg", SEGMENTS_MASK),
        "-2": export("film", "-2", "dclassic 2026-10-13 1258482BD4FDFDE524.jpg", SEGMENTS_MASK),
        "-3": export("film", "-3", "dclassic 2026-10-13 1843093A9910F76245.jpg", SEGMENTS_MASK),
        "-4": export("film", "-4", "dclassic 2026-10-13 184310FA626BC17C06.jpg", SEGMENTS_MASK),
        "-5": export("film", "-5", "dclassic 2026-10-13 184310E46E24DB20F4.jpg", SEGMENTS_MASK),
        "-6": export("film", "-6", "dclassic 2026-10-13 184309C12C4E2D758E.jpg", SEGMENTS_MASK),
    },
    "inst": {
        "": print_export("inst", "instc 2026-10-13 125627B1E07A644D71.jpg", None),
        "-1": print_export("inst", "instc 2026-10-13 125707D6631BF33833.jpg", None),
        "-2": print_export("inst", "instc 2026-10-13 125741FA539412BD42.jpg", None),
        "-3": print_export("inst", "instc 2026-10-13 1846292F270BF009F9.jpg", (348, 484, 2389, 3207)),
        "-4": print_export("inst", "instc 2026-10-13 1846304A43C3C42E8B.jpg", (473, 339, 3195, 2380)),
        "-5": print_export("inst", "instc 2026-10-13 1846308212D4BEBA8B.jpg", (325, 470, 2367, 3193)),
        "-6": print_export("inst", "instc 2026-10-13 1846309107A3BA31EF.jpg", (318, 465, 2359, 3188)),
    },
    "compactPro": {
        "": export("compactPro", "", "ct2f 2026-10-13 1259524B9DC3638601.jpg", SEGMENTS_MASK),
        "-1": export("compactPro", "-1", "ct2f 2026-10-13 125952BCC6D6D1B4D1.jpg", SEGMENTS_MASK),
        "-2": export("compactPro", "-2", "ct2f 2026-10-13 125953969342376801.jpg", SEGMENTS_MASK),
        "-3": export("compactPro", "-3", "ct2f 2026-10-13 184732A743D3C69B72.jpg", SEGMENTS_MASK),
        "-4": export("compactPro", "-4", "ct2f 2026-10-13 1847339FAD043812FE.jpg", SEGMENTS_MASK),
        "-5": export("compactPro", "-5", "ct2f 2026-10-13 18473351F834BE2F1D.jpg", SEGMENTS_MASK),
        "-6": export("compactPro", "-6", "ct2f 2026-10-13 184732580960DBEAA0.jpg", SEGMENTS_MASK),
    },
    "classicSLR": {
        "": export("classicSLR", "", "classicu 2026-10-13 1302126C86A06C18E2.jpg", SEGMENTS_MASK),
        "-1": export("classicSLR", "-1", "classicu 2026-10-13 130212B1F2575D660F.jpg", SEGMENTS_MASK),
        "-2": export("classicSLR", "-2", "classicu 2026-10-13 130213FED571A8FE1A.jpg", SEGMENTS_MASK),
        "-3": export("classicSLR", "-3", "classicu 2026-10-13 184815735AF2D5AB41.jpg", SEGMENTS_MASK),
        "-4": export("classicSLR", "-4", "classicu 2026-10-13 184816408D66917C54.jpg", SEGMENTS_MASK),
        "-5": export("classicSLR", "-5", "classicu 2026-10-13 1848166EDC85348AA7.jpg", SEGMENTS_MASK),
        "-6": export("classicSLR", "-6", "classicu 2026-10-13 1848164E4506E0D149.jpg", SEGMENTS_MASK),
    },
    "instSquare": {
        "": print_export("instSquare", "instsqc 2026-10-13 130051466BF8D1713F.jpg", None),
        "-1": print_export("instSquare", "instsqc 2026-10-13 130050F5A56D6C147E.jpg", None),
        "-2": print_export("instSquare", "instsqc 2026-10-13 130051DE2A0C351A86.jpg", None),
        "-3": print_export("instSquare", "instsqc 2026-10-13 1844111091B36DD628.jpg", (372, 630, 2667, 2939)),
        "-4": print_export("instSquare", "instsqc 2026-10-13 184412CB00543017FD.jpg", (334, 599, 2629, 2908)),
        "-5": print_export("instSquare", "instsqc 2026-10-13 1844124ABD9DE0025F.jpg", (338, 607, 2635, 2916)),
        "-6": print_export("instSquare", "instsqc 2026-10-13 1844115855FB757FE5.jpg", (393, 648, 2689, 2957)),
    },
}

# The square print's card the reference app gave each picture (`SquarePrintDesign`), for `ReferenceExportTests`.
SQUARE_CARDS = {"": "lightBlue", "-1": "whitePattern", "-2": "darkBlue", "-3": "plainWhite", "-4": "green", "-5": "plainWhite", "-6": "green"}


def pairs(cam):
    """The pair names a camera has, in suffix order: `negative`, `negative-1`, `negative-3`, …"""
    return [cam + suffix for suffix in PAIRS[cam]]


def reference_path(cam, suffix):
    return os.path.join(ROOT, "photo", PAIRS[cam][suffix]["file"])


def input_path(suffix):
    return os.path.join(ROOT, "photo-input", INPUTS[suffix][1])


if __name__ == "__main__":
    for cam in CAMERAS:
        for suffix, ref in PAIRS[cam].items():
            print(f"{cam + suffix:16s} {INPUTS[suffix][0]:9s} {ref['kind']:10s} {ref['file']}")


# Regions a viewer judges first, as fractions (left, top, right, bottom) of the upright input picture, mapped onto a
# pair through its alignment (`region_in_pair`): the face on the pictures that have one, and the whites.
FACE_REGION = {"": (0.30, 0.00, 0.80, 0.62), "-3": (0.40, 0.20, 0.64, 0.44), "-4": (0.42, 0.26, 0.58, 0.50)}
# The lightness the face's skin may have in the input (the backlit face is in shadow).
FACE_LIGHTNESS = {"": (40, 80), "-3": (35, 85), "-4": (18, 70)}
WHITES_REGION = {"-4": (0.28, 0.12, 0.70, 0.72), "-5": (0.30, 0.66, 0.50, 0.78), "-6": (0.0, 0.0, 1.0, 1.0)}
WHITES_NAME = {"-4": "the window", "-5": "the price card", "-6": "the wall"}


def suffix_of(pair):
    """`negative-3` -> `-3`; `negative` -> ``."""
    import re
    m = re.search(r"-\d+$", pair)
    return m.group(0) if m else ""


def camera_of(pair):
    return pair[: len(pair) - len(suffix_of(pair))]


def alignment_of(pair):
    """The alignment `fit.py` recorded for a pair (scale, x0, y0: pair = (input - origin) * scale) and its mask:
    from the pair's own JSON, or, for the first pair whose JSON is the camera's joint fit, from that fit's entry
    for the pair."""
    import json
    own = json.load(open(os.path.join(ROOT, "pairs", pair + ".json")))
    if "scale" in own:
        return own
    for entry in own.get("pairs", []):
        if entry.get("name") == pair and "scale" in entry:
            return entry
    # Batch 1's single fits were kept aside when the joint fits replaced them.
    aside = os.path.join(ROOT, "pairs", "batch1", pair + ".json")
    if os.path.exists(aside):
        kept = json.load(open(aside))
        if "scale" in kept:
            return kept
    return None


def mask_of(cam, suffix):
    """The date back's box in the pair's pixels, from the manifest, or None."""
    return PAIRS[cam][suffix].get("mask")


def region_in_pair(region, pair_json, input_size, pair_size):
    """An input region (fractions) as a pixel box in the pair, through the alignment `fit.py` recorded
    (scale, x0, y0: pair = (input - origin) * scale), clipped to the pair."""
    W, H = input_size
    w, h = pair_size
    s, x0, y0 = pair_json["scale"], pair_json["x0"], pair_json["y0"]
    l, t, r, b = region
    box = [(l * W - x0) * s, (t * H - y0) * s, (r * W - x0) * s, (b * H - y0) * s]
    return (max(0, int(box[0])), max(0, int(box[1])), min(w, int(box[2])), min(h, int(box[3])))


def recipe(cam):
    """The camera's recipe as `CameraLook.swift` has it: blur (pt), halation (threshold, radius, amount, tint name),
    grain (size, amount, colour) and vignette, read from the source so the tools measure what the app draws."""
    import re
    case = {"inst": "instant"}.get(cam, cam)
    source = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Retrosnap", "DesignSystem", "Look", "CameraLook.swift")).read()
    start = source.index(f"case .{case}:")
    end = source.find("\n        case .", start + 1)
    block = source[start:end if end > 0 else None]
    out = {"blur": 0.0, "halation": None, "grain": None, "vignette": 0.0}
    m = re.search(r"blurRadius: ([\d.]+)", block)
    if m:
        out["blur"] = float(m.group(1))
    m = re.search(r"vignette: ([\d.]+)", block)
    if m:
        out["vignette"] = float(m.group(1))
    m = re.search(r"Halation\(threshold: ([\d.]+), radius: ([\d.]+), amount: ([\d.]+), tintHex: 0x([0-9A-Fa-f]+)\)", block)
    if m:
        tint = {"FFFFFF": "white", "E0F0FF": "cool", "FF8A50": "warm"}[m.group(4).upper()]
        out["halation"] = (float(m.group(1)), float(m.group(2)), float(m.group(3)), tint)
    m = re.search(r"FilmGrain\(size: ([\d.]+), amount: ([\d.]+), color: ([\d.]+)\)", block)
    if m:
        out["grain"] = (float(m.group(1)), float(m.group(2)), float(m.group(3)))
    return out
