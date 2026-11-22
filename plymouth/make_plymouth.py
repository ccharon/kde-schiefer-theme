#!/usr/bin/env python3
"""Boot screen (Plymouth script theme) in the style of a workstation PROM console.

   python3 plymouth/make_plymouth.py      -> plymouth/schiefer/ (images, schiefer.script.in, schiefer.plymouth)

Plymouth 22 cannot draw text inside the initramfs (the label plugin and the fonts are not copied
there), so the text comes from glyph atlases rendered here: Noto Sans Mono for the log and Noto Sans
Bold for the host name, each in three sizes for UI scale 1, 2 and 3. The script crops single glyphs
from the atlas. The machine details are filled in later by schiefer-plymouth-info (see README).
"""
import os
import sys
import subprocess
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, "schiefer")
sys.path.insert(0, os.path.join(ROOT, "common"))
import schiefercolors as sc  # noqa: E402

FONT_DIRS = ["/usr/share/fonts/noto", "/usr/share/fonts/google-noto", "/usr/share/fonts/truetype/noto"]
SCALES = (1, 2, 3)
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


# Schiefer palette (same values as greeter/kit/Pal.qml and SevenSeg.qml)
DIALOG = (0xbe, 0xc2, 0xd3)
FIELD = (0xe2, 0xe5, 0xed)
ACTIVE = (0x60, 0x72, 0x9e)
SLATE = (20, 26, 41)                       # rgba(0.08, 0.10, 0.16) of the clock field
SCREEN = mix(DIALOG, SLATE, 0.86)          # boot screen background, darker than the clock field
TROUGH = mix(DIALOG, SLATE, 0.93)          # sunken progress trough
LIT = mix(mix(DIALOG, (255, 255, 255), 0.8), ACTIVE, 0.2)   # lit segments of the clock
BLACK = (0, 0, 0)


def solid(name, rgb):
    Image.new("RGBA", (1, 1), rgb + (255,)).save(os.path.join(OUT, name + ".png"))


def atlas(name, ttf, px, color, mono):
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
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    return xs, ws, advs, h


def script_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_emblems():
    for k in SCALES:
        out = os.path.join(OUT, f"emblem-{k}.png")
        r = subprocess.run(["qml6", "-platform", "offscreen", os.path.join(HERE, "render_emblem.qml"),
                            "--", out, str(EMBLEM_PX * k)], capture_output=True, text=True, timeout=60)
        if r.returncode != 0 or not os.path.exists(out):
            sys.exit(f"emblem rendering failed: {r.stderr}")


def main():
    os.makedirs(OUT, exist_ok=True)
    mono = font_path("NotoSansMono-Regular.ttf")
    bold = font_path("NotoSans-Bold.ttf")

    tables = []
    for k in SCALES:
        for name, ttf, px, color, is_mono in (
                (f"mono-lit-{k}", mono, MONO_PX * k, LIT, True),
                (f"mono-dark-{k}", mono, MONO_PX * k, BLACK, True),
                (f"host-{k}", bold, HOST_PX * k, BLACK, False)):
            xs, ws, advs, h = atlas(name, ttf, px, color, is_mono)
            tables.append(f'MakeFont({script_string(name)}, {h}, '
                          f'[{", ".join(map(str, xs))}], [{", ".join(map(str, ws))}], '
                          f'[{", ".join(map(str, advs))}]);')
    render_emblems()

    panel = sc.motif_colors(DIALOG)
    bar = sc.motif_colors(ACTIVE)
    screen = sc.motif_colors(SCREEN)
    for name, rgb in (("panel", DIALOG), ("panel-top", panel["top"]), ("panel-bottom", panel["bottom"]),
                      ("field", FIELD), ("trough", TROUGH), ("trough-top", screen["top"]),
                      ("trough-bottom", screen["bottom"]), ("bar", ACTIVE), ("bar-top", bar["top"]),
                      ("bar-bottom", bar["bottom"]), ("lit", LIT), ("ink", BLACK)):
        solid(name, rgb)

    chars = ", ".join(script_string(c) for c in CHARS)
    with open(os.path.join(HERE, "schiefer.script.tmpl")) as f:
        code = f.read()
    code = (code.replace("@CHARS@", chars)
                .replace("@FONTS@", "\n".join(tables))
                .replace("@SCREEN@", ", ".join("%.4f" % (c / 255) for c in SCREEN))
                .replace("@EMBLEM_PX@", str(EMBLEM_PX)))
    with open(os.path.join(OUT, "schiefer.script.in"), "w") as f:
        f.write(code)
    with open(os.path.join(OUT, "schiefer.plymouth"), "w") as f:
        f.write("[Plymouth Theme]\n"
                "Name=Schiefer\n"
                "Description=Workstation console: machine banner, systemd units as they start, progress\n"
                "ModuleName=script\n\n"
                "[script]\n"
                "ImageDir=/usr/share/plymouth/themes/schiefer\n"
                "# generated with the machine details by schiefer-plymouth-info (dracut module 90schiefer-plymouth)\n"
                "ScriptFile=/var/lib/schiefer/plymouth/schiefer.script\n")
    print(f"{OUT}: {len(os.listdir(OUT))} files, screen {sc.hexcolor(SCREEN)}, text {sc.hexcolor(LIT)}")


if __name__ == "__main__":
    main()
