#!/bin/bash
# Packt Quelltarball und Ebuilds für das lokale Overlay (als normaler Benutzer ausführen).
#   tools/make-dist.sh      -> dist/schiefer-<VERSION>.tar.xz und dist/overlay/x11-themes/*
# Der Tarball ist reproduzierbar (feste Reihenfolge und Besitzer): unveränderte Dateien = gleiche Prüfsumme.
# Die Änderungszeiten bleiben bewusst echt: Qt verwirft seinen QML-Cache (~/.cache/*/qmlcache) nur, wenn sich
# die Zeit der Quelldatei ändert. Mit einer festen Zeit liefe nach einem Update weiter der alte QML-Code.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
V="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$V" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Ungültige VERSION in $ROOT/VERSION: '$V'" >&2; exit 1; }
DIST="$ROOT/dist"

FILES=(
    VERSION UPSTREAM.md make_theme.py dither.py
    colors common palettes
    gtk/Schiefer
    kdecoration/CMakeLists.txt kdecoration/schiefer.json kdecoration/retrodecoration.cpp kdecoration/retrodecoration.h
    kstyle
    lookandfeel
    plasma/make_plasma_theme.py
    wallpaper/apply.sh wallpaper/make_wallpaper_package.py wallpaper/tiles
    wallpaper/plugin/CMakeLists.txt wallpaper/plugin/package wallpaper/plugin/shaders
    cursors/make_cursors.py
    kwin/tabbox
    tools/schiefer-config
    dock
    greeter
)
# erst prüfen, dann dist/ löschen
for f in "${FILES[@]}" packaging/x11-themes tools/install-overlay.sh; do
    [ -e "$ROOT/$f" ] || { echo "Fehlt: $f" >&2; exit 1; }
done
rm -rf "$DIST"
# layout.conf/repo_name: damit `ebuild` die Pakete auch direkt aus dist/overlay bauen kann (Test ohne root)
mkdir -p "$DIST/overlay/metadata" "$DIST/overlay/profiles"
printf 'masters = gentoo\nthin-manifests = true\n' > "$DIST/overlay/metadata/layout.conf"
echo schiefer-dist > "$DIST/overlay/profiles/repo_name"
tar -C "$ROOT" --transform "s,^,schiefer-$V/,SH" \
    --exclude=build --exclude=.upstream-base --exclude=__pycache__ --exclude='vorschau*.png' --exclude=test --exclude=render.sh \
    --sort=name --owner=0 --group=0 --numeric-owner \
    -cJf "$DIST/schiefer-$V.tar.xz" "${FILES[@]}"

for d in "$ROOT"/packaging/x11-themes/*/; do
    pkg="$(basename "$d")"
    mkdir -p "$DIST/overlay/x11-themes/$pkg"
    cp "$d/metadata.xml" "$DIST/overlay/x11-themes/$pkg/"
    cp "$d/$pkg.ebuild" "$DIST/overlay/x11-themes/$pkg/$pkg-$V.ebuild"
done
# eigenständig: dist/ lässt sich auf einen anderen Rechner kopieren und dort installieren
cp "$ROOT/VERSION" "$DIST/"
install -m 0755 "$ROOT/tools/install-overlay.sh" "$DIST/"
echo "Tarball: $DIST/schiefer-$V.tar.xz ($(du -h "$DIST/schiefer-$V.tar.xz" | cut -f1))"
echo "Ebuilds: $(cd "$DIST/overlay" && find . -name '*.ebuild' | sort | tr '\n' ' ')"
