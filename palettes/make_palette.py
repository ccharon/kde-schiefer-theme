#!/usr/bin/env python3
"""Generates KDE color schemes (colors/*.colors) from CDE-like palettes (palettes/*.toml).

    python3 palettes/make_palette.py              all palettes -> colors/
    python3 palettes/make_palette.py --out DIR    other output directory
    python3 palettes/make_palette.py --check      print figures only (brightness, Motif branch, edges)

Like CDE a palette has eight color sets; every other color is derived with the Motif formula
(common/schiefercolors.py). Roles and their KDE mapping:

  1  active frame/title      [WM] active*, [Colors:Selection], focus/hover decoration
  2  inactive frame/title    [WM] inactive*
  3  desktop 1               [Schiefer] DesktopColors (buttons of the dock console)
  4  desktop 2               [Schiefer] DesktopColors
  5  text and list areas     [Colors:View]
  6  main windows            [Colors:Window]
  7  dialogs/controls        [Colors:Button] (KDE has no dialog color; buttons, combo boxes
                             and tool buttons carry the dialog color)
  8  front panel             [Colors:Complementary], [Schiefer] FrontPanel

Rules: light palettes need qGray(window) >= 192, dark ones < 192, otherwise GTK and Firefox pick
the wrong variant. No [Colors:Header] group, so GTK header bars take the title color from [WM].
All surfaces should lie in the medium Motif branch (brightness 20 ... 93 %), because the GTK and
Plasma styles can only approximate the formula there. --check warns otherwise.
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
    1: "active frame", 2: "inactive frame", 3: "desktop 1", 4: "desktop 2",
    5: "text area", 6: "main window", 7: "dialogs/buttons", 8: "front panel",
}

# Accent colors for text (links, states), chosen by the brightness of the surface
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
        raise SystemExit(f"{path}: missing color sets: {missing}")
    d["cde"] = cde
    d.setdefault("id", os.path.splitext(os.path.basename(path))[0])
    return d


def ref(p, spec):
    """'3' -> color set 3, otherwise a color."""
    s = str(spec).strip()
    return p["cde"][int(s)] if s.isdigit() else sc.parse(s)


def colorset(bg, focus, hover, fg=None, accents=None):
    """One KDE color group from a surface (Motif: foreground, select color)."""
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
    # Focus frame: Motif select color of the active color (a little stronger than the title bar)
    focus = ma["select"] if ma["fg"] == (255, 255, 255) else ma["bottom"]
    hover = active
    groups = {}
    groups["Colors:Window"] = colorset(window, focus, hover)
    groups["Colors:View"] = colorset(view, focus, hover)
    groups["Colors:Button"] = colorset(button, focus, hover)
    tooltip = ref(p, p.get("schiefer", {}).get("tooltip", "5"))
    groups["Colors:Tooltip"] = colorset(tooltip, focus, hover)
    groups["Colors:Complementary"] = colorset(panel, ma["top"], ma["top"])
    # Selection = active color (like the title bar); foreground after Motif
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
        f"# {p.get('name', pid)}: {p.get('comment', '')}".rstrip(" :"),
        f"# Generated by palettes/make_palette.py from palettes/{src_name}. Do not edit.",
        "# Derived with the Motif formula (common/schiefercolors.py, Motif 2.3.8 lib/Xm/Color.c, LGPL-2.1+).",
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
    if "name_de" in p:
        gen["Name[de]"] = p["name_de"]
    gen["shadeSortColumn"] = "true"
    section("General", gen)
    section("KDE", {"contrast": "6"})
    # Own group: KDE does not copy it to kdeglobals when applying the scheme, so the dock reads it
    # from the .colors file of the active scheme ([General] ColorScheme in kdeglobals).
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
    print(f"{p['id']} ({p.get('name', '')}), {variant}, qGray(window)={gray}")
    if variant == "light" and gray < 192 or variant == "dark" and gray >= 192:
        print(f"  ERROR: qGray(window)={gray} does not match variant={variant} (threshold 192)")
        ok = False
    for i in range(1, 9):
        m = sc.motif_colors(c[i])
        b = sc.brightness(c[i])
        warn = "" if m["model"] == "medium" else "   WARNING: not in the medium Motif branch"
        print(f"  {i} {ROLES[i]:<16} {sc.hexcolor(c[i])}  brightness {b:5.1%}  fg {sc.hexcolor(m['fg'])}  "
              f"top {sc.hexcolor(m['top'])}  bottom {sc.hexcolor(m['bottom'])}  select {sc.hexcolor(m['select'])}{warn}")
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
