#!/bin/bash
# Isoliertes Bildschirmfoto (eigener D-Bus): dbus-run-session -- ./screenshot.sh build/plugins out.png ../colors/Schiefer.colors
# $1 = Plugin-Dir, $2 = Ausgabe-PNG, $3 = colors-Datei
CFG=$(mktemp -d)
cp ~/.config/kdeglobals $CFG/kdeglobals
python3 -I - "$3" "$CFG/kdeglobals" <<'PY'
import configparser, sys
s=configparser.ConfigParser(interpolation=None,strict=False); s.optionxform=str; s.read(sys.argv[1])
d=configparser.ConfigParser(interpolation=None,strict=False); d.optionxform=str; d.read(sys.argv[2])
for sec in s.sections():
    if sec=="General": continue
    if not d.has_section(sec): d.add_section(sec)
    for k,v in s.items(sec): d.set(sec,k,v)
with open(sys.argv[2],"w") as f: d.write(f,space_around_delimiters=False)
PY
printf '[org.kde.kdecoration2]\nlibrary=schiefer\ntheme=\nButtonsOnLeft=M\nButtonsOnRight=IAX\n[Plugins]\nblurEnabled=false\n' > $CFG/kwinrc
export XDG_CONFIG_HOME=$CFG QT_PLUGIN_PATH="$1"
kwin_wayland --virtual --width 1000 --height 640 --socket retroshot --no-lockscreen >/dev/null 2>&1 &
K=$!
sleep 3
WAYLAND_DISPLAY=retroshot QT_QPA_PLATFORM=wayland kwrite >/dev/null 2>&1 &
sleep 2
WAYLAND_DISPLAY=retroshot QT_QPA_PLATFORM=wayland konsole >/dev/null 2>&1 &
sleep 4
WAYLAND_DISPLAY=retroshot QT_QPA_PLATFORM=wayland spectacle -b -n -f -o "$2" 2>&1 | tail -3
sleep 2
kill %2 %3 2>/dev/null; kill $K 2>/dev/null; wait 2>/dev/null
rm -rf $CFG
