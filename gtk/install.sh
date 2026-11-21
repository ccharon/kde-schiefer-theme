#!/bin/bash
# Installs the Schiefer GTK theme (GTK3 and GTK4) and activates it like System Settings does.
#   Back: qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme Breeze
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/themes/Schiefer"
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$HERE/Schiefer" "$DEST"
qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme Schiefer
echo "GTK theme Schiefer active. Restart GTK applications (Firefox, Thunderbird ...)."
