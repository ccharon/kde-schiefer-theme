#!/usr/bin/env python3
"""Erzeugt aus ../tiles/*.png die Index-Kacheln des Hintergrund-Plugins.

Die Muster aus make_patterns.py bestehen nur aus Stufen der Palette RAMP (sechs Töne
Schieferblau, dunkel -> hell). Das Plugin färbt sie zur Laufzeit je Arbeitsfläche neu ein;
dafür speichert jede Index-Kachel statt der Farbe die Stufe als Grauwert i*51 (0, 51, …, 255).
Zusätzlich gibt es „flach“ (einfarbig, nur Stufe 2 = Grundton).

    python3 -I make_index_tiles.py      -> package/contents/patterns/*.png
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True   # nichts in wallpaper/ ablegen
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
                sys.exit(f"{name}: Farbe {c} bei ({x},{y}) gehört nicht zur Palette RAMP")
            idx[y, x] = lut[c]
    Image.fromarray(idx * 51, "L").save(os.path.join(OUT, name), optimize=True)
    print(os.path.join(OUT, name))
Image.fromarray(np.full((8, 8), BASE * 51, np.uint8), "L").save(os.path.join(OUT, "flach.png"))
print(os.path.join(OUT, "flach.png"))
# Abstufung relativ zum Grundton – muss mit RAMP_DELTA in contents/ui/Palette.js übereinstimmen
print("RAMP_DELTA =", [[int(a) - int(b) for a, b in zip(c, RAMP[BASE])] for c in RAMP])
