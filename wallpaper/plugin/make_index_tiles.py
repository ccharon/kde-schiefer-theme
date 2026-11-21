#!/usr/bin/env python3
"""Generates the index tiles of the backdrop plugin from ../tiles/*.png.

The patterns from make_patterns.py only use levels of the RAMP palette (six tones of
slate blue, dark -> light). The plugin recolors them per desktop at runtime, so each
index tile stores the level as the gray value i*51 (0, 51, ..., 255) instead of the color.
There is also "flach" (solid, only level 2 = base color).

    python3 -I make_index_tiles.py      -> package/contents/patterns/*.png
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True   # keep wallpaper/ clean
sys.path.insert(0, os.path.dirname(HERE))
from make_patterns import RAMP, BASE  # noqa: E402

SRC = os.path.join(os.path.dirname(HERE), "tiles")
OUT = os.path.join(HERE, "package", "contents", "patterns")
os.makedirs(OUT, exist_ok=True)

lut = {tuple(int(v) for v in c): i for i, c in enumerate(RAMP)}
for name in sorted(os.listdir(SRC)):
    if not name.endswith(".png"):
        continue
    rgb = np.asarray(Image.open(os.path.join(SRC, name)).convert("RGB"))
    idx = np.zeros(rgb.shape[:2], np.uint8)
    for y in range(rgb.shape[0]):
        for x in range(rgb.shape[1]):
            c = tuple(int(v) for v in rgb[y, x])
            if c not in lut:
                sys.exit(f"{name}: color {c} at ({x},{y}) is not in the RAMP palette")
            idx[y, x] = lut[c]
    Image.fromarray(idx * 51, "L").save(os.path.join(OUT, name), optimize=True)
    print(os.path.join(OUT, name))
Image.fromarray(np.full((8, 8), BASE * 51, np.uint8), "L").save(os.path.join(OUT, "flach.png"))
print(os.path.join(OUT, "flach.png"))
# Levels relative to the base color; must match RAMP_DELTA in contents/ui/Palette.js
print("RAMP_DELTA =", [[int(a) - int(b) for a, b in zip(c, RAMP[BASE])] for c in RAMP])
