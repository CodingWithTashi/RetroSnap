# tools

The calibration scripts for matching a camera to its reference pair. `docs/camera-lineup.md`, "Measuring a pair", says when to run which; each script's docstring says how.

| Script | Does |
|---|---|
| `refscan.py` | Scans a reference screenshot for where the picture and canvas are. |
| `refcrop.py` | Snaps a rough rectangle to the picture's edges and saves the crop; `--deskew` first turns a tilted canvas straight. |
| `fit.py` | Converts the pictures to sRGB, aligns the crop with the input photo, writes the pair to `ref/pairs`, fits the colour stage (matrix, curves, per-hue terms) and vignette, writes the JSON and a report. With `--pair`, fits one colour stage over several pairs already aligned, each counting the same. |
| `sanity.py` | Runs a fit over a hue sweep and a grey ramp, to catch a fit that misbehaves on colours it never saw. |
| `transcribe.py` | Prints a fit as the Swift literal for `CameraLook.swift`. |
| `compare.py` | ΔE2000 of RetroSnap's render (from `ReferencePairTests`) against the reference and against the camera's fit (its table when it ships one, else the parametric fit), for the first pair or any later one. |
| `grain.py` | The grain of a pair's reference and of RetroSnap's render: amplitude by luminance, their ratio at mid grey, texture size, and the detail each keeps where the input has some (softness). |
| `lut.py` | Fits a camera's colour as a 3D lookup table from all its pairs at once (one sparse least-squares solve), held toward the parametric fit where the pictures showed nothing and kept smooth; writes the `.cube` the app ships. |
| `halation.py` | Fits a camera's halation from its pairs: the glow the reference spreads around highlights, found as the threshold, radius, amount and tint that best explain what the colour-only fit leaves next to bright pixels. |
| `face.py` | The selfie's face (skin-tone pixels) under a fit or RetroSnap's render against the reference: the region a viewer judges first, which whole-picture medians hide. |
| `glow_grain.py` | How coloured the grain is and what the reference adds next to highlights, for RetroSnap's renders against the references. |
| `frames.py` | RetroSnap's exports (`ReferenceExportTests`) beside the reference app's screens, canvas to canvas, and one sheet of them all for the owner. |
| `seed_simulator.py` | Puts the reference inputs into the booted simulator's live library, so `-rsLive 1 -rsScreen result -rsPhoto selfie` shows the real pictures on the real screens. |
| `shoot.sh` | Every designed scenario screenshotted from the installed app, for before/after pixel diffs. |
| `device_probe.py` | A connected phone's look-screen screenshots (from `testLookScreensAreKeptAsScreenshotsForTheDeviceProbe`) against the simulator's: whether the phone draws what the simulator draws. |
| `verify.sh` | A batch's definition of done, start to finish, on the booted simulator. |
| `screen_vs_bake.py` | A Viewer screenshot against the export of the same photo (from `BakeVersusScreenTests`). |
| `colour.py` | Shared maths: sRGB/CIELAB, ΔE2000, and the colour stage exactly as `RetroLook.metal` evaluates it (matrix, curves, hue terms), with `ColourStage.from_json` for a fit's JSON. |

Python with numpy, Pillow and scipy: `python3 -m venv venv && venv/bin/pip install numpy pillow scipy` (the system `/usr/bin/python3` if Homebrew's cannot make a venv), then `venv/bin/python -I tools/<script>.py …` from the repository root. `ref/` is gitignored, so everything here works only on a machine that has the reference material. Everything is measured in sRGB: an iPhone's photos and screenshots are Display P3 and are converted on loading.
