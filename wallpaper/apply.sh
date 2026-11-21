#!/bin/bash
# Sets a Schiefer pattern as the wallpaper on all screens.
#   schiefer-wallpaper [pattern]    (default: koeper; choices: leinen pflaster wellen granit rauten koeper)
#
# Plasma 6 cannot tile and always loads images scaled to the screen size.
# So the pattern is assembled into a pixel-exact full image for each screen size.
#
# Test helpers (environment):
#   SCHIEFER_WALLPAPER_DRYRUN=1   print the Plasma script instead of running it
#   SCHIEFER_KSCREEN_JSON=file    read this file instead of `kscreen-doctor -j`
#   SCHIEFER_WALLPAPER_DIR=dir    target directory instead of ~/.local/share/wallpapers/schiefer
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"   # also works through /usr/bin/schiefer-wallpaper
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in de*) DE=1 ;; *) DE= ;; esac
msg() { if [ -n "$DE" ]; then printf '%s\n' "$2"; else printf '%s\n' "$1"; fi; }
NAME="${1:-koeper}"
[[ "$NAME" =~ ^[a-z0-9_-]+$ ]] || { msg "Invalid pattern name: $NAME" "Ungültiger Mustername: $NAME" >&2; exit 1; }
SRC="$HERE/tiles/$NAME.png"
[ -f "$SRC" ] || { msg "Pattern not found: $SRC" "Muster nicht gefunden: $SRC" >&2; exit 1; }
DEST_DIR="${SCHIEFER_WALLPAPER_DIR:-$HOME/.local/share/wallpapers/schiefer}"
DRYRUN="${SCHIEFER_WALLPAPER_DRYRUN:-}"
KJSON="${SCHIEFER_KSCREEN_JSON:-}"

# check dependencies first
missing=()
command -v python3 >/dev/null 2>&1 || missing+=("python3")
if command -v python3 >/dev/null 2>&1 && ! python3 -I -c 'import PIL' 2>/dev/null; then missing+=("python3-PIL (Pillow)"); fi
[ -n "$KJSON" ] || command -v kscreen-doctor >/dev/null 2>&1 || missing+=("kscreen-doctor (kscreen)")
[ -n "$DRYRUN" ] || command -v qdbus6 >/dev/null 2>&1 || missing+=("qdbus6 (qttools)")
if [ ${#missing[@]} -gt 0 ]; then
    msg "Missing dependencies: ${missing[*]}" "Fehlende Abhängigkeiten: ${missing[*]}" >&2
    exit 1
fi
mkdir -p "$DEST_DIR"

# Screens: logical size (for matching) and physical pixels (for the image).
# Output (stdout): JSON list of the generated logical sizes [[w, h], ...]
if [ -n "$KJSON" ]; then KS="$(cat "$KJSON")"; else KS="$(kscreen-doctor -j)"; fi
SIZES="$(printf '%s' "$KS" | python3 -I -c '
import json, sys
from PIL import Image
src, dest, name = sys.argv[1:4]
tile = Image.open(src).convert("RGB")
outputs = json.load(sys.stdin).get("outputs") or []
if not outputs:
    sys.exit("Error: kscreen-doctor reports no outputs")
done = []
for o in outputs:
    if not o.get("enabled"):
        continue
    mode = next((m for m in o.get("modes", []) if m.get("id") == o.get("currentModeId")), None)
    if mode is None:
        print("Warning: output " + str(o.get("name", "?")) + " has no current mode, skipped", file=sys.stderr)
        continue
    pw, ph = mode["size"]["width"], mode["size"]["height"]
    if o.get("rotation", 1) in (2, 8):
        pw, ph = ph, pw
    s = o.get("scale", 1) or 1
    lw, lh = round(pw / s), round(ph / s)
    if [lw, lh] in done:
        continue
    done.append([lw, lh])
    # with HiDPI (for example 200 %) scale the pattern by an integer factor so it looks the same size
    f = max(1, round(s))
    t = tile.resize((tile.width * f, tile.height * f), Image.NEAREST) if f > 1 else tile
    im = Image.new("RGB", (pw, ph))
    for y in range(0, ph, t.height):
        for x in range(0, pw, t.width):
            im.paste(t, (x, y))
    out = f"{dest}/{name}-{lw}x{lh}.png"
    im.save(out, optimize=True)
    print(out, file=sys.stderr)
if not done:
    sys.exit("Error: no active screen with a valid mode found")
print(json.dumps(done))
' "$SRC" "$DEST_DIR" "$NAME")"

q() { python3 -I -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }
JS="
const dir = $(q "$DEST_DIR"), name = $(q "$NAME");
const sizes = $SIZES;
for (const d of desktops()) {
    const g = screenGeometry(d.screen);
    // generated size closest to the logical screen size (rounding can differ by 1 px)
    let best = sizes[0], bd = Infinity;
    for (const s of sizes) {
        const dd = Math.abs(s[0] - g.width) + Math.abs(s[1] - g.height);
        if (dd < bd) { bd = dd; best = s; }
    }
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    d.writeConfig('Image', 'file://' + encodeURI(dir + '/' + name + '-' + best[0] + 'x' + best[1] + '.png'));
    d.writeConfig('FillMode', 2);
}"

if [ -n "$DRYRUN" ]; then
    printf '%s\n' "$JS"
    exit 0
fi
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS" >/dev/null
msg "Wallpaper set (pattern: $NAME)" "Hintergrund gesetzt (Muster: $NAME)"
