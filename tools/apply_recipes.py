"""Put the refitted recipes into the app: for each camera, the `CameraLook` block `refine.py` had `recipe.py` print
(`ref/pairs/refine/<id>-recipe.txt`) replaces the camera's case in `CameraLook.swift` (its frame, stamp and case
name kept from the old block, its comment rewritten with the new numbers), the table `lut.py` wrote goes to
`Resources/Looks/<id>.cube`, and the tests that pin recipe numbers are re-pinned from the files
(`ColorCubeTests`, `LookRendererTests`, `LookRenderModelTests`, `LookUniformsTests`).

    venv/bin/python -I tools/apply_recipes.py <id> [...] [--grain <id>=size,amount,color ...]

`--grain` overrides a camera's grain (the ratios `grain.py` measured after the shader's weight changed say by how
much). A camera without a recipe file is left alone.
"""
import json
import os
import re
import shutil
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lut import evaluate, read_cube  # noqa: E402
from pairs import NAMES  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
R = os.path.join(ROOT, "ref", "pairs")
SWIFT = os.path.join(ROOT, "Retrosnap", "DesignSystem", "Look", "CameraLook.swift")
CASES = {"inst": "instant"}


def old_block(source, case):
    start = source.index(f"        case .{case}:\n")
    end = source.find("\n        case .", start + 1)
    closing = source.index("\n        }\n    }", start)
    if end < 0 or closing < end:  # the last case of the switch
        end = closing
    # A comment between two cases (a batch's header) belongs to the source, not to the block before it.
    close = source.rindex("\n            )", start, end) + len("\n            )")
    return start, close, source[start:close]


def main(argv):
    grains = {}
    cams = []
    i = 0
    while i < len(argv):
        if argv[i] == "--grain":
            name, _, value = argv[i + 1].rpartition("=")
            grains[name] = value; i += 2
        else:
            cams.append(argv[i]); i += 1
    source = open(SWIFT).read()
    pins = {}
    for cam in cams:
        path = os.path.join(R, "refine", cam + "-recipe.txt")
        if not os.path.exists(path):
            print(f"{cam}: no recipe yet"); continue
        block = open(path).read().rstrip("\n")
        case = CASES.get(cam, cam)
        start, end, old = old_block(source, case)
        frame = re.search(r"frame: (\.\w+)", old).group(1)
        stamp = re.search(r"stamp: (\.\w+)", old)
        block = block.replace(f"case .{cam}:", f"case .{case}:")
        block = block.replace("frame: ?", f"frame: {frame}")
        if stamp and "stamp:" not in block:  # the initializer's order: blurRadius, vignette, stamp
            block = re.sub(r"(vignette: [\d.]+)", rf"\1, stamp: {stamp.group(1)}", block, count=1)
        if cam in grains:
            size, amount, color = grains[cam].split(",")
            block = re.sub(r"filmGrain: FilmGrain\(size: [\d.]+, amount: [\d.]+, color: [\d.]+\)",
                           f"filmGrain: FilmGrain(size: {float(size):g}, amount: {float(amount):g}, color: {float(color):g})", block)
        # The comment: the refit's numbers.
        fit = json.load(open(os.path.join(R, cam + ".json")))
        lut = json.load(open(os.path.join(R, cam + "-lut.json")))
        refine = json.load(open(os.path.join(R, "refine", cam + "-refine.json")))
        fits = ", ".join(f"{p['deltaE_median']:.1f}" for p in fit["pairs"])
        tables = ", ".join(f"{p['deltaE_median']:.1f}" for p in lut["pairs"])
        setting = f"--reg {fit['reg']:g}" + (f" --hue-reg {fit['hue_reg']:g}" if fit.get("hue_reg", 1) != 1 else "")
        comment = (f"            // {NAMES[cam]}: refitted 13 October 2026 on its {len(fit['pairs'])} pictures ({setting}: {fits}); the table "
                   f"(prior {lut['prior']:g}, smooth {lut['smooth']:g}, skin {lut['skin']:g}) {tables}; held-out median gap {refine['loo_median_gap']:+.2f}.")
        block = re.sub(r"            // .*\n", comment + "\n", block, count=1)
        source = source[:start] + block + source[end:]
        shutil.copy(os.path.join(R, cam + ".cube"), os.path.join(ROOT, "Retrosnap", "Resources", "Looks", cam + ".cube"))
        cube, size = read_cube(os.path.join(R, cam + ".cube"))
        pins[cam] = evaluate(cube, size, np.array([[200, 120, 40]]) / 255)[0] * 255
        print(f"{cam}: recipe applied, table copied; fixture orange -> {pins[cam].round(1).tolist()}")
    open(SWIFT, "w").write(source)
    # Test pins.
    p = os.path.join(ROOT, "RetrosnapTests", "DesignSystem", "ColorCubeTests.swift")
    t = open(p).read()
    for cam, rgb in pins.items():
        t = re.sub(rf"\((CameraStyle)?\.{CASES.get(cam, cam)}, [\d.]+, [\d.]+, [\d.]+\)", lambda m: f"({m.group(1) or ''}.{CASES.get(cam, cam)}, {rgb[0]:.1f}, {rgb[1]:.1f}, {rgb[2]:.1f})", t)
    open(p, "w").write(t)
    p = os.path.join(ROOT, "RetrosnapTests", "DesignSystem", "LookRendererTests.swift")
    t = open(p).read()
    for cam in ("tlr", "negative"):
        if cam in pins:
            rgb = pins[cam]
            t = re.sub(rf"let {cam} = renderer.render\(orange, model: model\(\.{cam}, noGrain\), scale: 1\)\n        #expect\(centre\({cam}\).isClose\(to: Pixel\(red: \d+, green: \d+, blue: \d+\)",
                       f"let {cam} = renderer.render(orange, model: model(.{cam}, noGrain), scale: 1)\n        #expect(centre({cam}).isClose(to: Pixel(red: {round(rgb[0])}, green: {round(rgb[1])}, blue: {round(rgb[2])})", t)
    open(p, "w").write(t)
    if "negative" in pins:
        fit = json.load(open(os.path.join(R, "negative.json")))
        refine = json.load(open(os.path.join(R, "refine", "negative-refine.json")))
        t_, r_, a_, tint = refine["halation"]
        p = os.path.join(ROOT, "RetrosnapTests", "DesignSystem", "LookRenderModelTests.swift")
        t = open(p).read()
        # Only the fitted camera's own test: the other tests pin other cameras' vignettes.
        a = t.index("@Test func aFittedCameraDrawsItsColourStageInsteadOfAFilterChain()")
        b = t.index("@Test func", a + 1)
        body = t[a:b]
        body = re.sub(r"#expect\(isClose\(m\.color\?\.matrix\[0\]\[0\] \?\? 0, -?[\d.]+\)\)", f"#expect(isClose(m.color?.matrix[0][0] ?? 0, {fit['matrix'][0][0]:.4f}))", body)
        body = re.sub(r"#expect\(isClose\(m\.vignetteOpacity, [\d.]+\)\)", f"#expect(isClose(m.vignetteOpacity, {fit['vignette']:.3f}))", body)
        body = re.sub(r"#expect\(m\.halation\?\.radius == [\d.]+\)", f"#expect(m.halation?.radius == {r_:g})", body)
        body = re.sub(r"#expect\(m\.halation\?\.tintHex == 0x[0-9A-F]+\)", f"#expect(m.halation?.tintHex == {dict(white='0xFFFFFF', cool='0xE0F0FF', warm='0xFF8A50')[tint]})", body)
        t = t[:a] + body + t[b:]
        open(p, "w").write(t)
        p = os.path.join(ROOT, "RetrosnapTests", "DesignSystem", "LookUniformsTests.swift")
        t = open(p).read()
        source = open(SWIFT).read()
        _, _, block = old_block(source, "negative")
        g = re.search(r"FilmGrain\(size: ([\d.]+), amount: ([\d.]+), color: ([\d.]+)\)", block)
        t = re.sub(r"#expect\(isClose\(negative\.filmGrain\.x, [\d.]+\)\)\n        #expect\(isClose\(negative\.filmGrain\.y, [\d.]+\)\)\n        #expect\(isClose\(negative\.filmGrain\.z, [\d.]+\)\)",
                   f"#expect(isClose(negative.filmGrain.x, {g.group(1)}))\n        #expect(isClose(negative.filmGrain.y, {g.group(2)}))\n        #expect(isClose(negative.filmGrain.z, {g.group(3)}))", t)
        t = re.sub(r"#expect\(isClose\(negative\.halation\.x, [\d.]+\)\)\n        #expect\(isClose\(negative\.halation\.y, [\d.]+\)\)", f"#expect(isClose(negative.halation.x, {t_:g}))\n        #expect(isClose(negative.halation.y, {a_:g}))", t)
        t = re.sub(r"#expect\(isClose\(stage\[0\]\.x, -?[\d.]+\)\)", f"#expect(isClose(stage[0].x, {fit['matrix'][0][0]:.4f}))", t)
        t = re.sub(r"#expect\(isClose\(stage\[0\]\.w, -?[\d.]+\)\)", f"#expect(isClose(stage[0].w, {fit['offset'][0]:.4f}))", t)
        t = re.sub(r"#expect\(isClose\(stage\[2\]\.z, -?[\d.]+\)\)", f"#expect(isClose(stage[2].z, {fit['matrix'][2][2]:.4f}))", t)
        tint_rgb = {"white": (1, 1, 1), "cool": (0.878, 0.941, 1), "warm": (1, 0.541, 0.314)}[tint]
        t = re.sub(r"#expect\(isClose\(negative\.halationTint\.x, [\d.]+\)\)\n        #expect\(isClose\(negative\.halationTint\.y, [\d.]+\)\)", f"#expect(isClose(negative.halationTint.x, {tint_rgb[0]:g}))\n        #expect(isClose(negative.halationTint.y, {tint_rgb[1]:g}))", t)
        if "plastic35" in pins:
            pr = json.load(open(os.path.join(R, "refine", "plastic35-refine.json")))
            t = re.sub(r"#expect\(isClose\(plastic\.halation\.x, [\d.]+\)\)\n        #expect\(isClose\(plastic\.halation\.y, [\d.]+\)\)", f"#expect(isClose(plastic.halation.x, {pr['halation'][0]:g}))\n        #expect(isClose(plastic.halation.y, {pr['halation'][2]:g}))", t)
        open(p, "w").write(t)
    print("tests re-pinned")


if __name__ == "__main__":
    main(sys.argv[1:])
