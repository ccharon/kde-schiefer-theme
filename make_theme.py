#!/usr/bin/env python3
"""
Erzeugt aus dem installierten Breeze-Icon-Set das Icon-Theme „Schiefer“.

  python3 make_theme.py                       # -> ~/.local/share/icons/schiefer
  python3 make_theme.py --only places devices # nur einige Kategorien (schneller Test)
  python3 make_theme.py --force               # vorhandenes Ergebnis überschreiben

Die Icons bleiben Vektorgrafiken: Pro SVG werden nur die Farben umgeschrieben (fill, stroke,
stop-color …). Form, Kantenglättung und Schärfe sind damit genau wie bei Breeze, in jeder
Größe. Farbabbildung „weich“: leicht entsättigen und jede Farbe zur Hälfte an den nächsten
Ton einer gedämpften CDE/Motif-Palette annähern – die Programme behalten ihre Erkennungsfarbe.
Einfarbige Icons, die dem Farbschema folgen, werden standardmäßig ausgelassen -> dafür greift
Breeze (Inherits=breeze). Symlinks werden nachgebildet.
"""
import argparse, colorsys, configparser, os, re, shutil, sys, time
from functools import lru_cache
from multiprocessing import Pool
import numpy as np

MARKER = ".schiefer-generated"
SKIP_CATEGORIES = {"animations"}

# --- Palette: CDE/Motif-artig (8 Grau + 7 gedämpfte Farbtöne x 3 Stufen) -----------------
def _hsvpal(specs):
    return [[c * 255 for c in colorsys.hsv_to_rgb(h / 360, s, v)] for h, sv in specs for s, v in sv]

GRAYS8 = [[int(h[i:i + 2], 16) for i in (0, 2, 4)]
          for h in "000000 303030 585858 808080 a0a0a0 c3c3c3 dcdcdc ffffff".split()]
CDE = np.array(GRAYS8 + _hsvpal([(h, [(.45, .45), (.40, .65), (.30, .85)])
                                 for h in (0, 35, 50, 110, 190, 220, 270)]), float)
SAT = 0.8      # Sättigung gegenüber Breeze
PULL = 0.5     # Anteil, mit dem jede Farbe zum nächsten Palettenton gezogen wird

def to_lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz /= np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

PAL_LAB = to_lab(CDE)

# Farbwerte in Attributen und CSS; url(#id) bleibt unberührt, weil davor kein „:“/„=“ steht
COLOR_RE = re.compile(
    r'((?:fill|stroke|stop-color|flood-color|lighting-color|color)\s*[:=]\s*["\']?)'
    r'(#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|white\b|black\b)')
NAMED = {"white": "#ffffff", "black": "#000000"}

@lru_cache(maxsize=None)
def map_color(value):
    v = NAMED.get(value, value)[1:]
    if len(v) == 3:
        v = "".join(ch * 2 for ch in v)
    x = np.array([int(v[i:i + 2], 16) for i in (0, 2, 4)], float)
    g = (x * [0.3, 0.59, 0.11]).sum()
    x = np.clip(g + (x - g) * SAT, 0, 255)
    near = CDE[((to_lab(x[None])[0] - PAL_LAB) ** 2).sum(-1).argmin()]
    y = (1 - PULL) * x + PULL * near
    return "#%02x%02x%02x" % tuple(int(round(c)) for c in y)

def recolor(svg_text):
    return COLOR_RE.sub(lambda m: m.group(1) + map_color(m.group(2)), svg_text)

# --- „Wenig Farben“ mit Dithering (siehe dither.py) ---------------------------------------
DITHER = None   # wird in main() gesetzt
# Palette für --dither: 8 Grau + 12 gedämpfte Farbtöne x 3 Stufen = 44 Farben
GRAYS12 = [[v] * 3 for v in (0, 40, 72, 100, 128, 150, 172, 192, 210, 226, 242, 255)]
DPAL = np.array(GRAYS12 + _hsvpal([(h, [(.60, .50), (.55, .75), (.35, .92)])
                                  for h in (0, 25, 42, 55, 100, 165, 192, 205, 218, 240, 275, 330)]), float)

def _make_ditherer():
    import dither
    q = dither.Quantizer(DPAL, sat=float(os.environ.get("SD_SAT", 0.9)),
                         max_pair_de=float(os.environ.get("SD_DE", 26)))
    pal = {dither.hexc(c) for c in DPAL}
    def snap(svg_text):
        def rep(m):
            v = m.group(2)
            rgb = dither.parse_color(NAMED.get(v, v))
            if rgb is None or dither.hexc(rgb) in pal:
                return m.group(0)
            return m.group(1) + q.pure(rgb)
        return COLOR_RE.sub(rep, svg_text)
    return dither.Ditherer(q), snap

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

# --- Arbeit pro Datei --------------------------------------------------------------------
def work(job):
    src, dst, base, include_symbolic, dith = job
    try:
        with open(src, encoding="utf-8", errors="surrogateescape") as f:
            text = f.read()
        if not include_symbolic and is_symbolic(text, os.path.basename(src), base):
            return "symbolic", src, None
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", errors="surrogateescape") as f:
            if dith:
                global DITHER
                if DITHER is None:
                    DITHER = _make_ditherer()
                d, snap = DITHER
                f.write(d.process(text, base, snap))
            else:
                f.write(recolor(text))
        return "ok", src, None
    except Exception as e:  # noqa: BLE001 – Fehler sammeln, nicht abbrechen
        return "error", src, repr(e)

# --- Hauptprogramm -----------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default="/usr/share/icons/breeze")
    ap.add_argument("--out", default=os.path.expanduser("~/.local/share/icons/schiefer"))
    ap.add_argument("--name", default="Schiefer")
    ap.add_argument("--only", nargs="*", help="nur diese Kategorien (z. B. places devices apps)")
    ap.add_argument("--include-symbolic", action="store_true",
                    help="auch einfarbige Farbschema-Icons umfärben (passen dann nicht mehr zu dunklen Schemata)")
    ap.add_argument("--dither", action="store_true",
                    help="„wenig Farben“: Palette + Schachbrett-Dithering als Vektor-Muster (siehe dither.py)")
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--force", action="store_true", help="vorhandenes (von diesem Skript erzeugtes) Theme ersetzen")
    a = ap.parse_args()

    src, out = os.path.abspath(a.src), os.path.abspath(os.path.expanduser(a.out))
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
            for root, _, files in os.walk(ddir):
                for f in files:
                    if not f.endswith(".svg"):
                        continue
                    p = os.path.join(root, f)
                    dst = os.path.join(out, os.path.relpath(p, src))
                    if os.path.islink(p):
                        links.append((p, dst))
                    else:
                        jobs.append((p, dst, sz[0], a.include_symbolic, a.dither))

    print(f"Quelle:  {src}\nZiel:    {out}\nDateien: {len(jobs)} SVGs, {len(links)} Symlinks, {a.jobs} Prozesse\n")
    t0 = time.time()
    stats = {"ok": 0, "symbolic": 0, "error": 0}
    errors, done_src = [], set()
    with Pool(a.jobs) as pool:
        for i, (st, s, msg) in enumerate(pool.imap_unordered(work, jobs, chunksize=64), 1):
            stats[st] += 1
            if st == "ok":
                done_src.add(s)
            elif st == "error":
                errors.append(f"{s}: {msg}")
            if i % 500 == 0 or i == len(jobs):
                print(f"\r  {i:5d}/{len(jobs)}  ({100 * i / len(jobs):5.1f} %)  "
                      f"umgefärbt {stats['ok']}, einfarbig übersprungen {stats['symbolic']}, "
                      f"Fehler {stats['error']} ", end="", flush=True)
    print()

    # Symlinks nachbilden, wenn ihr endgültiges Ziel erzeugt wurde
    nlinks = 0
    for p, dst in links:
        if os.path.realpath(p) not in done_src:
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            os.symlink(os.readlink(p), dst)
            nlinks += 1
        except FileExistsError:
            pass

    # index.theme: Abschnitte der vorhandenen Ordner aus Breeze übernehmen (Scalable, Min/MaxSize …)
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    cp.read(os.path.join(src, "index.theme"), encoding="utf-8")
    present = {os.path.relpath(r, out) for r, _, fs in os.walk(out) if any(f.endswith(".svg") for f in fs)}
    dirs = [d for d in cp.get("Icon Theme", "Directories", fallback="").split(",") if d in present]
    sdirs = [d for d in cp.get("Icon Theme", "ScaledDirectories", fallback="").split(",") if d in present]
    # Ordner, die index.theme nicht nennt, trotzdem eintragen
    known = set(dirs) | set(sdirs)
    extra = sorted(d for d in present if d not in known and parse_sizedir(d.split("/")[-1]))
    lines = ["[Icon Theme]", f"Name={a.name}",
             "Comment=Breeze in gedämpften CDE/Motif-Farben, automatisch erzeugt",
             "Inherits=breeze,hicolor", "DisplayDepth=32", "Example=folder",
             f"Directories={','.join(dirs + extra)}"]
    if sdirs:
        lines.append(f"ScaledDirectories={','.join(sdirs)}")
    lines.append("")
    for d in dirs + sdirs + extra:
        if cp.has_section(d):
            lines += [f"[{d}]"] + [f"{k}={v}" for k, v in cp.items(d)] + [""]
        else:
            base, scale = parse_sizedir(d.split("/")[-1])
            lines += [f"[{d}]", f"Size={base}", f"Scale={scale}", "Type=Scalable", ""]
    with open(os.path.join(out, "index.theme"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    if errors:
        with open(os.path.join(out, "errors.log"), "w") as f:
            f.write("\n".join(errors) + "\n")
    print(f"\nFertig in {time.time() - t0:.0f}s: {stats['ok']} SVGs, {nlinks} Symlinks, "
          f"{stats['symbolic']} einfarbige übersprungen (-> Breeze), {stats['error']} Fehler"
          + (f" (siehe {out}/errors.log)" if errors else ""))
    print(f"Theme: {a.name}  ->  Systemeinstellungen › Farben & Designs › Symbole")

if __name__ == "__main__":
    main()
