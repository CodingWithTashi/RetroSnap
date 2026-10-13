# tools

The calibration scripts for matching a camera to its reference pair. `docs/camera-lineup.md`, "Measuring a pair", says when to run which; each script's docstring says how.

| Script | Does |
|---|---|
| `refscan.py` | Scans a reference screenshot for where the picture and canvas are. |
| `refcrop.py` | Snaps a rough rectangle to the picture's edges and saves the crop; `--deskew` first turns a tilted canvas straight. |
| `fit.py` | Aligns the crop with the input photo, writes the pair to `ref/pairs`, fits the colour stage and vignette, writes the JSON and a report. With `--pair`, fits one colour stage over several pairs already aligned, each counting the same. |
| `sanity.py` | Runs a fit over a hue sweep and a grey ramp, to catch a fit that misbehaves on colours it never saw. |
| `transcribe.py` | Prints a fit as the Swift literal for `CameraLook.swift`. |
| `compare.py` | ΔE2000 of RetroSnap's render (from `ReferencePairTests`) against the reference and against the camera's fit, for the first pair or any later one. |
| `grain.py` | The grain of a pair's reference and of RetroSnap's render: amplitude by luminance, their ratio at mid grey, texture size, and the detail each keeps where the input has some (softness). |
| `screen_vs_bake.py` | A Viewer screenshot against the export of the same photo (from `BakeVersusScreenTests`). |
| `colour.py` | Shared maths: sRGB/CIELAB, ΔE2000, and the colour stage exactly as `RetroLook.metal` evaluates it. |

Python with numpy, Pillow and scipy: `python3 -m venv venv && venv/bin/pip install numpy pillow scipy` (the system `/usr/bin/python3` if Homebrew's cannot make a venv), then `venv/bin/python -I tools/<script>.py …` from the repository root. `ref/` is gitignored, so everything here works only on a machine that has the reference material.
