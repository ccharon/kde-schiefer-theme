#!/bin/bash
# Setzt ein Schiefer-Muster als Hintergrund auf allen Bildschirmen.
#   schiefer-wallpaper [muster]     (Standard: koeper; Auswahl: leinen pflaster wellen granit rauten koeper)
#
# Plasma 6 kann nicht mehr echt kacheln und lädt Bilder immer auf Bildschirmgröße skaliert.
# Darum wird das Muster hier für jede Bildschirmgröße pixelgenau zu einem Vollbild zusammengesetzt.
set -e
HERE="$(dirname "$(readlink -f "$0")")"   # funktioniert auch über /usr/bin/schiefer-wallpaper
NAME="${1:-koeper}"
SRC="$HERE/tiles/$NAME.png"
[ -f "$SRC" ] || { echo "Muster nicht gefunden: $SRC"; exit 1; }
DEST_DIR="$HOME/.local/share/wallpapers/schiefer"
mkdir -p "$DEST_DIR"

# Bildschirme: logische Größe (für die Zuordnung) und physische Pixel (für das Bild)
kscreen-doctor -j | python3 -I -c '
import json, sys
from PIL import Image
src, dest, name = sys.argv[1:4]
tile = Image.open(src).convert("RGB")
done = set()
for o in json.load(sys.stdin)["outputs"]:
    if not o.get("enabled"):
        continue
    mode = next(m for m in o["modes"] if m["id"] == o["currentModeId"])
    pw, ph = mode["size"]["width"], mode["size"]["height"]
    if o.get("rotation", 1) in (2, 8):
        pw, ph = ph, pw
    s = o.get("scale", 1) or 1
    lw, lh = round(pw / s), round(ph / s)
    if (lw, lh) in done:
        continue
    done.add((lw, lh))
    # bei HiDPI (z. B. 200 %) das Muster ganzzahlig mitvergrößern, damit es gleich groß wirkt
    f = max(1, round(s))
    t = tile.resize((tile.width * f, tile.height * f), Image.NEAREST) if f > 1 else tile
    im = Image.new("RGB", (pw, ph))
    for y in range(0, ph, t.height):
        for x in range(0, pw, t.width):
            im.paste(t, (x, y))
    out = f"{dest}/{name}-{lw}x{lh}.png"
    im.save(out, optimize=True)
    print(out)
' "$SRC" "$DEST_DIR" "$NAME"

qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
for (const d of desktops()) {
    const g = screenGeometry(d.screen);
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    d.writeConfig('Image', 'file://$DEST_DIR/$NAME-' + g.width + 'x' + g.height + '.png');
    d.writeConfig('FillMode', 2);
}"
echo "Hintergrund gesetzt (Muster: $NAME)"
