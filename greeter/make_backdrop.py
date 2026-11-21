#!/usr/bin/env python3
"""Köper-Kachel in einer Arbeitsflächenfarbe, genau wie das Hintergrund-Plugin sie färbt
(Index-Kachel + RAMP_DELTA aus wallpaper/plugin/package/contents/ui/Palette.js).
   python3 greeter/make_backdrop.py '#8fa3bf' out.png [muster]
Erzeugt die mitgelieferten Kacheln für SDDM und das Startbild (Palette Schiefer, Farbsatz 3)."""
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAMP_DELTA = [(-20, -23, -27), (-10, -11, -13), (0, 0, 0), (10, 11, 11), (22, 22, 21), (36, 35, 33)]

def ramp(hexcolor):
    base = [int(hexcolor.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    shift = []
    for k in range(3):
        lo, hi = base[k] + RAMP_DELTA[0][k], base[k] + RAMP_DELTA[5][k]
        shift.append(255 - hi if hi > 255 else -lo if lo < 0 else 0)
    return [tuple(base[k] + d[k] + shift[k] for k in range(3)) for d in RAMP_DELTA]

def main():
    color, out = sys.argv[1], sys.argv[2]
    pattern = sys.argv[3] if len(sys.argv) > 3 else "koeper"
    idx = Image.open(os.path.join(HERE, "..", "wallpaper", "plugin", "package", "contents", "patterns", pattern + ".png")).convert("L")
    r = ramp(color)
    img = Image.new("RGB", idx.size)
    img.putdata([r[min(5, int(v / 255 * 5 + 0.5))] for v in idx.get_flattened_data()])
    img.save(out, optimize=True)

if __name__ == "__main__":
    main()
