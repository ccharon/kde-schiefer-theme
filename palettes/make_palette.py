#!/usr/bin/env python3
"""Erzeugt KDE-Farbschemata (colors/*.colors) aus CDE-artigen Paletten (palettes/*.toml).

    python3 palettes/make_palette.py              alle Paletten -> colors/
    python3 palettes/make_palette.py --out DIR    anderer Zielordner
    python3 palettes/make_palette.py --check      nur Kennzahlen ausgeben (Helligkeit, Motif-Zweig, Kanten)

Eine Palette hat wie bei CDE acht Farbsätze; jede weitere Farbe wird mit der Motif-Formel
(common/schiefercolors.py) abgeleitet. Rollen und ihre Abbildung auf KDE:

  1  Aktivrahmen/-titel      [WM] active*, [Colors:Selection], Fokus-/Hover-Dekoration
  2  Inaktivrahmen/-titel    [WM] inactive*
  3  Arbeitsfläche 1         [Schiefer] DesktopColors (Knöpfe der Dock-Konsole)
  4  Arbeitsfläche 2         [Schiefer] DesktopColors
  5  Text- und Listenflächen [Colors:View]
  6  Hauptfenster            [Colors:Window]
  7  Dialoge/Bedienelemente  [Colors:Button] (KDE kennt keine eigene Dialogfarbe; Knöpfe,
                             Kombifelder und Werkzeugknöpfe tragen die Dialogfarbe)
  8  Frontpanel/Leiste       [Colors:Complementary], [Schiefer] FrontPanel

Regeln (siehe README): helle Paletten brauchen qGray(Fenster) >= 192, dunkle < 192 (sonst schalten
GTK/Firefox falsch um); keine [Colors:Header]-Gruppe, damit GTK-Kopfleisten die Titelfarbe aus [WM]
nehmen. Alle Flächen sollen im mittleren Motif-Zweig liegen (Helligkeit 20 … 93 %), weil GTK- und
Plasma-Stil die Formel nur dort gut nachbilden können – die Prüfung warnt sonst.
"""
import argparse
import os
import sys
import tomllib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "common"))
import schiefercolors as sc  # noqa: E402

ROLES = {
    1: "Aktivrahmen", 2: "Inaktivrahmen", 3: "Arbeitsfläche 1", 4: "Arbeitsfläche 2",
    5: "Textfläche", 6: "Hauptfenster", 7: "Dialoge/Knöpfe", 8: "Frontpanel",
}

# Akzentfarben für Text (Verweise, Zustände) – je nach Helligkeit der Fläche
ACCENTS_LIGHT = {
    "ForegroundLink": (30, 60, 150), "ForegroundVisited": (110, 50, 120),
    "ForegroundNegative": (160, 40, 40), "ForegroundNeutral": (150, 100, 0),
    "ForegroundPositive": (30, 110, 40),
}
ACCENTS_DARK = {
    "ForegroundLink": (140, 180, 255), "ForegroundVisited": (205, 160, 235),
    "ForegroundNegative": (240, 120, 120), "ForegroundNeutral": (235, 185, 80),
    "ForegroundPositive": (130, 210, 140),
}


def load(path):
    with open(path, "rb") as f:
        d = tomllib.load(f)
    cde = {int(k): sc.parse(v) for k, v in d["cde"].items()}
    missing = sorted(set(range(1, 9)) - set(cde))
    if missing:
        raise SystemExit(f"{path}: Farbsätze fehlen: {missing}")
    d["cde"] = cde
    d.setdefault("id", os.path.splitext(os.path.basename(path))[0])
    return d


def ref(p, spec):
    """'3' -> Farbsatz 3, sonst Farbe."""
    s = str(spec).strip()
    return p["cde"][int(s)] if s.isdigit() else sc.parse(s)


def colorset(bg, focus, hover, fg=None, accents=None):
    """Eine KDE-Farbgruppe aus einer Fläche (Motif: Vordergrund, Auswahlfarbe)."""
    m = sc.motif_colors(bg)
    fg = fg or m["fg"]
    dark = fg == (255, 255, 255)
    acc = accents or (ACCENTS_DARK if dark else ACCENTS_LIGHT)
    g = {
        "BackgroundNormal": bg,
        "BackgroundAlternate": sc.mix(bg, m["select"], 0.5),
        "ForegroundNormal": fg,
        "ForegroundInactive": sc.mix(fg, bg, 0.42),
        "ForegroundActive": focus if not dark else sc.motif_colors(focus)["top"],
        "DecorationFocus": focus,
        "DecorationHover": hover,
    }
    g.update(acc)
    return g


def build(p):
    c = p["cde"]
    active, inactive, view, window, button, panel = c[1], c[2], c[5], c[6], c[7], c[8]
    ma = sc.motif_colors(active)
    # Fokusrahmen: Motif-Auswahlfarbe der Aktivfarbe (etwas kräftiger als die Titelleiste)
    focus = ma["select"] if ma["fg"] == (255, 255, 255) else ma["bottom"]
    hover = active
    groups = {}
    groups["Colors:Window"] = colorset(window, focus, hover)
    groups["Colors:View"] = colorset(view, focus, hover)
    groups["Colors:Button"] = colorset(button, focus, hover)
    tooltip = ref(p, p.get("schiefer", {}).get("tooltip", "5"))
    groups["Colors:Tooltip"] = colorset(tooltip, focus, hover)
    groups["Colors:Complementary"] = colorset(panel, ma["top"], ma["top"])
    # Auswahl = Aktivfarbe (wie die Titelleiste); Vordergrund nach Motif
    sel = colorset(active, focus, hover)
    sel["ForegroundActive"] = ma["fg"]
    sel["ForegroundInactive"] = sc.mix(ma["fg"], active, 0.25)
    sel["BackgroundAlternate"] = sc.mix(active, ma["top"], 0.4)
    groups["Colors:Selection"] = sel

    mi = sc.motif_colors(inactive)
    wm = {
        "activeBackground": active, "activeBlend": active, "activeForeground": ma["fg"],
        "inactiveBackground": inactive, "inactiveBlend": inactive,
        "inactiveForeground": sc.mix(mi["fg"], inactive, 0.25),
    }
    mw = sc.motif_colors(window)
    disabled = mw["bottom"]
    desktops = [ref(p, s) for s in p.get("schiefer", {}).get("desktops", ["3", "4"])]
    return groups, wm, disabled, desktops


def write(p, out_dir, src_name):
    groups, wm, disabled, desktops = build(p)
    c = p["cde"]
    pid = p["id"]
    lines = [
        f"# {p.get('name', pid)} – {p.get('comment', '')}".rstrip(" –"),
        f"# Erzeugt von palettes/make_palette.py aus palettes/{src_name} – nicht von Hand ändern.",
        "# Ableitungen nach der Motif-Formel (common/schiefercolors.py, Motif 2.3.8 lib/Xm/Color.c, LGPL-2.1+).",
        "",
    ]

    def section(name, items):
        lines.append(f"[{name}]")
        for k in sorted(items):
            v = items[k]
            lines.append(f"{k}={sc.kde(v) if isinstance(v, tuple) else v}")
        lines.append("")

    section("ColorEffects:Disabled", {
        "Color": disabled, "ColorAmount": "0", "ColorEffect": "0", "ContrastAmount": "0.55",
        "ContrastEffect": "1", "IntensityAmount": "0.05", "IntensityEffect": "2"})
    section("ColorEffects:Inactive", {
        "ChangeSelectionColor": "true", "Color": disabled, "ColorAmount": "0.025", "ColorEffect": "2",
        "ContrastAmount": "0.1", "ContrastEffect": "2", "Enable": "false", "IntensityAmount": "0",
        "IntensityEffect": "0"})
    for g in ("Colors:Button", "Colors:Complementary", "Colors:Selection", "Colors:Tooltip",
              "Colors:View", "Colors:Window"):
        section(g, groups[g])
    gen = {"ColorScheme": pid, "Name": p.get("name", pid)}
    if "name" in p:
        gen["Name[de]"] = p["name"]
    gen["shadeSortColumn"] = "true"
    section("General", gen)
    section("KDE", {"contrast": "6"})
    # eigene Gruppe: wird von KDE beim Anwenden nicht nach kdeglobals kopiert – das Dock liest sie
    # aus der .colors-Datei des aktiven Schemas ([General] ColorScheme in kdeglobals)
    sch = {"Palette": pid, "DesktopColors": ",".join(sc.hexcolor(d) for d in desktops),
           "FrontPanel": sc.hexcolor(c[8])}
    for i in range(1, 9):
        sch[f"Color{i}"] = sc.hexcolor(c[i])
    section("Schiefer", sch)
    section("WM", wm)
    path = os.path.join(out_dir, f"{pid}.colors")
    with open(path + ".tmp", "w") as f:
        f.write("\n".join(lines))
    os.replace(path + ".tmp", path)
    return path


def check(p):
    c = p["cde"]
    ok = True
    gray = sc.qgray(c[6])
    variant = p.get("variant", "light")
    print(f"{p['id']} ({p.get('name', '')}), {variant}, qGray(Fenster)={gray}")
    if variant == "light" and gray < 192 or variant == "dark" and gray >= 192:
        print(f"  FEHLER: qGray(Fenster)={gray} passt nicht zu variant={variant} (Grenze 192)")
        ok = False
    for i in range(1, 9):
        m = sc.motif_colors(c[i])
        b = sc.brightness(c[i])
        warn = "" if m["model"] == "medium" else "   WARNUNG: nicht im mittleren Motif-Zweig"
        print(f"  {i} {ROLES[i]:<16} {sc.hexcolor(c[i])}  Helligkeit {b:5.1%}  fg {sc.hexcolor(m['fg'])}  "
              f"oben {sc.hexcolor(m['top'])}  unten {sc.hexcolor(m['bottom'])}  Auswahl {sc.hexcolor(m['select'])}{warn}")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(ROOT, "colors"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("palettes", nargs="*", help="Palettendateien (Standard: palettes/*.toml)")
    a = ap.parse_args()
    files = a.palettes or sorted(os.path.join(HERE, f) for f in os.listdir(HERE) if f.endswith(".toml"))
    ok = True
    for f in files:
        p = load(f)
        ok &= check(p)
        if not a.check:
            os.makedirs(a.out, exist_ok=True)
            print("  ->", write(p, a.out, os.path.basename(f)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
