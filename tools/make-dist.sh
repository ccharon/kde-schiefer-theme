#!/bin/bash
# Packt Quelltarball und Ebuilds für das lokale Overlay (als normaler Benutzer ausführen).
#   tools/make-dist.sh      -> dist/schiefer-<VERSION>.tar.xz und dist/overlay/x11-themes/*
# Der Tarball ist reproduzierbar (feste Reihenfolge, Zeit und Besitzer): gleicher Inhalt = gleiche Prüfsumme.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
V="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$V" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Ungültige VERSION in $ROOT/VERSION: '$V'" >&2; exit 1; }
DIST="$ROOT/dist"

FILES=(
    VERSION UPSTREAM.md make_theme.py dither.py
    colors/Schiefer.colors
    gtk/Schiefer
    kdecoration/CMakeLists.txt kdecoration/schiefer.json kdecoration/retrodecoration.cpp kdecoration/retrodecoration.h
    kstyle
    lookandfeel
    plasma/make_plasma_theme.py
    wallpaper/apply.sh wallpaper/make_wallpaper_package.py wallpaper/tiles
    dock
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
    --exclude=build --exclude=.upstream-base --exclude='vorschau*.png' --exclude=test --exclude=render.sh \
    --sort=name --mtime='2026-01-01 00:00Z' --owner=0 --group=0 --numeric-owner \
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
