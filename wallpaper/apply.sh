#!/bin/bash
# Setzt ein Schiefer-Muster als Hintergrund auf allen Bildschirmen.
#   schiefer-wallpaper [muster]     (Standard: koeper; Auswahl: leinen pflaster wellen granit rauten koeper)
#
# Plasma 6 kann nicht mehr echt kacheln und lädt Bilder immer auf Bildschirmgröße skaliert.
# Darum wird das Muster hier für jede Bildschirmgröße pixelgenau zu einem Vollbild zusammengesetzt.
#
# Testhilfen (Umgebung):
#   SCHIEFER_WALLPAPER_DRYRUN=1   Plasma-Skript nur ausgeben, nicht ausführen
#   SCHIEFER_KSCREEN_JSON=datei   statt `kscreen-doctor -j` diese Datei lesen
#   SCHIEFER_WALLPAPER_DIR=ordner Zielordner statt ~/.local/share/wallpapers/schiefer
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"   # funktioniert auch über /usr/bin/schiefer-wallpaper
NAME="${1:-koeper}"
[[ "$NAME" =~ ^[a-z0-9_-]+$ ]] || { echo "Ungültiger Mustername: $NAME" >&2; exit 1; }
SRC="$HERE/tiles/$NAME.png"
[ -f "$SRC" ] || { echo "Muster nicht gefunden: $SRC" >&2; exit 1; }
DEST_DIR="${SCHIEFER_WALLPAPER_DIR:-$HOME/.local/share/wallpapers/schiefer}"
DRYRUN="${SCHIEFER_WALLPAPER_DRYRUN:-}"
KJSON="${SCHIEFER_KSCREEN_JSON:-}"

# Abhängigkeiten vorab prüfen
fehlt=()
command -v python3 >/dev/null 2>&1 || fehlt+=("python3")
if command -v python3 >/dev/null 2>&1 && ! python3 -I -c 'import PIL' 2>/dev/null; then fehlt+=("python3-PIL (Pillow)"); fi
[ -n "$KJSON" ] || command -v kscreen-doctor >/dev/null 2>&1 || fehlt+=("kscreen-doctor (kscreen)")
[ -n "$DRYRUN" ] || command -v qdbus6 >/dev/null 2>&1 || fehlt+=("qdbus6 (qttools)")
if [ ${#fehlt[@]} -gt 0 ]; then
    echo "Fehlende Abhängigkeiten: ${fehlt[*]}" >&2
    exit 1
fi
mkdir -p "$DEST_DIR"

# Bildschirme: logische Größe (für die Zuordnung) und physische Pixel (für das Bild).
# Ausgabe (stdout): JSON-Liste der erzeugten logischen Größen [[b, h], ...]
if [ -n "$KJSON" ]; then KS="$(cat "$KJSON")"; else KS="$(kscreen-doctor -j)"; fi
SIZES="$(printf '%s' "$KS" | python3 -I -c '
import json, sys
from PIL import Image
src, dest, name = sys.argv[1:4]
tile = Image.open(src).convert("RGB")
outputs = json.load(sys.stdin).get("outputs") or []
if not outputs:
    sys.exit("Fehler: kscreen-doctor meldet keine Ausgänge")
done = []
for o in outputs:
    if not o.get("enabled"):
        continue
    mode = next((m for m in o.get("modes", []) if m.get("id") == o.get("currentModeId")), None)
    if mode is None:
        print("Warnung: Ausgang " + str(o.get("name", "?")) + " ohne aktuellen Modus, übersprungen", file=sys.stderr)
        continue
    pw, ph = mode["size"]["width"], mode["size"]["height"]
    if o.get("rotation", 1) in (2, 8):
        pw, ph = ph, pw
    s = o.get("scale", 1) or 1
    lw, lh = round(pw / s), round(ph / s)
    if [lw, lh] in done:
        continue
    done.append([lw, lh])
    # bei HiDPI (z. B. 200 %) das Muster ganzzahlig mitvergrößern, damit es gleich groß wirkt
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
    sys.exit("Fehler: kein aktiver Bildschirm mit gültigem Modus gefunden")
print(json.dumps(done))
' "$SRC" "$DEST_DIR" "$NAME")"

q() { python3 -I -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }
JS="
const dir = $(q "$DEST_DIR"), name = $(q "$NAME");
const sizes = $SIZES;
for (const d of desktops()) {
    const g = screenGeometry(d.screen);
    // erzeugte Größe mit kleinster Abweichung zur logischen Bildschirmgröße (Rundung kann um 1 px abweichen)
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
echo "Hintergrund gesetzt (Muster: $NAME)"
