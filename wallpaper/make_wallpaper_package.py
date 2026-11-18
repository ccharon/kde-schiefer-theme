#!/usr/bin/env python3
"""Erzeugt ein Plasma-Hintergrundpaket „Schiefer“ (Köper-Muster) mit Bildern in gängigen Auflösungen.

    python3 make_wallpaper_package.py ZIELORDNER [muster]

Plasma 6 kann nicht kacheln und lädt Bilder immer auf Bildschirmgröße skaliert. Ein Paket mit
contents/images/BxH.png lässt Plasma die passende Auflösung wählen – bei exakter Größe pixelgenau.
Für ungewöhnliche Auflösungen gibt es schiefer-wallpaper (apply.sh).
"""
import json
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SIZES = ["1280x800", "1366x768", "1440x900", "1600x900", "1680x1050", "1920x1080", "1920x1200",
         "2560x1080", "2560x1440", "2560x1600", "2880x1800", "3440x1440", "3840x1600", "3840x2160",
         "5120x1440", "5120x2160", "5120x2880",
         # Apple-Geräte (Asahi): MacBook Air M1/M2/M3 13"/15", MacBook Pro 14"/16"
         "2560x1600", "2560x1664", "2880x1864", "3024x1964", "3456x2234"]
SIZES = sorted(set(SIZES), key=lambda s: tuple(map(int, s.split("x"))))


def main():
    dest = os.path.abspath(sys.argv[1])
    pattern = sys.argv[2] if len(sys.argv) > 2 else "koeper"
    tile = Image.open(os.path.join(HERE, "tiles", pattern + ".png")).convert("RGB")
    img_dir = os.path.join(dest, "contents", "images")
    os.makedirs(img_dir, exist_ok=True)
    for size in SIZES:
        w, h = map(int, size.split("x"))
        im = Image.new("RGB", (w, h))
        for y in range(0, h, tile.height):
            for x in range(0, w, tile.width):
                im.paste(tile, (x, y))
        im.save(os.path.join(img_dir, size + ".png"), optimize=True)
        if size == "1920x1080":
            im.crop((0, 0, 400, 250)).save(os.path.join(dest, "contents", "screenshot.png"))
    meta = {"KPlugin": {"Authors": [{"Name": "Schiefer"}], "Id": "Schiefer", "License": "GPL-2.0-or-later",
                        "Name": "Schiefer (Köper)", "Description": "Ruhiges Webmuster im Schiefer-Blau"}}
    with open(os.path.join(dest, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=4, ensure_ascii=False)
    print(dest)


if __name__ == "__main__":
    main()
