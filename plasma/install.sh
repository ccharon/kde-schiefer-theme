#!/bin/bash
# Regenerates the Plasma theme, copies it to ~/.local/share and activates it.
#   ./install.sh          Back to Breeze: plasma-apply-desktoptheme default
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 "$HERE/make_plasma_theme.py" >/dev/null
DEST="$HOME/.local/share/plasma/desktoptheme/schiefer"
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$HERE/schiefer" "$DEST"
plasma-apply-desktoptheme schiefer
