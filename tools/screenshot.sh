#!/bin/bash
# Isoliertes Bildschirmfoto aller Schiefer-Teile (Deko + Qt-Stil + Farbschema) mit echten Programmen.
# Läuft in einer eigenen KWin-Sitzung mit eigenem D-Bus; die echte Sitzung bleibt unberührt.
#   tools/screenshot.sh out.png [programm ...]      (Standard: dolphin kwrite)
#   Programm "plasmashell" startet die Arbeitsfläche mit dem Plasma-Theme aus plasma/schiefer.
#   GTK-Programme nutzen das Theme gtk/Schiefer (BR_GTK_THEME=Breeze zum Vergleich).
#   BR_SHELL_CMD="qdbus6 org.kde.plasmashell /PlasmaShell activateLauncherMenu" führt danach einen Befehl aus.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(realpath -m "${1:-/tmp/schiefer.png}")"; shift || true
APPS=("$@"); [ ${#APPS[@]} -eq 0 ] && APPS=(dolphin kwrite)
if [ -z "${SCHIEFER_INNER:-}" ]; then
    # Hintergrunddienste der Testsitzung erben sonst stdout und halten Pipes offen
    SCHIEFER_INNER=1 timeout 150 dbus-run-session -- "$0" "$OUT" "${APPS[@]}" >/dev/null 2>&1 </dev/null
    [ -s "$OUT" ] && echo "$OUT" || { echo "kein Bild erzeugt" >&2; exit 1; }
    exit 0
fi
CFG=$(mktemp -d)
cp ~/.config/kdeglobals "$CFG/kdeglobals" 2>/dev/null
python3 -I - "${BR_COLORS:-$ROOT/colors/Schiefer.colors}" "$CFG/kdeglobals" <<'PY'
import configparser, sys
s=configparser.ConfigParser(interpolation=None,strict=False); s.optionxform=str; s.read(sys.argv[1])
d=configparser.ConfigParser(interpolation=None,strict=False); d.optionxform=str; d.read(sys.argv[2])
for sec in list(d.sections()):
    if sec.startswith("Colors:") and not s.has_section(sec): d.remove_section(sec)
for sec in s.sections():
    if sec=="General": continue
    if not d.has_section(sec): d.add_section(sec)
    for k,v in s.items(sec): d.set(sec,k,v)
if not d.has_section("KDE"): d.add_section("KDE")
d.set("KDE","widgetStyle","Schiefer")
if not d.has_section("Icons"): d.add_section("Icons")
import os
if os.path.isdir(os.path.expanduser("~/.local/share/icons/schiefer")): d.set("Icons","Theme","schiefer")
with open(sys.argv[2],"w") as f: d.write(f,space_around_delimiters=False)
PY
printf '[org.kde.kdecoration2]\nlibrary=schiefer\ntheme=\nButtonsOnLeft=M\nButtonsOnRight=IAX\n' > "$CFG/kwinrc"
printf '[Theme]\nname=schiefer\n' > "$CFG/plasmarc"
DATA=$(mktemp -d); mkdir -p "$DATA/plasma/desktoptheme"
ln -s "$ROOT/plasma/schiefer" "$DATA/plasma/desktoptheme/schiefer"
export XDG_DATA_DIRS="$DATA:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CONFIG_HOME="$CFG"
# GTK: colors.css wie kde-gtk-config, Theme aus gtk/Schiefer (Vergleich: BR_GTK_THEME=Breeze)
mkdir -p "$DATA/themes" "$CFG/gtk-3.0" "$CFG/gtk-4.0"
ln -s "$ROOT/gtk/Schiefer" "$DATA/themes/Schiefer"
ICONS=breeze; [ -d ~/.local/share/icons/schiefer ] && ICONS=schiefer
for v in gtk-3.0 gtk-4.0; do
    QT_QPA_PLATFORM=offscreen "$ROOT/gtk/tools/build/gtkcolors" > "$CFG/$v/colors.css" 2>/dev/null
    printf "@import 'colors.css';\n" > "$CFG/$v/gtk.css"
    printf '[Settings]\ngtk-font-name=Noto Sans, 10\ngtk-icon-theme-name=%s\n' "$ICONS" > "$CFG/$v/settings.ini"
done
export GTK_THEME="${BR_GTK_THEME:-Schiefer}"
# Dienste, die der Test-D-Bus selbst startet (z. B. das Portal), sollen die Testkonfiguration lesen.
# Ohne --systemd: betrifft nur den privaten Bus dieser Sitzung, nicht die echte Sitzung.
dbus-update-activation-environment XDG_CONFIG_HOME XDG_DATA_DIRS QT_PLUGIN_PATH QT_STYLE_OVERRIDE GTK_THEME
export QT_PLUGIN_PATH="$ROOT/kdecoration/build/plugins:$ROOT/kstyle/build/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_STYLE_OVERRIDE=Schiefer
kwin_wayland --virtual --width 1280 --height 800 --socket brshot --no-lockscreen >/dev/null 2>&1 &
K=$!
sleep 3
PIDS=()
for a in "${APPS[@]}"; do WAYLAND_DISPLAY=brshot QT_QPA_PLATFORM=wayland $a >/dev/null 2>&1 & PIDS+=($!); sleep 3; done
sleep 3
[[ " ${APPS[*]} " == *" plasmashell "* ]] && sleep 6
[ -n "${BR_SHELL_CMD:-}" ] && { WAYLAND_DISPLAY=brshot QT_QPA_PLATFORM=wayland bash -c "$BR_SHELL_CMD" >/dev/null 2>&1; sleep 3; }
WAYLAND_DISPLAY=brshot QT_QPA_PLATFORM=wayland spectacle -b -n -f -o "$OUT" >/dev/null 2>&1
sleep 1
kill "${PIDS[@]}" 2>/dev/null; sleep 1; kill $K 2>/dev/null; sleep 1; kill -9 "${PIDS[@]}" $K 2>/dev/null
rm -rf "$CFG" "$DATA"
