#!/bin/bash
# Installiert alle Schiefer-Farbschemata (Schiefer, SchieferSandstein, SchieferJade, SchieferGranit,
# SchieferBasalt – erzeugt von palettes/make_palette.py) und wendet eines an.
#   ./install.sh [Schema]      (Standard: Schiefer)
# Entfernt dabei eine alte [Colors:Header]-Gruppe aus kdeglobals: Plasma lässt sie beim Wechsel stehen,
# und ohne sie übernehmen GTK-Kopfleisten (z. B. Firefox) die Titelleistenfarbe aus [WM].
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.local/share/color-schemes
SCHEME="${1:-Schiefer}"
[ -f "$HERE/$SCHEME.colors" ] || { echo "Unbekanntes Schema: $SCHEME" >&2; exit 1; }
cp "$HERE"/*.colors ~/.local/share/color-schemes/
for key in BackgroundAlternate BackgroundNormal DecorationFocus DecorationHover ForegroundActive \
           ForegroundInactive ForegroundLink ForegroundNegative ForegroundNeutral ForegroundNormal \
           ForegroundPositive ForegroundVisited; do
    kwriteconfig6 --file kdeglobals --group "Colors:Header" --key "$key" --delete
    kwriteconfig6 --file kdeglobals --group "Colors:Header" --group Inactive --key "$key" --delete
done
# Umweg über BreezeLight, damit Plasma das (gleichnamige) Schema sicher neu einliest
plasma-apply-colorscheme BreezeLight >/dev/null
plasma-apply-colorscheme "$SCHEME"
