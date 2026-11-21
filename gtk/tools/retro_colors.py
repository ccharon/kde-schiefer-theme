#!/usr/bin/env python3
"""Vergleicht die festen GTK-Näherungen (retro.css: retro_light/_dark/_select/_title_*) je Palette
mit der exakten Motif-Formel (common/schiefercolors.py), wie sie Qt-Stil und Deko rechnen.

    python3 gtk/tools/retro_colors.py [colors/*.colors]

Ausgabe: größte Abweichung je Kanal in 8-bit-Stufen. Die Anteile liest das Skript aus
gtk/Schiefer/gtk-3.0/retro.css, damit Änderungen dort sofort geprüft werden.
"""
import configparser
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "common"))
import schiefercolors as sc  # noqa: E402

css = open(os.path.join(ROOT, "gtk/Schiefer/gtk-3.0/retro.css")).read()


def factor(name):
    m = re.search(r"@define-color %s mix\(@\w+, (white|black), ([0-9.]+)\);" % name, css)
    return m.group(1), float(m.group(2))


def gtk_mix(c, target, t):
    w = 255 if target == "white" else 0
    return tuple(int(round(x + (w - x) * t)) for x in c)


def diff(a, b):
    return max(abs(x - y) for x, y in zip(a, b))


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "colors", "*.colors")))
    rows = [("retro_light", "Colors:Window", "BackgroundNormal", "top"),
            ("retro_dark", "Colors:Window", "BackgroundNormal", "bottom"),
            ("retro_select", "Colors:Window", "BackgroundNormal", "select"),
            ("retro_title_light", "WM", "activeBackground", "top"),
            ("retro_title_dark", "WM", "activeBackground", "bottom")]
    worst = 0
    for f in files:
        cp = configparser.ConfigParser(interpolation=None, strict=False)
        cp.optionxform = str
        cp.read(f)
        out = []
        for var, grp, key, role in rows:
            bg = sc.parse(cp[grp][key])
            exact = sc.motif_colors(bg)[role]
            approx = gtk_mix(bg, *factor(var))
            d = diff(exact, approx)
            worst = max(worst, d)
            out.append(f"{var} {d}")
        # Knöpfe: GTK nimmt die Kanten von der Fensterfarbe, Qt von der Knopffarbe
        btn = sc.parse(cp["Colors:Button"]["BackgroundNormal"])
        win = sc.parse(cp["Colors:Window"]["BackgroundNormal"])
        d = max(diff(sc.motif_colors(btn)["top"], gtk_mix(win, *factor("retro_light"))),
                diff(sc.motif_colors(btn)["bottom"], gtk_mix(win, *factor("retro_dark"))))
        out.append(f"Knopfkanten {d}")
        print(f"{os.path.basename(f):<26} " + ", ".join(out))
    print(f"größte Abweichung: {worst} Stufen (von 255)")


if __name__ == "__main__":
    main()
