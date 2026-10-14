"""Put the reference inputs into the simulator app's live library, so the real Result and Viewer screens can show
the pictures the references were made from (the same path a user's import takes).

    venv/bin/python -I tools/seed_simulator.py <camera id> "$(xcrun simctl get_app_container booted com.retrosnap.vintagecamera data)"

Then launch with `-rsLive 1 -rsScreen result -rsPhoto selfie` (or `dunes`, or `-rsScreen viewer`) and screenshot.

Writes Library/<id>.jpg (the input as it is, EXIF and profile kept), <id>-thumb.jpg, and library.json with the
seven reference pictures of `tools/pairs.py` ('selfie', 'dunes', 'sign', 'tungsten', 'backlit', 'market', 'wall'),
all posed as taken with the camera, newest first in the order the plan lists them.
"""
import json, os, shutil, subprocess, sys
from datetime import datetime, timezone
from PIL import Image, ImageOps
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import INPUTS

def seconds(iso):
    """JSONEncoder's default date: seconds since 2001-01-01 UTC."""
    return (datetime.fromisoformat(iso.replace("Z", "+00:00")) - datetime(2001, 1, 1, tzinfo=timezone.utc)).total_seconds()

cam, container = sys.argv[1], sys.argv[2]
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "photo-input")
lib = os.path.join(container, "Library", "Application Support", "Library")
os.makedirs(lib, exist_ok=True)
photos = []
for minute, (pid, file, _) in enumerate(INPUTS.values()):
    src, when = f"{R}/{file}", f"2026-10-11T16:{12 - minute:02d}:00Z"
    shutil.copy2(src, os.path.join(lib, f"{pid}.jpg"))
    im = ImageOps.exif_transpose(Image.open(src))
    w, h = im.size
    thumb = im.copy(); thumb.thumbnail((640, 640)); thumb.convert("RGB").save(os.path.join(lib, f"{pid}-thumb.jpg"), quality=85)
    photos.append({"id": pid, "image": {"file": {"full": f"{pid}.jpg", "thumbnail": f"{pid}-thumb.jpg"}}, "camera": cam,
                   "capturedAt": seconds(when), "adjustments": {"intensity": 100, "grain": 50, "warmth": 0, "exposure": 0, "contrast": 0},
                   "isCollage": False, "pixelSize": {"width": w, "height": h}})
json.dump({"version": 1, "photos": photos}, open(os.path.join(lib, "library.json"), "w"))
print("seeded", lib, [(p["id"], p["pixelSize"]) for p in photos])
