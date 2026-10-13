"""Print a camera's `CameraLook` recipe block for `CameraLook.swift` from what the calibration loop measured: the
joint colour fit (`ref/pairs/<id>.json`), its table (`<id>-lut.json`), the halation, the blur and the grain.

    venv/bin/python -I tools/recipe.py <id> --frame .fullFrame [--stamp .dateSegments] [--halation t,r,a,tint]
                                        [--blur r] [--grain size,amount,color] [--name "D Classic"] [--case instant]

`--case` is the `CameraStyle` case when it differs from the id (`inst` is `.instant`).

The colour stage is `tools/transcribe.py`'s literal; the comment carries each pair's median ΔE2000 of the fit and
of the table, so the recipe says what it was measured against.
"""
import json
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from transcribe import row  # noqa: E402

HEX = {"white": "0xFFFFFF", "cool": "0xE0F0FF", "warm": "0xFF8A50"}


def main(argv):
    cam = argv[0]
    opts = {"--frame": None, "--stamp": None, "--halation": None, "--blur": None, "--grain": None, "--name": cam, "--case": cam}
    i = 1
    while i < len(argv):
        opts[argv[i]] = argv[i + 1]
        i += 2
    fit = json.load(open(f"ref/pairs/{cam}.json"))
    try:
        lut = json.load(open(f"ref/pairs/{cam}-lut.json"))
    except FileNotFoundError:
        lut = None
    fits = " and ".join(f"{p['deltaE_median']:.1f}" for p in fit["pairs"])
    tables = " and ".join(f"{p['deltaE_median']:.1f}" for p in lut["pairs"]) if lut else "no table yet"
    lines = [f"        case .{opts['--case']}:",
             f"            // {opts['--name']}: fit --reg {fit['reg']:g} on its three pictures ({fits}); the table {tables}."]
    args = []
    if opts["--blur"]:
        args.append(f"blurRadius: {float(opts['--blur']):.2f}")
    args.append(f"vignette: {fit['vignette']:.3f}")
    if opts["--stamp"]:
        args.append(f"stamp: {opts['--stamp']}")
    lines.append("            CameraLook(")
    lines.append("                " + ", ".join(args) + ",")
    m, o, c, h = fit["matrix"], fit["offset"], fit["knots"], fit.get("hue")
    rows = [list(m[i]) + [o[i]] for i in range(3)]
    lines.append("                color: ColorStage(")
    lines.append(f"                    matrix: [{row(rows[0])}, {row(rows[1])}, {row(rows[2])}],")
    lines.append(f"                    curves: [{row(c[0])}, {row(c[1])},")
    lines.append(f"                             {row(c[2])}]" + ("," if h else ""))
    if h:
        lines.append("                    hue: HueTerms(")
        lines.append(f"                        shift: {row(h['shift'])},")
        lines.append(f"                        saturation: {row(h['saturation'])},")
        lines.append(f"                        lightness: {row(h['lightness'])}")
        lines.append("                    )")
    lines.append("                ),")
    if lut:
        lines.append(f'                colorCube: "{cam}",')
    if opts["--halation"]:
        t, r, a, tint = opts["--halation"].split(",")
        lines.append(f"                halation: Halation(threshold: {float(t):g}, radius: {float(r):g}, amount: {float(a):g}, tintHex: {HEX[tint]}),")
    if opts["--grain"]:
        size, amount, color = opts["--grain"].split(",")
        lines.append(f"                filmGrain: FilmGrain(size: {float(size):g}, amount: {float(amount):g}, color: {float(color):g}),")
    lines.append(f"                frame: {opts['--frame']}")
    lines.append("            )")
    print("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv[1:])
