#!/bin/bash
# Builds Plymouth 22 for test-plymouth.sh into a user directory (nothing is installed system-wide):
# with tracing, and with an x11 renderer that redraws right away (under Xwayland no X event wakes
# its event loop, so the window would keep showing the first frame).
#   plymouth/build-test-plymouth.sh <prefix> [plymouth-22.*.tar.xz]
set -eu
PREFIX="$(realpath -m "$1")"
TARBALL="${2:-$(ls /var/cache/distfiles/plymouth-22.*.tar.xz 2>/dev/null | sort -V | tail -n1)}"
[ -r "$TARBALL" ] || { echo "Plymouth 22 tarball not found, pass it as second argument" >&2; exit 1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
tar -C "$W" -xf "$TARBALL"
cd "$W"/plymouth-*/
python3 - <<'PY'
p = "src/plugins/renderers/x11/plugin.c"
s = open(p).read()
old = "        ply_region_clear (updated_region);\n}"
assert old in s, "x11 renderer changed, adapt build-test-plymouth.sh"
s = s.replace(old, "        ply_region_clear (updated_region);\n"
                   "        while (gtk_events_pending ())\n                gtk_main_iteration ();\n}", 1)
open(p, "w").write(s)
PY
./configure --prefix="$PREFIX" --enable-tracing --enable-gtk --enable-pango --enable-drm --without-udev \
    --disable-systemd-integration --disable-documentation --without-system-root-install --with-logo=/dev/null >/dev/null
make -j"$(nproc)" >/dev/null
make install >/dev/null
mkdir -p "$PREFIX/share/plymouth/themes"
echo "PLY_PREFIX=$PREFIX"
