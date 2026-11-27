#!/usr/bin/env python3
"""Twill tile in a desktop color, colored exactly like the backdrop plugin does it
(index tile + RAMP_DELTA from wallpaper/plugin/package/contents/ui/Palette.js).
   python3 greeter/make_backdrop.py '#8fa3bf' out.png [pattern]
   python3 greeter/make_backdrop.py --palettes   -> greeter/sddm/schiefer/backdrops/<palette>.png
The splash screen tile is the one of the Schiefer palette (first desktop color)."""
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "common"))
import schiefercolors as sc  # noqa: E402
RAMP_DELTA = [(-20, -23, -27), (-10, -11, -13), (0, 0, 0), (10, 11, 11), (22, 22, 21), (36, 35, 33)]

def ramp(hexcolor):
    base = [int(hexcolor.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    shift = []
    for k in range(3):
        lo, hi = base[k] + RAMP_DELTA[0][k], base[k] + RAMP_DELTA[5][k]
        shift.append(255 - hi if hi > 255 else -lo if lo < 0 else 0)
    return [tuple(base[k] + d[k] + shift[k] for k in range(3)) for d in RAMP_DELTA]

def tile(color, out, pattern="koeper"):
    idx = Image.open(os.path.join(HERE, "..", "wallpaper", "plugin", "package", "contents", "patterns", pattern + ".png")).convert("L")
    r = ramp(color)
    img = Image.new("RGB", idx.size)
    img.putdata([r[min(5, int(v / 255 * 5 + 0.5))] for v in idx.get_flattened_data()])
    img.save(out, optimize=True)

def palettes():
    """One tile per palette in the first desktop color, for the SDDM theme (schiefer-config system-palette)."""
    colors = os.path.join(HERE, "..", "colors")
    out = os.path.join(HERE, "sddm", "schiefer", "backdrops")
    os.makedirs(out, exist_ok=True)
    for fn in sorted(os.listdir(colors)):
        if fn.startswith("Schiefer") and fn.endswith(".colors"):
            short = (fn[len("Schiefer"):-len(".colors")] or "Schiefer").lower()
            tile(sc.hexcolor(sc.login_roles(os.path.join(colors, fn))["desktop"]), os.path.join(out, short + ".png"))
            print(os.path.join(out, short + ".png"))

def main():
    if sys.argv[1:] == ["--palettes"]:
        palettes()
    else:
        tile(*sys.argv[1:4])

if __name__ == "__main__":
    main()
