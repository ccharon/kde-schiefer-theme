#!/bin/bash
# Installiert das Farbschema Schiefer und wendet es an.
# Entfernt dabei eine alte [Colors:Header]-Gruppe aus kdeglobals: Plasma lässt sie beim Wechsel stehen,
# und ohne sie übernehmen GTK-Kopfleisten (z. B. Firefox) die Titelleistenfarbe aus [WM].
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.local/share/color-schemes
cp "$HERE/Schiefer.colors" ~/.local/share/color-schemes/
for key in BackgroundAlternate BackgroundNormal DecorationFocus DecorationHover ForegroundActive \
           ForegroundInactive ForegroundLink ForegroundNegative ForegroundNeutral ForegroundNormal \
           ForegroundPositive ForegroundVisited; do
    kwriteconfig6 --file kdeglobals --group "Colors:Header" --key "$key" --delete
    kwriteconfig6 --file kdeglobals --group "Colors:Header" --group Inactive --key "$key" --delete
done
# Umweg über BreezeLight, damit Plasma das (gleichnamige) Schema sicher neu einliest
plasma-apply-colorscheme BreezeLight >/dev/null
plasma-apply-colorscheme Schiefer
