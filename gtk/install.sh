#!/bin/bash
# Installiert das GTK-Theme Schiefer (GTK3 + GTK4) und aktiviert es wie die Systemeinstellungen.
#   Zurück: qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme Breeze
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/themes/Schiefer"
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$HERE/Schiefer" "$DEST"
qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme Schiefer
echo "GTK-Theme Schiefer aktiv. GTK-Programme (Firefox, Thunderbird …) neu starten."
