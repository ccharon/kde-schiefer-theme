#!/usr/bin/env python3
"""Boot screen (Plymouth script theme) in the style of a workstation PROM console.

   python3 plymouth/make_plymouth.py      -> plymouth/schiefer/ (schiefer.script.in, schiefer.plymouth)
                                             plymouth/palettes/<palette>/ (images, palette.script)

Plymouth 22 cannot draw text inside the initramfs (the label plugin and the fonts are not copied
there), so the text comes from glyph atlases rendered here: Noto Sans Mono for the log and Noto Sans
Bold for the host name, each in five sizes for UI scale 1, 1.5, 2, 2.5 and 3. The script crops single glyphs
from the atlas. The machine details are filled in later by schiefer-plymouth-info (see README).

Every palette in colors/ gets its own image set with the roles of the login screens
(schiefercolors.login_roles). schiefer-plymouth-info copies the set of the system palette
(/etc/schiefer/palette) into the image directory of the theme.
"""
import os
import sys
import subprocess
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
THEME = os.path.join(HERE, "schiefer")
PALETTES = os.path.join(HERE, "palettes")
COLORS = os.path.join(ROOT, "colors")
sys.path.insert(0, os.path.join(ROOT, "common"))
import schiefercolors as sc  # noqa: E402

FONT_DIRS = ["/usr/share/fonts/noto", "/usr/share/fonts/google-noto", "/usr/share/fonts/truetype/noto"]
SCALES = (1, 1.5, 2, 2.5, 3)   # file suffix "%g"; the script takes it from a string table
MONO_PX = 14          # log and header lines at scale 1
HOST_PX = 26          # host name at scale 1
EMBLEM_PX = 64        # emblem tile at scale 1

# glyphs: printable ASCII plus what host names, os-release, prompts and the German texts need
CHARS = [chr(c) for c in range(32, 127)] + list("ÄÖÜäöüßéèêàâçñóôíúÉ·…•°±×µ")


def font_path(name):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    sys.exit(f"font {name} not found in {FONT_DIRS}")


def mix(a, b, t):
    """Qt.tint: a covered by b with alpha t."""
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


SLATE = (20, 26, 41)                       # rgba(0.08, 0.10, 0.16) of the clock field (SevenSeg.qml)


def solid(out, name, rgb):
    Image.new("RGBA", (1, 1), rgb + (255,)).save(os.path.join(out, name + ".png"))


def atlas(out, name, ttf, px, color, mono):
    """One row of glyph cells. Returns (cell x list, cell width list, advance list, height)."""
    font = ImageFont.truetype(ttf, px)
    asc, desc = font.getmetrics()
    h = asc + desc
    xs, ws, advs = [], [], []
    x = 0
    for ch in CHARS:
        adv = round(font.getlength(ch))
        box = font.getbbox(ch)
        w = max(adv, box[2]) + (0 if mono else 1)
        xs.append(x); ws.append(w); advs.append(adv)
        x += w
    img = Image.new("RGBA", (x, h), (0, 0, 0, 0))
    mask = Image.new("L", (x, h), 0)
    d = ImageDraw.Draw(mask)
    for ch, cx in zip(CHARS, xs):
        d.text((cx, 0), ch, font=font, fill=255)
    img.paste(Image.new("RGBA", (x, h), color + (255,)), (0, 0), mask)
    img.save(os.path.join(out, name + ".png"), optimize=True)
    return xs, ws, advs, h


def script_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_emblems(out, roles):
    for k in SCALES:
        png = os.path.join(out, f"emblem-{k:g}.png")
        r = subprocess.run(["qml6", "-platform", "offscreen", os.path.join(HERE, "render_emblem.qml"),
                            "--", png, str(round(EMBLEM_PX * k)), sc.hexcolor(roles["bg"]),
                            sc.hexcolor(roles["active"])], capture_output=True, text=True, timeout=60)
        if r.returncode != 0 or not os.path.exists(png):
            sys.exit(f"emblem rendering failed: {r.stderr}")


def screen_color(roles):
    """Boot screen background, darker than the clock field."""
    return mix(roles["bg"], SLATE, 0.86)


def render_palette(short, roles, mono, bold):
    """Image set of one palette; returns the glyph tables (the same for every palette)."""
    out = os.path.join(PALETTES, short)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        os.remove(os.path.join(out, f))
    dialog, field, active, ink = roles["bg"], roles["field"], roles["active"], roles["fg"]
    screen = screen_color(roles)
    trough = mix(dialog, SLATE, 0.93)                                  # sunken progress trough
    lit = mix(mix(dialog, (255, 255, 255), 0.8), active, 0.2)          # lit segments of the clock

    tables = []
    for k in SCALES:
        for name, ttf, px, color, is_mono in (
                (f"mono-lit-{k:g}", mono, round(MONO_PX * k), lit, True),
                (f"mono-dark-{k:g}", mono, round(MONO_PX * k), ink, True),
                (f"host-{k:g}", bold, round(HOST_PX * k), ink, False)):
            xs, ws, advs, h = atlas(out, name, ttf, px, color, is_mono)
            tables.append(f'MakeFont({script_string(name)}, {h}, '
                          f'[{", ".join(map(str, xs))}], [{", ".join(map(str, ws))}], '
                          f'[{", ".join(map(str, advs))}]);')
    render_emblems(out, roles)

    panel = sc.motif_colors(dialog)
    bar = sc.motif_colors(active)
    edges = sc.motif_colors(screen)
    for name, rgb in (("panel", dialog), ("panel-top", panel["top"]), ("panel-bottom", panel["bottom"]),
                      ("field", field), ("trough", trough), ("trough-top", edges["top"]),
                      ("trough-bottom", edges["bottom"]), ("bar", active), ("bar-top", bar["top"]),
                      ("bar-bottom", bar["bottom"]), ("lit", lit), ("ink", ink)):
        solid(out, name, rgb)
    with open(os.path.join(out, "palette.script"), "w") as f:
        f.write("screen_r = %.4f; screen_g = %.4f; screen_b = %.4f;\n" % tuple(c / 255 for c in screen))
    print(f"{out}: {len(os.listdir(out))} files, screen {sc.hexcolor(screen)}, text {sc.hexcolor(lit)}")
    return tables


def main():
    os.makedirs(THEME, exist_ok=True)
    mono = font_path("NotoSansMono-Regular.ttf")
    bold = font_path("NotoSans-Bold.ttf")

    tables = None
    for fn in sorted(os.listdir(COLORS)):
        if not (fn.startswith("Schiefer") and fn.endswith(".colors")):
            continue
        short = (fn[len("Schiefer"):-len(".colors")] or "Schiefer").lower()
        tables = render_palette(short, sc.login_roles(os.path.join(COLORS, fn)), mono, bold)
    schiefer = screen_color(sc.login_roles(os.path.join(COLORS, "Schiefer.colors")))

    chars = ", ".join(script_string(c) for c in CHARS)
    with open(os.path.join(HERE, "schiefer.script.tmpl")) as f:
        code = f.read()
    code = (code.replace("@CHARS@", chars)
                .replace("@FONTS@", "\n".join(tables))
                .replace("@SCALES@", ", ".join(f"{k:g}" for k in SCALES))
                .replace("@SCALE_NAMES@", ", ".join(script_string(f"{k:g}") for k in SCALES))
                .replace("@SCREEN@", "screen_r = %.4f; screen_g = %.4f; screen_b = %.4f;"
                         % tuple(c / 255 for c in schiefer))
                .replace("@EMBLEM_PX@", str(EMBLEM_PX)))
    with open(os.path.join(THEME, "schiefer.script.in"), "w") as f:
        f.write(code)
    with open(os.path.join(THEME, "schiefer.plymouth"), "w") as f:
        f.write("[Plymouth Theme]\n"
                "Name=Schiefer\n"
                "Description=Workstation console: machine banner, systemd units as they start, progress\n"
                "ModuleName=script\n\n"
                "[script]\n"
                "# images of the system palette and the script with the machine details, both written by\n"
                "# schiefer-plymouth-info (dracut module 90schiefer-plymouth)\n"
                "ImageDir=/var/lib/schiefer/plymouth/images\n"
                "ScriptFile=/var/lib/schiefer/plymouth/schiefer.script\n")


if __name__ == "__main__":
    main()
