#!/bin/bash
# Packs the source tarball and the ebuilds (run as a normal user).
#   tools/make-dist.sh      -> dist/schiefer-<VERSION>.tar.xz und dist/overlay/x11-themes/*
# The tarball is reproducible (fixed order and owner): unchanged files give the same checksum.
# Modification times stay real on purpose: Qt discards its QML cache (~/.cache/*/qmlcache) only when the
# source file time changes. With a fixed time the old QML code would keep running after an update.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
V="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$V" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Invalid VERSION in $ROOT/VERSION: '$V'" >&2; exit 1; }
DIST="$ROOT/dist"

FILES=(
    VERSION README.md UPSTREAM.md LICENSE LICENSES make_theme.py dither.py
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
    plymouth
    konsole/Schiefer.colorscheme konsole/Schiefer.profile konsole/mc-schiefer.ini konsole/make_konsole.py
)
# check first, then delete dist/
for f in "${FILES[@]}" packaging/x11-themes tools/install-overlay.sh; do
    [ -e "$ROOT/$f" ] || { echo "Fehlt: $f" >&2; exit 1; }
done
rm -rf "$DIST"
# layout.conf/repo_name: lets `ebuild` build the packages straight from dist/overlay (test without root)
mkdir -p "$DIST/overlay/metadata" "$DIST/overlay/profiles"
printf 'masters = gentoo\nthin-manifests = true\n' > "$DIST/overlay/metadata/layout.conf"
echo schiefer-dist > "$DIST/overlay/profiles/repo_name"
tar -C "$ROOT" --transform "s,^,schiefer-$V/,SH" \
    --exclude=build --exclude=.upstream-base --exclude=__pycache__ --exclude='preview*.png' --exclude=comparison.png --exclude=test --exclude=render.sh \
    --sort=name --owner=0 --group=0 --numeric-owner \
    -cJf "$DIST/schiefer-$V.tar.xz" "${FILES[@]}"

for d in "$ROOT"/packaging/x11-themes/*/; do
    pkg="$(basename "$d")"
    mkdir -p "$DIST/overlay/x11-themes/$pkg"
    cp "$d/metadata.xml" "$DIST/overlay/x11-themes/$pkg/"
    cp "$d/$pkg.ebuild" "$DIST/overlay/x11-themes/$pkg/$pkg-$V.ebuild"
done
# self-contained: dist/ can be copied to another machine and installed there
cp "$ROOT/VERSION" "$DIST/"
install -m 0755 "$ROOT/tools/install-overlay.sh" "$DIST/"
echo "Tarball: $DIST/schiefer-$V.tar.xz ($(du -h "$DIST/schiefer-$V.tar.xz" | cut -f1))"
echo "Ebuilds: $(cd "$DIST/overlay" && find . -name '*.ebuild' | sort | tr '\n' ' ')"
