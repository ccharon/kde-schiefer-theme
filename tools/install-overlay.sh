#!/bin/bash
# Puts Schiefer into a local overlay (default: /var/db/repos/local, otherwise REPO=/path).
#
#   In the project:    tools/install-overlay.sh       packs dist/ first (make-dist.sh), then installs
#   Other machine:     copy dist/ (for example scp -r dist macbook:schiefer-dist), there:
#                      ~/schiefer-dist/install-overlay.sh
#
# Run as a normal user; the script calls itself through sudo. As root it puts the
# tarball into DISTDIR and the ebuilds into the overlay, runs `ebuild ... digest`, owner root:root,
# modes: files 644 (root read/write, everyone else read),
#        directories 755 (also searchable, or Portage could not read them).
set -euo pipefail
SELF="$(readlink -f "$0")"
HERE="$(dirname "$SELF")"
REPO="${REPO:-/var/db/repos/local}"

# Is the script inside a dist directory (tarball + overlay/ next to it) or in the project under tools/?
if [ -d "$HERE/overlay" ] && [ -f "$HERE/VERSION" ]; then
    DIST="$HERE"
else
    DIST="$(cd "$HERE/.." && pwd)/dist"
    if [ "$(id -u)" -ne 0 ]; then
        "$HERE/make-dist.sh"
    fi
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Continuing as root ..."
    exec sudo REPO="$REPO" "$SELF"
fi

V="$(cat "$DIST/VERSION")"
TARBALL="$DIST/schiefer-$V.tar.xz"
[ -f "$TARBALL" ] || { echo "Missing: $TARBALL. Run tools/make-dist.sh first." >&2; exit 1; }
[ -d "$REPO/profiles" ] || { echo "No overlay at $REPO" >&2; exit 1; }

DISTDIR="$(portageq distdir)"
install -o root -g root -m 0644 "$TARBALL" "$DISTDIR/"
echo "Tarball -> $DISTDIR/$(basename "$TARBALL")"

install -d -o root -g root -m 0755 "$REPO/x11-themes"
for src in "$DIST"/overlay/x11-themes/*/; do
    pkg="$(basename "$src")"
    case "$pkg" in schiefer|schiefer-*) ;; *) echo "skipped: $pkg"; continue ;; esac
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
echo "Done. Install with:  emerge -av x11-themes/schiefer"
