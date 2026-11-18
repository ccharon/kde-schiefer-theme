#!/bin/bash
# Bringt Schiefer ins lokale Overlay (Standard: /var/db/repos/local, anders: REPO=/pfad).
#
#   Im Projekt:        tools/install-overlay.sh       packt erst dist/ (make-dist.sh), dann Installation
#   Anderer Rechner:   dist/ kopieren (z. B. scp -r dist macbook:schiefer-dist), dort:
#                      ~/schiefer-dist/install-overlay.sh
#
# Als normaler Benutzer aufrufen; das Skript ruft sich per sudo selbst auf. Als root:
# Tarball nach DISTDIR, Ebuilds ins Overlay, `ebuild … digest`, Besitzer root:root,
# Rechte: Dateien 644 (root lesen/schreiben, alle anderen lesen),
#         Verzeichnisse 755 (zusätzlich betretbar – sonst könnte Portage sie nicht lesen).
set -euo pipefail
SELF="$(readlink -f "$0")"
HERE="$(dirname "$SELF")"
REPO="${REPO:-/var/db/repos/local}"

# Liegt das Skript in einem dist-Ordner (Tarball + overlay/ daneben) oder im Projekt unter tools/?
if [ -d "$HERE/overlay" ] && [ -f "$HERE/VERSION" ]; then
    DIST="$HERE"
else
    DIST="$(cd "$HERE/.." && pwd)/dist"
    if [ "$(id -u)" -ne 0 ]; then
        "$HERE/make-dist.sh"
    fi
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Weiter als root …"
    exec sudo REPO="$REPO" "$SELF"
fi

V="$(cat "$DIST/VERSION")"
TARBALL="$DIST/schiefer-$V.tar.xz"
[ -f "$TARBALL" ] || { echo "Fehlt: $TARBALL – erst tools/make-dist.sh ausführen" >&2; exit 1; }
[ -d "$REPO/profiles" ] || { echo "Kein Overlay unter $REPO" >&2; exit 1; }

DISTDIR="$(portageq distdir)"
install -o root -g root -m 0644 "$TARBALL" "$DISTDIR/"
echo "Tarball -> $DISTDIR/$(basename "$TARBALL")"

install -d -o root -g root -m 0755 "$REPO/x11-themes"
for src in "$DIST"/overlay/x11-themes/*/; do
    pkg="$(basename "$src")"
    case "$pkg" in schiefer|schiefer-*) ;; *) echo "übersprungen: $pkg"; continue ;; esac
    dest="$REPO/x11-themes/$pkg"
    rm -rf "$dest"
    cp -r "$src" "$dest"
    rm -f "$dest/Manifest"
    ebuild "$dest/$pkg-$V.ebuild" digest
    chown -R root:root "$dest"
    find "$dest" -type d -exec chmod 0755 {} +
    find "$dest" -type f -exec chmod 0644 {} +
    echo "Overlay  -> $dest"
done

echo
echo "Fertig. Installieren mit:  emerge -av x11-themes/schiefer"
