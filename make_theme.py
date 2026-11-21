#!/usr/bin/env python3
"""
Generates the "Schiefer" icon theme from the installed Breeze icon set.

  python3 make_theme.py                       # -> ~/.local/share/icons/schiefer
  python3 make_theme.py --only places devices # only some categories (quick test)
  python3 make_theme.py --force               # overwrite an existing result

The icons stay vector graphics: only the colors in each SVG are rewritten (fill, stroke,
stop-color ...). Shapes, anti-aliasing and sharpness stay exactly as in Breeze, at every size.
Color mapping: desaturate slightly and pull each color halfway toward the nearest tone of a
muted CDE/Motif palette, so applications keep their recognizable colors.
Monochrome icons that follow the color scheme are skipped by default, so Breeze provides them
(Inherits=breeze). Symlinks, including size directories such as 16@2x -> 16, are recreated.

The result is built in a temporary directory next to the target and replaces the target only at
the end (rename); on error or interruption the old target stays. Exit code 1 if files could not
be recolored or no SVG was produced at all (--allow-errors: 0 anyway).
"""
import argparse, colorsys, configparser, os, re, shutil, signal, sys, time
from functools import lru_cache
from multiprocessing import Pool
import numpy as np

MARKER = ".schiefer-generated"
SKIP_CATEGORIES = {"animations"}

# --- Palette: CDE/Motif-like (8 grays + 7 muted hues x 3 levels) -------------------------
def _hsvpal(specs):
    return [[c * 255 for c in colorsys.hsv_to_rgb(h / 360, s, v)] for h, sv in specs for s, v in sv]

GRAYS8 = [[int(h[i:i + 2], 16) for i in (0, 2, 4)]
          for h in "000000 303030 585858 808080 a0a0a0 c3c3c3 dcdcdc ffffff".split()]
CDE = np.array(GRAYS8 + _hsvpal([(h, [(.45, .45), (.40, .65), (.30, .85)])
                                 for h in (0, 35, 50, 110, 190, 220, 270)]), float)
SAT = 0.8      # saturation relative to Breeze
PULL = 0.5     # fraction by which each color is pulled toward the nearest palette tone

def to_lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz /= np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

PAL_LAB = to_lab(CDE)

# Color values in attributes and CSS; url(#id) stays untouched because no ":" or "=" precedes it
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

# --- "Few colors" with dithering (see dither.py) -----------------------------------------
DITHER = None   # set in main()
# Palette for --dither: 8 grays + 12 muted hues x 3 levels = 44 colors
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

# --- Classification and sizes ------------------------------------------------------------
def is_symbolic(svg_text, name, base):
    """Monochrome and follows the color scheme (ColorScheme-*, at most 1 fixed color, no gradient).
    From 32 px on, ColorScheme-Accent tints whole folders; such icons count as colored."""
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

# --- Work per file -----------------------------------------------------------------------
def work(job):
    src, dst, base, include_symbolic, dith = job
    try:
        with open(src, encoding="utf-8", errors="surrogateescape") as f:
            text = f.read()
        symbolic = is_symbolic(text, os.path.basename(src), base)
        if not include_symbolic and symbolic:
            return "symbolic", src, None
        if dith:
            global DITHER
            if DITHER is None:
                DITHER = _make_ditherer()
            d, snap = DITHER
            out = d.process(text, base, snap)
        else:
            out = recolor(text)
        if not symbolic:
            # The theme sets FollowsColorScheme=true so monochrome symbols turn light in dark palettes;
            # KIconLoader then replaces the stylesheet with id="current-color-scheme". Colored icons keep
            # their recolored values (otherwise folders would take the scheme's accent color).
            out = out.replace('id="current-color-scheme"', 'id="schiefer-fixed-colors"')
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", errors="surrogateescape") as f:
            f.write(out)
        return "ok", src, None
    except Exception as e:  # noqa: BLE001  collect errors, do not abort
        return "error", src, repr(e)

# --- Helpers -----------------------------------------------------------------------------
def check_src(src):
    """Check the source; returns an error text or None."""
    if not os.path.exists(src):
        return f"Source {src} does not exist."
    if not os.path.isdir(src):
        return f"Source {src} is not a directory."
    if os.path.isfile(os.path.join(src, "index.theme")):
        return None
    try:
        cats = os.listdir(src)
    except OSError as e:
        return f"Source {src} is not readable: {e}"
    for cat in cats:
        cdir = os.path.join(src, cat)
        try:
            if os.path.isdir(cdir) and any(parse_sizedir(d) for d in os.listdir(cdir)):
                return None
        except OSError:
            continue
    return f"Source {src} does not look like an icon theme (neither index.theme nor categories with size directories)."

def link_target(p, dst, src, tmp):
    """Symlink target for the copy: relative, pointing to the counterpart in the theme (tmp).
    Absolute targets inside src are rewritten; targets outside -> None (skip)."""
    t = os.readlink(p)
    absolute = t if os.path.isabs(t) else os.path.join(os.path.dirname(p), t)
    absolute = os.path.normpath(absolute)
    if absolute != src and not absolute.startswith(src + os.sep):
        return None
    mapped = os.path.join(tmp, os.path.relpath(absolute, src))
    return os.path.relpath(mapped, os.path.dirname(dst))

def swap_in(tmp, out):
    """Move the old target aside, put the new one in place, delete the old. If that fails, restore the old one."""
    old = None
    if os.path.lexists(out):
        old = f"{out}.old-{os.getpid()}"
        os.rename(out, old)
    try:
        os.rename(tmp, out)
    except BaseException:
        if old:
            os.rename(old, out)
        raise
    if old:
        shutil.rmtree(old, ignore_errors=True)

# --- Main --------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default="/usr/share/icons/breeze")
    ap.add_argument("--out", default=os.path.expanduser("~/.local/share/icons/schiefer"))
    ap.add_argument("--name", default="Schiefer")
    ap.add_argument("--only", nargs="*", help="only these categories (for example places devices apps)")
    ap.add_argument("--include-symbolic", action="store_true",
                    help="recolor monochrome color-scheme icons too (they then no longer fit dark schemes)")
    ap.add_argument("--dither", action="store_true",
                    help="few colors: palette plus checkerboard dithering as vector patterns (see dither.py)")
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--force", action="store_true", help="replace an existing theme generated by this script")
    ap.add_argument("--allow-errors", action="store_true",
                    help="exit code 0 and keep the theme even if single files could not be recolored")
    ap.add_argument("--error-log", metavar="FILE", help="also write the error list to this file")
    a = ap.parse_args()

    src, out = os.path.abspath(a.src), os.path.abspath(os.path.expanduser(a.out))

    # 1. Check inputs before touching anything
    msg = check_src(src)
    if msg:
        sys.exit(msg)
    if os.path.lexists(out):
        if not a.force:
            sys.exit(f"{out} already exists. Use --force to replace it.")
        if not os.path.exists(os.path.join(out, MARKER)):
            sys.exit(f"{out} was not generated by this script. Not deleting it.")

    # 2. Build in a temporary directory next to the target (same file system -> atomic rename)
    owner = os.getpid()
    tmp = f"{out}.tmp-{owner}"
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    try:
        rc = build(a, src, out, tmp)
    except KeyboardInterrupt:
        print("\nInterrupted. Target unchanged.", file=sys.stderr)
        rc = 130
    except OSError as e:
        print(f"Error: {e}. Target unchanged.", file=sys.stderr)
        rc = 1
    finally:
        if os.getpid() == owner and os.path.lexists(tmp):
            shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(rc)

def build(a, src, out, tmp):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    os.makedirs(tmp)
    open(os.path.join(tmp, MARKER), "w").close()

    # Collect jobs
    jobs, links, dirlinks = [], [], []
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
            if os.path.islink(ddir):      # for example 16@2x -> 16: recreate as a symlink, do not descend
                dirlinks.append((ddir, os.path.join(tmp, cat, sd)))
                continue
            for root, _, files in os.walk(ddir):
                for f in files:
                    if not f.endswith(".svg"):
                        continue
                    p = os.path.join(root, f)
                    dst = os.path.join(tmp, os.path.relpath(p, src))
                    if os.path.islink(p):
                        links.append((p, dst))
                    else:
                        jobs.append((p, dst, sz[0], a.include_symbolic, a.dither))

    print(f"Source:  {src}\nTarget:  {out}\nFiles:   {len(jobs)} SVGs, {len(links)} symlinks, "
          f"{len(dirlinks)} directory symlinks, {a.jobs} processes\n")
    t0 = time.time()
    stats = {"ok": 0, "symbolic": 0, "error": 0}
    errors, done_src = [], set()
    with Pool(a.jobs) as pool:
        for i, (st, s, msg) in enumerate(pool.imap_unordered(work, jobs, chunksize=64), 1):
            stats[st] += 1
            if st == "ok":
                done_src.add(os.path.realpath(s))
            elif st == "error":
                errors.append(f"{s}: {msg}")
            if i % 500 == 0 or i == len(jobs):
                print(f"\r  {i:5d}/{len(jobs)}  ({100 * i / len(jobs):5.1f} %)  "
                      f"recolored {stats['ok']}, monochrome skipped {stats['symbolic']}, "
                      f"errors {stats['error']} ", end="", flush=True)
    print()

    # Recreate file symlinks whose final target was produced
    nlinks, skipped_links = 0, []
    for p, dst in links:
        if os.path.realpath(p) not in done_src:
            continue
        t = link_target(p, dst, src, tmp)
        if t is None:
            skipped_links.append(p)       # points out of the theme (for example absolute into Breeze)
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            os.symlink(t, dst)
            nlinks += 1
        except FileExistsError:
            pass

    # Recreate directory symlinks whose target directory was produced
    ndl, linked_dirs = 0, []
    for p, dst in dirlinks:
        t = link_target(p, dst, src, tmp)
        if t is None or not os.path.isdir(os.path.join(os.path.dirname(dst), t)):
            continue
        os.symlink(t, dst)
        ndl += 1
        linked_dirs.append(os.path.relpath(dst, tmp))

    # index.theme: take the sections of the present directories from Breeze (Scalable, Min/MaxSize ...)
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    cp.read(os.path.join(src, "index.theme"), encoding="utf-8")
    present = {os.path.relpath(r, tmp) for r, _, fs in os.walk(tmp) if any(f.endswith(".svg") for f in fs)}
    present |= set(linked_dirs)
    dirs = [d for d in cp.get("Icon Theme", "Directories", fallback="").split(",") if d in present]
    sdirs = [d for d in cp.get("Icon Theme", "ScaledDirectories", fallback="").split(",") if d in present]
    # Add directories that index.theme does not list
    known = set(dirs) | set(sdirs)
    extra = sorted(d for d in present if d not in known and parse_sizedir(d.split("/")[-1]))
    lines = ["[Icon Theme]", f"Name={a.name}",
             "Comment=Breeze in muted CDE/Motif colors, generated",
             "Inherits=breeze,hicolor",
             # as in Breeze: stylesheet colors (ColorScheme-*) follow the color scheme; otherwise
             # symbols, including those inherited from Breeze, stay dark in dark palettes
             "FollowsColorScheme=true", "DisplayDepth=32", "Example=folder",
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
    with open(os.path.join(tmp, "index.theme"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    # Errors go to stderr (and optionally a file), never into the theme
    for p in skipped_links:
        errors.append(f"{p}: symlink points out of the theme, skipped")
    if errors:
        print(f"\n{len(errors)} errors:", file=sys.stderr)
        print("\n".join(errors), file=sys.stderr)
        if a.error_log:
            with open(a.error_log, "w") as f:
                f.write("\n".join(errors) + "\n")
    print(f"\nGenerated in {time.time() - t0:.0f}s: {stats['ok']} SVGs, {nlinks} file symlinks, {ndl} directory symlinks, "
          f"{stats['symbolic']} monochrome skipped (-> Breeze), {len(errors)} errors")
    if stats["ok"] == 0:
        print("Error: no SVG was generated. Target unchanged.", file=sys.stderr)
        return 1
    if errors and not a.allow_errors:
        print("Errors while recoloring. Target unchanged (--allow-errors keeps the result anyway).",
              file=sys.stderr)
        return 1

    swap_in(tmp, out)
    print(f"Theme: {a.name}  ->  {out}\nSystem Settings > Colors & Themes > Icons")
    return 0

if __name__ == "__main__":
    main()
