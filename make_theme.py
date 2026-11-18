#!/usr/bin/env python3
"""
Erzeugt aus dem installierten Breeze-Icon-Set ein Retro-Icon-Theme im CDE/Motif-Stil.

  python3 make_theme.py                       # -> ~/.local/share/icons/schiefer
  python3 make_theme.py --only places devices # nur einige Kategorien (schneller Test)
  python3 make_theme.py --force               # vorhandenes Ergebnis überschreiben

Ablauf pro Icon: SVG mit rsvg-convert rastern (ohne Kantenglättung im Ergebnis), Farben
auf eine gedämpfte Palette abbilden (Bayer-Dither nur in Verläufen), dunkle Kontur.
Größen über 32 px werden halb so groß gerendert und pixelgenau verdoppelt (chunky),
@2x/@3x-Ordner ebenso. Einfarbige Icons, die dem Farbschema folgen, werden standardmäßig
ausgelassen -> dafür greift Breeze (Inherits=breeze). Symlinks werden nachgebildet.
"""
import argparse, colorsys, configparser, io, os, re, shutil, subprocess, sys, time
from multiprocessing import Pool
import numpy as np
from PIL import Image

MARKER = ".schiefer-generated"
SKIP_CATEGORIES = {"animations"}

# --- Palette: CDE/Motif-artig (8 Grau + 7 gedämpfte Farbtöne x 3 Stufen) -----------------
def _hsvpal(specs):
    return [[c * 255 for c in colorsys.hsv_to_rgb(h / 360, s, v)] for h, sv in specs for s, v in sv]

GRAYS8 = [[int(h[i:i + 2], 16) for i in (0, 2, 4)]
          for h in "000000 303030 585858 808080 a0a0a0 c3c3c3 dcdcdc ffffff".split()]
CDE = np.array(GRAYS8 + _hsvpal([(h, [(.45, .45), (.40, .65), (.30, .85)])
                                 for h in (0, 35, 50, 110, 190, 220, 270)]), float)
OUTLINE = (48, 48, 48)
DITHER, SAT, ALPHA_MIN = 24, 0.8, 70

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16 - 0.5
N4 = [(0, 1), (0, -1), (1, 0), (-1, 0)]
N8 = N4 + [(1, 1), (1, -1), (-1, 1), (-1, -1)]

def to_lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz /= np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

PAL_LAB = to_lab(CDE)

def shift(m, dy, dx):
    out = np.zeros_like(m); h, w = m.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = \
        m[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out

def retro(img):
    a = np.asarray(img, float)
    rgb, alpha = a[..., :3], a[..., 3]
    h, w = alpha.shape
    solid = alpha >= ALPHA_MIN
    # Dither nur in sanften Verläufen
    d = np.zeros((h, w))
    for dy, dx in N8:
        d = np.maximum(d, np.abs(rgb - shift(rgb, dy, dx)).max(-1))
    grad = (d > 1.5) & (d < 40)
    g = (rgb * [0.3, 0.59, 0.11]).sum(-1, keepdims=True)
    x = np.clip(g + (rgb - g) * SAT, 0, 255)
    t = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w, None]
    x = np.clip(x + t * DITHER * grad[..., None], 0, 255)
    q = CDE[((to_lab(x)[:, :, None, :] - PAL_LAB[None, None]) ** 2).sum(-1).argmin(-1)]
    out = np.zeros((h, w, 4), np.uint8)
    out[solid, :3] = q[solid]; out[solid, 3] = 255
    edge = np.zeros_like(solid)
    for dy, dx in N4:
        edge |= shift(solid, dy, dx)
    edge &= ~solid
    out[edge, :3] = OUTLINE; out[edge, 3] = 255
    return Image.fromarray(out, "RGBA")

# --- Klassifizierung & Größen ------------------------------------------------------------
def is_symbolic(svg_text, name, base):
    """Einfarbig + folgt dem Farbschema (ColorScheme-*, max. 1 feste Farbe, kein Verlauf).
    Ab 32 px färbt ColorScheme-Accent ganze Ordner ein -> dann gilt das Icon als farbig."""
    if name.endswith("-symbolic.svg"):
        return True
    if "ColorScheme-" not in svg_text:
        return False
    if base >= 32 and "ColorScheme-Accent" in svg_text:
        return False
    body = re.sub(r"<style.*?</style>", "", svg_text, flags=re.S)
    if "Gradient" in body:
        return False
    return len({c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", body)}) <= 1

def parse_sizedir(name):
    m = re.fullmatch(r"(\d+)(?:@(\d)x)?", name)
    return (int(m.group(1)), int(m.group(2) or 1)) if m else None

def plan(base, scale, chunky):
    """-> (Renderauflösung, Vergrößerungsfaktor)"""
    px, up = base, scale
    if chunky and base > 32:
        px, up = base // 2, up * 2
    return px, up

# --- Arbeit pro Datei --------------------------------------------------------------------
def work(job):
    src, dst, px, up, base, include_symbolic = job
    try:
        with open(src, errors="ignore") as f:
            text = f.read()
        if not include_symbolic and is_symbolic(text, os.path.basename(src), base):
            return "symbolic", src, None
        png = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), src],
                             capture_output=True, check=True, timeout=60).stdout
        img = retro(Image.open(io.BytesIO(png)).convert("RGBA"))
        if up > 1:
            img = img.resize((px * up, px * up), Image.NEAREST)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        img.save(dst, optimize=True)
        return "ok", src, None
    except Exception as e:  # noqa: BLE001 – Fehler sammeln, nicht abbrechen
        msg = e.stderr.decode(errors="ignore").strip() if isinstance(e, subprocess.CalledProcessError) else repr(e)
        return "error", src, msg

# --- Hauptprogramm -----------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default="/usr/share/icons/breeze")
    ap.add_argument("--out", default=os.path.expanduser("~/.local/share/icons/schiefer"))
    ap.add_argument("--name", default="Schiefer")
    ap.add_argument("--only", nargs="*", help="nur diese Kategorien (z. B. places devices apps)")
    ap.add_argument("--include-symbolic", action="store_true",
                    help="auch einfarbige Farbschema-Icons umwandeln (passen dann nicht mehr zu dunklen Schemata)")
    ap.add_argument("--no-chunky", action="store_true", help="große Größen nativ statt verdoppelt rendern")
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--force", action="store_true", help="vorhandenes (von diesem Skript erzeugtes) Theme ersetzen")
    a = ap.parse_args()

    src, out = os.path.abspath(a.src), os.path.abspath(os.path.expanduser(a.out))
    if not shutil.which("rsvg-convert"):
        sys.exit("rsvg-convert nicht gefunden (gnome-base/librsvg).")
    if os.path.exists(out):
        if not a.force:
            sys.exit(f"{out} existiert schon – mit --force ersetzen.")
        if not os.path.exists(os.path.join(out, MARKER)):
            sys.exit(f"{out} wurde nicht von diesem Skript erzeugt – lösche ich nicht.")
        shutil.rmtree(out)
    os.makedirs(out)
    open(os.path.join(out, MARKER), "w").close()

    # Aufträge sammeln
    jobs, links = [], []
    for cat in sorted(os.listdir(src)):
        if cat in SKIP_CATEGORIES or (a.only and cat not in a.only):
            continue
        cdir = os.path.join(src, cat)
        if not os.path.isdir(cdir):
            continue
        for sd in sorted(os.listdir(cdir)):
            sz = parse_sizedir(sd)
            ddir = os.path.join(cdir, sd)
            if not sz or not os.path.isdir(ddir):
                continue
            px, up = plan(*sz, chunky=not a.no_chunky)
            for root, _, files in os.walk(ddir):
                for f in files:
                    if not f.endswith(".svg"):
                        continue
                    p = os.path.join(root, f)
                    rel = os.path.relpath(p, src)
                    dst = os.path.join(out, rel[:-4] + ".png")
                    if os.path.islink(p):
                        links.append((p, dst))
                    else:
                        jobs.append((p, dst, px, up, sz[0], a.include_symbolic))

    print(f"Quelle:  {src}\nZiel:    {out}\nDateien: {len(jobs)} SVGs, {len(links)} Symlinks, {a.jobs} Prozesse\n")
    t0 = time.time()
    stats = {"ok": 0, "symbolic": 0, "error": 0}
    errors, done_src = [], set()
    with Pool(a.jobs) as pool:
        for i, (st, s, msg) in enumerate(pool.imap_unordered(work, jobs, chunksize=8), 1):
            stats[st] += 1
            if st == "ok":
                done_src.add(s)
            elif st == "error":
                errors.append(f"{s}: {msg}")
            if i % 50 == 0 or i == len(jobs):
                el = time.time() - t0
                eta = el / i * (len(jobs) - i)
                print(f"\r  {i:5d}/{len(jobs)}  ({100 * i / len(jobs):5.1f} %)  "
                      f"umgewandelt {stats['ok']}, einfarbig übersprungen {stats['symbolic']}, "
                      f"Fehler {stats['error']}  –  noch ~{eta:4.0f}s ", end="", flush=True)
    print()

    # Symlinks nachbilden, wenn ihr endgültiges Ziel erzeugt wurde
    nlinks = 0
    for p, dst in links:
        final = os.path.realpath(p)
        target = os.readlink(p)
        if final not in done_src or not target.endswith(".svg"):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            os.symlink(target[:-4] + ".png", dst)
            nlinks += 1
        except FileExistsError:
            pass

    # index.theme
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    cp.read(os.path.join(src, "index.theme"), encoding="utf-8")
    dirs = sorted({os.path.relpath(os.path.dirname(os.path.join(r, f)), out)
                   for r, _, fs in os.walk(out) for f in fs if f.endswith(".png")},
                  key=lambda d: (d.split("/")[0], parse_sizedir(d.split("/")[1]) or (0, 0)))
    lines = ["[Icon Theme]", f"Name={a.name}",
             "Comment=Breeze im Retro-Look (CDE/Motif-artig), automatisch erzeugt",
             "Inherits=breeze,hicolor", "DisplayDepth=32", "Example=folder",
             f"Directories={','.join(dirs)}", ""]
    for d in dirs:
        base, scale = parse_sizedir(d.split("/")[1])
        ctx = cp.get(d, "Context", fallback=None) if cp.has_section(d) else None
        lines += [f"[{d}]", f"Size={base}", f"Scale={scale}"] + ([f"Context={ctx}"] if ctx else []) \
                 + ["Type=Fixed", ""]
    with open(os.path.join(out, "index.theme"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    if errors:
        with open(os.path.join(out, "errors.log"), "w") as f:
            f.write("\n".join(errors) + "\n")
    print(f"\nFertig in {time.time() - t0:.0f}s: {stats['ok']} PNGs, {nlinks} Symlinks, "
          f"{stats['symbolic']} einfarbige übersprungen (-> Breeze), {stats['error']} Fehler"
          + (f" (siehe {out}/errors.log)" if errors else ""))
    print(f"Theme: {a.name}  ->  Systemeinstellungen › Farben & Designs › Symbole")

if __name__ == "__main__":
    main()
