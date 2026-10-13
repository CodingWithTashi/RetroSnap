"""Print a fit as the Swift literal `CameraLook.swift` takes, with the vignette amount.

    venv/bin/python tools/transcribe.py ref/pairs/<id>.json [...]
"""
import json
import math
import sys


def row(values, digits=4):
    return "[" + ", ".join(f"{v:.{digits}f}" for v in values) + "]"


def main(paths):
    for path in paths:
        d = json.load(open(path))
        rows = [m + [o] for m, o in zip(d["matrix"], d["offset"])]
        pairs = d.get("pairs", [])
        if len(pairs) > 1:
            numbers = ", ".join(f"{p['name']} {p['deltaE_median']:.2f}" for p in pairs)
            print(f"// {d['camera']}: median ΔE2000 {numbers} (fit --reg {d.get('reg', 0.02):g} on both)")
        else:
            print(f"// {d['camera']}: median ΔE2000 {d['deltaE_median']:.2f}, p95 {d['deltaE_p95']:.2f}")
        print(f"vignette: {d['vignette']:.3f},")
        print("color: ColorStage(")
        print(f"    matrix: [{row(rows[0])}, {row(rows[1])}, {row(rows[2])}],")
        print(f"    curves: [{row(d['knots'][0])}, {row(d['knots'][1])},")
        print(f"             {row(d['knots'][2])}]" + ("," if d.get("hue") else ""))
        if d.get("hue"):
            hue = d["hue"]
            print(f"    hue: HueTerms(shift: {row(hue['shift'])},")
            print(f"                  saturation: {row(hue['saturation'])},")
            print(f"                  lightness: {row(hue['lightness'])})")
            print("    // shift in degrees: " + " ".join(f"{math.degrees(v):+.1f}" for v in hue["shift"]))
        print("),")


if __name__ == "__main__":
    main(sys.argv[1:])
