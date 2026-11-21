#!/bin/bash
# Startbild bzw. Abmeldedialog isoliert fotografieren (eigene KWin-Sitzung):
#   greeter/test-lnf.sh splash out.png        ksplashqml --test (Stufen laufen im Testmodus von selbst)
#   greeter/test-lnf.sh logout out.png        ksmserver-logout-greeter --windowed
# Das Design-Paket wird dereferenziert kopiert (KPackage lehnt Symlinks aus dem Paket hinaus ab).
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
