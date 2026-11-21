#!/bin/bash
# Fensterwechsler in der Testsitzung zeigen und fotografieren (als BR_SHELL_CMD von tools/screenshot.sh):
#   B=<Ordner für eikey und Bilder> BR_DATA_DIRS=<Ordner mit kwin-wayland/tabbox/schiefer> \
#   BR_SHELL_CMD="bash kwin/test/tab6.sh" tools/screenshot.sh out.png dolphin kwrite
# eikey wird bei Bedarf aus eikey.c gebaut (braucht libei). Bilder: $B/${OUTN:-tab}N.png
HERE="$(cd "$(dirname "$0")" && pwd)"
B="${B:?B=Ausgabeordner setzen}"
mkdir -p "$B"
[ -x "$B/eikey" ] || cc -O2 -o "$B/eikey" "$HERE/eikey.c" $(pkg-config --cflags --libs libei-1.0) || exit 1
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "${LAYOUT:-schiefer}"
qdbus6 org.kde.KWin /KWin reconfigure
sleep 1
python3 "$HERE/getfd.py" "$B/eikey" "${HOLD:-6}" "${TABS:-1}" &
for i in 1 2; do sleep 2; spectacle -b -n -f -o "$B/${OUTN:-tab}$i.png"; done
wait
