"""The fixtures' orange (200, 120, 40) through a camera's table, as `ColorCubeTests.everyFittedCameraShipsItsTable`
pins it: the same trilinear interpolation `tools/lut.py` and `ColorCube.apply` use.

    venv/bin/python -I tools/cube_fixture.py <id> [<id> ...]
"""
import sys
import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from lut import evaluate, read_cube  # noqa: E402

for cam in sys.argv[1:]:
    cube, size = read_cube(f"Retrosnap/Resources/Looks/{cam}.cube")
    out = evaluate(cube, size, np.array([[200, 120, 40]]) / 255)[0] * 255
    print(f"        (.{cam}, {out[0]:.1f}, {out[1]:.1f}, {out[2]:.1f}),")
