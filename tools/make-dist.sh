#!/bin/bash
# Packt Quelltarball und Ebuilds für das lokale Overlay (als normaler Benutzer ausführen).
#   tools/make-dist.sh      -> dist/schiefer-<VERSION>.tar.xz und dist/overlay/x11-themes/*
# Der Tarball ist reproduzierbar (feste Reihenfolge, Zeit und Besitzer): gleicher Inhalt = gleiche Prüfsumme.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
V="$(cat "$ROOT/VERSION")"
DIST="$ROOT/dist"
rm -rf "$DIST"
mkdir -p "$DIST/overlay/metadata" "$DIST/overlay/profiles"
# nur damit `ebuild` die Pakete auch direkt aus dist/overlay bauen kann (Test ohne root)
printf 'masters = gentoo\nthin-manifests = true\n' > "$DIST/overlay/metadata/layout.conf"
echo schiefer-dist > "$DIST/overlay/profiles/repo_name"

FILES=(
    VERSION UPSTREAM.md make_theme.py
    colors/Schiefer.colors
    gtk/Schiefer
    kdecoration/CMakeLists.txt kdecoration/schiefer.json kdecoration/retrodecoration.cpp kdecoration/retrodecoration.h
    kstyle
    lookandfeel
    plasma/make_plasma_theme.py
    wallpaper/apply.sh wallpaper/make_wallpaper_package.py wallpaper/tiles
)
tar -C "$ROOT" --transform "s,^,schiefer-$V/," \
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
