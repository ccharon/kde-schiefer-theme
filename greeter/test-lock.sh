#!/bin/bash
# Captures the lock screen in isolation (own KWin session, kscreenlocker_greet --testing):
#   greeter/test-lock.sh out.png [dialog]     "dialog" shows the password panel right away
# Builds the shell copy with schiefer-config in a test directory; the real session stays untouched.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(realpath -m "$1")"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp -rL "$ROOT/greeter/lockscreen" "$T/lock"
[ "${2:-}" = dialog ] && sed -i 's/SchieferLock { anchors.fill: parent }/SchieferLock { anchors.fill: parent; testShowDialog: true }/' "$T/lock/LockScreen.qml"
# Gentoo installs helpers to /usr/libexec, Debian to /usr/lib/<triplet>/libexec.
GREET=$(ls /usr/libexec/kscreenlocker_greet /usr/lib/*/libexec/kscreenlocker_greet 2>/dev/null | head -1)
[ -n "$GREET" ] || { echo "kscreenlocker_greet not found" >&2; exit 1; }
mkdir -p "$T/data"
XDG_DATA_HOME="$T/data" SCHIEFER_LOCKSCREEN_DIR="$T/lock" XDG_DATA_DIRS=/usr/share \
    python3 "$ROOT/tools/schiefer-config" lockscreen on >/dev/null
BR_DATA_DIRS="$T/data" "$ROOT/tools/screenshot.sh" "$OUT" "$GREET --testing"
