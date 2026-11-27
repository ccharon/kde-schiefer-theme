#!/usr/bin/env python3
"""Konsole color schemes and profiles "Schiefer" and "Schiefer Broica", and a matching Midnight Commander skin.

   python3 konsole/make_konsole.py          -> <id>.colorscheme, <id>.profile per scheme; checks mc-schiefer.ini

Black text on the light text field color of the palette, like a dtterm. Both schemes share the skin, which
names only ANSI colors: light gray is the dialog and menu color of each palette. The script checks the WCAG
contrast of every color pair that matters, for each scheme, and fails if one is too low:
  - shell: the normal colors as text on the background; the intense colors too, because Konsole draws
    bold text (ls, grep, git) with them
  - Midnight Commander with its default skin (light gray, white, yellow and bright green on blue,
    black and white on cyan), for example when run as root without our skin
  - Midnight Commander with mc-schiefer.ini, which the profile selects through MC_SKIN, including the
    mcedit syntax colors on the dark editor background of that skin
"""
import configparser
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

class Scheme:
    def __init__(self, id, name, background, normal, intense):
        self.id, self.name, self.background, self.normal, self.intense = id, name, background, normal, intense


SCHEMES = [
    # text field color of the Schiefer palette (greeter Pal.field)
    Scheme("Schiefer", "Schiefer", (0xe2, 0xe5, 0xed), [
        (0x00, 0x00, 0x00),   # 0 black
        (0xbd, 0x2f, 0x2f),   # 1 red
        (0x2e, 0x73, 0x2e),   # 2 green
        (0x81, 0x60, 0x00),   # 3 brown / yellow
        (0x22, 0x31, 0x66),   # 4 blue: dark, so mc's default skin stays readable on it
        (0x9b, 0x40, 0x9b),   # 5 magenta
        (0x1c, 0x6f, 0x7d),   # 6 cyan: between black and white text (mc default skin)
        (0xbe, 0xc2, 0xd3),   # 7 light gray = dialog color of the palette
    ], [
        (0x55, 0x5b, 0x6b),   # 8 gray
        (0xcc, 0x56, 0x56),   # 9 bright red
        (0x33, 0x86, 0x33),   # 10 bright green
        (0x96, 0x72, 0x00),   # 11 yellow
        (0x36, 0x69, 0xcb),   # 12 bright blue (bold directories in ls)
        (0xb4, 0x59, 0xb4),   # 13 bright magenta
        (0x1f, 0x82, 0x92),   # 14 bright cyan
        (0xff, 0xff, 0xff),   # 15 white
    ]),
    # Broica: text field color of palettes/Broica.toml (CDE set 4), hues warmer and taken from the CDE
    # palette where it has one: blue from the slate of set 3, cyan from the petrol of set 6, magenta
    # from the rose of set 7
    Scheme("SchieferBroica", "Schiefer Broica", (0xeb, 0xe6, 0xe2), [
        (0x00, 0x00, 0x00),   # 0 black
        (0xbc, 0x33, 0x2c),   # 1 red
        (0x3d, 0x74, 0x2c),   # 2 green
        (0x85, 0x5e, 0x10),   # 3 brown / yellow
        (0x2a, 0x3d, 0x5c),   # 4 blue: CDE slate, dark for the mc panel cursor and mc's default skin
        (0x9e, 0x47, 0x6a),   # 5 magenta: CDE rose
        (0x22, 0x6f, 0x82),   # 6 cyan: CDE petrol, between black and white text (mc default skin)
        (0x96, 0xc5, 0xd1),   # 7 light gray: menu and dialog color of the palette (CDE set 6), a touch lighter
    ], [
        (0x5f, 0x5a, 0x57),   # 8 gray
        (0xc9, 0x4a, 0x3c),   # 9 bright red
        (0x4a, 0x82, 0x36),   # 10 bright green
        (0x94, 0x6c, 0x00),   # 11 yellow
        (0x3c, 0x68, 0xb0),   # 12 bright blue (bold directories in ls)
        (0xa8, 0x50, 0x7a),   # 13 bright magenta
        (0x23, 0x7f, 0x95),   # 14 bright cyan
        (0xff, 0xff, 0xff),   # 15 white
    ]),
]
FOREGROUND = (0x00, 0x00, 0x00)
# ANSI colors 0-7, their intense variants 8-15 and the background of the scheme being checked
NORMAL = INTENSE = BACKGROUND = None

FAINT_MIX = 0.45

# Konsole's default scheme Breeze, as reference for the mc default skin: that skin has weak pairs with
# every common palette (black on blue, yellow on cyan ...), so Schiefer only must not be worse there
BREEZE = [
    (35, 38, 39), (237, 21, 21), (17, 209, 22), (246, 116, 0), (29, 153, 243), (155, 89, 182),
    (26, 188, 156), (252, 252, 252), (127, 140, 141), (192, 57, 43), (28, 220, 154), (253, 188, 75),
    (61, 174, 233), (142, 68, 173), (22, 160, 133), (255, 255, 255),
]
BREEZE_BG, BREEZE_FG = (35, 38, 39), (252, 252, 252)            # faint colors: this much toward the background

MC_NAMES = {
    "black": 0, "red": 1, "green": 2, "brown": 3, "blue": 4, "magenta": 5, "cyan": 6, "lightgray": 7,
    "gray": 8, "brightred": 9, "brightgreen": 10, "yellow": 11, "brightblue": 12, "brightmagenta": 13,
    "brightcyan": 14, "white": 15,
}


def color(i):
    return NORMAL[i] if i < 8 else INTENSE[i - 8]


def lum(rgb):
    def ch(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mix(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


problems = []

# mc default skin pairs that stay weak: yellow highlights on cyan and red, and "special" files in black
# on blue. Yellow must stay dark, because Konsole draws bold text with the intense colors and bold
# yellow on the light background (Portage ewarn, emerge) has to remain readable; black on the dark blue
# follows from blue being dark enough for light gray text. mc-schiefer.ini avoids all of them.
KNOWN_WEAK = {
    "[core] markselect", "[error] errdhotnormal", "[error] errdtitle", "[filehighlight] special",
    "[menu] menuhot", "[popupmenu] menutitle", "[viewer] viewselected",
}


def check(label, fg, bg, need, ref=None):
    c = contrast(fg, bg)
    if ref is not None:
        need = min(need, ref)
    known = " ".join(label.split(" ")[:2]) in KNOWN_WEAK and ref is not None
    flag = "" if c >= need - 0.005 else ("   (known, see KNOWN_WEAK)" if known else "   <-- below %.2f" % need)
    print("  %-50s %5.2f%s%s" % (label, c, "" if ref is None else "  (Breeze %.2f)" % ref, flag))
    if c < need - 0.005 and not known:
        problems.append(label)


def mc_color(name, default, palette=None):
    name = name.strip()
    if name in ("", "default"):
        return default
    return palette[MC_NAMES[name]] if palette else color(MC_NAMES[name])


def check_skin(path, need, editor_need, skip_sections=(), against_breeze=False):
    """Every fg;bg pair of an mc skin; empty or "default" background = terminal background."""
    ini = configparser.ConfigParser(interpolation=None, strict=False)
    ini.optionxform = str
    with open(path) as f:
        ini.read_string(f.read())
    for sec in ini.sections():
        if sec in ("skin", "Lines", "widget-panel", "widget-editor") or sec in skip_sections:
            continue
        base = ini[sec].get("_default_", "").split(";")
        base_bg = base[1] if len(base) > 1 else ""
        for key, val in ini[sec].items():
            parts = val.split(";")
            if not parts[0].strip():
                continue
            bg = parts[1] if len(parts) > 1 and parts[1].strip() else base_bg
            if sec == "filehighlight":
                bg = core_bg
            if key in ("disabled", "inputunchanged", "menuinactive", "shadow", "editwhitespace",
                       "editrightmargin", "temp", "editnonprintable"):
                continue        # deliberately faint
            fg_rgb = mc_color(parts[0], FOREGROUND)
            bg_rgb = mc_color(bg, BACKGROUND)
            ref = None
            if against_breeze:
                ref = contrast(mc_color(parts[0], BREEZE_FG, BREEZE), mc_color(bg, BREEZE_BG, BREEZE))
            check(f"[{sec}] {key} = {val.strip()}", fg_rgb, bg_rgb, editor_need if sec == "editor" else need, ref)


def check_scheme(scheme):
    global NORMAL, INTENSE, BACKGROUND, core_bg
    NORMAL, INTENSE, BACKGROUND = scheme.normal, scheme.intense, scheme.background
    print(f"===== {scheme.name}")
    print("Shell: normal colors on the background (need 4.5)")
    for i in range(1, 7):
        check(f"color {i}", NORMAL[i], BACKGROUND, 4.5)
    check("color 8 (gray, comments)", INTENSE[0], BACKGROUND, 4.5)
    check("foreground", FOREGROUND, BACKGROUND, 7)
    print("Shell: intense colors as bold text on the background (need 3.0)")
    for i in range(9, 15):
        check(f"color {i}", INTENSE[i - 8], BACKGROUND, 3.0)

    print("Midnight Commander, default skin (need 3.0, or at least what Breeze gives)")
    core_bg = "blue"
    check_skin("/usr/share/mc/skins/default.ini", 3.0, 3.0,
               skip_sections=("editor", "diffviewer"), against_breeze=True)

    print("Midnight Commander, mc-schiefer.ini (need 4.5, editor syntax on black 3.5)")
    # mcedit syntax colors: normal colors stay dark for the light shell background, so they reach
    # about 3.6 on black; the intense ones and white/yellow, which the syntax files use most, more
    core_bg = "default"
    check_skin(os.path.join(HERE, "mc-schiefer.ini"), 4.5, 3.5)
    for name in ("yellow", "white", "cyan", "brightgreen", "brightcyan", "brightmagenta", "brightred",
                 "magenta", "red", "brown", "green", "lightgray", "brightblue"):
        check(f"mcedit syntax {name} on black", color(MC_NAMES[name]), (0, 0, 0), 3.5)


def main():
    for scheme in SCHEMES:
        check_scheme(scheme)
        write_scheme(scheme)
    if problems:
        print(f"\n{len(problems)} pair(s) below the target", file=sys.stderr)
        sys.exit(1)


def write_scheme(scheme):
    def block(name, rgb):
        return f"[{name}]\nColor={rgb[0]},{rgb[1]},{rgb[2]}\n\n"
    bg = scheme.background
    out = ""
    out += block("Background", bg)
    out += block("BackgroundFaint", bg)
    out += block("BackgroundIntense", bg)
    for i in range(8):
        out += block(f"Color{i}", scheme.normal[i])
        out += block(f"Color{i}Faint", mix(scheme.normal[i], bg, FAINT_MIX))
        out += block(f"Color{i}Intense", scheme.intense[i])
    out += block("Foreground", FOREGROUND)
    out += block("ForegroundFaint", mix(FOREGROUND, bg, FAINT_MIX))
    out += block("ForegroundIntense", FOREGROUND)
    out += ("[General]\nAnchor=0.5,0.5\nBlur=false\nColorRandomization=false\n"
            f"Description={scheme.name}\nFillStyle=Tile\nOpacity=1\nWallpaper=\nWallpaperFlipType=NoFlip\n"
            "WallpaperOpacity=1\n")
    with open(os.path.join(HERE, f"{scheme.id}.colorscheme"), "w") as f:
        f.write("# Generated by make_konsole.py\n" + out)
    # profile: dtterm-like scroll bar on the left; MC_SKIN makes Midnight Commander use mc-schiefer.ini
    with open(os.path.join(HERE, f"{scheme.id}.profile"), "w") as f:
        f.write("# Generated by make_konsole.py\n"
                f"[Appearance]\nColorScheme={scheme.id}\n"
                "Font=Noto Sans Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\n\n"
                "[General]\nEnvironment=TERM=xterm-256color,COLORTERM=truecolor,MC_SKIN=schiefer\n"
                f"Name={scheme.name}\nParent=FALLBACK/\n\n"
                "[Scrolling]\nScrollBarPosition=0\n")


if __name__ == "__main__":
    main()
