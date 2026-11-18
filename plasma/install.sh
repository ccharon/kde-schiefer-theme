#!/bin/bash
# Erzeugt das Plasma-Theme neu, kopiert es nach ~/.local/share und aktiviert es.
#   ./install.sh          Zurück zu Breeze: plasma-apply-desktoptheme default
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 "$HERE/make_plasma_theme.py" >/dev/null
DEST="$HOME/.local/share/plasma/desktoptheme/schiefer"
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$HERE/schiefer" "$DEST"
plasma-apply-desktoptheme schiefer
