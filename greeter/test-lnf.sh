#!/bin/bash
# Captures the splash screen or the logout dialog in isolation (own KWin session):
#   greeter/test-lnf.sh splash out.png        ksplashqml --test (stages advance by themselves in test mode)
#   greeter/test-lnf.sh logout out.png        ksmserver-logout-greeter --windowed
# The global theme package is copied with symlinks resolved (KPackage rejects symlinks leaving the package).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAS="$1"; OUT="$(realpath -m "$2")"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plasma/look-and-feel"
cp -rL "$ROOT/lookandfeel/schiefer.desktop" "$T/plasma/look-and-feel/"
case "$WAS" in
    splash) CMD="ksplashqml --test --window schiefer.desktop" ;;
    logout) CMD="/usr/libexec/ksmserver-logout-greeter --windowed --lookandfeel schiefer.desktop" ;;
    *) echo "splash|logout" >&2; exit 1 ;;
esac
BR_DATA_DIRS="$T" "$ROOT/tools/screenshot.sh" "$OUT" "$CMD"
