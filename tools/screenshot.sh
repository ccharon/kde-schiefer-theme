#!/bin/bash
# Isoliertes Bildschirmfoto aller Schiefer-Teile (Deko + Qt-Stil + Farbschema) mit echten Programmen.
# Läuft in einer eigenen KWin-Sitzung mit eigenem D-Bus; die echte Sitzung bleibt unberührt.
#   tools/screenshot.sh out.png [programm ...]      (Standard: dolphin kwrite)
#   Programm "plasmashell" startet die Arbeitsfläche mit dem Plasma-Theme aus plasma/schiefer.
#   GTK-Programme nutzen das Theme gtk/Schiefer (BR_GTK_THEME=Breeze zum Vergleich).
#   BR_SHELL_CMD="qdbus6 org.kde.plasmashell /PlasmaShell activateLauncherMenu" führt danach einen Befehl aus.
#   BR_DATA_DIRS=a:b stellt zusätzliche Datenverzeichnisse voran (z. B. wallpaper/plugin/build/data für das Hintergrund-Plugin).
#   BR_SCALE=1.5 skaliert die virtuelle Ausgabe (fraktionale Skalierung testen; BR_WIDTH/BR_HEIGHT bleiben logisch, das Bild wird größer).
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
CFG="" DATA="" HOMEDATA="" K=""
PIDS=()
# Aufräumen auch bei Abbruch (timeout schickt TERM an die ganze Prozessgruppe, Strg+C INT)
cleanup() {
    trap - EXIT INT TERM
    [ ${#PIDS[@]} -gt 0 ] && kill "${PIDS[@]}" 2>/dev/null
    sleep 1
    [ -n "$K" ] && kill "$K" 2>/dev/null
    sleep 1
    kill -9 ${PIDS[@]+"${PIDS[@]}"} $K 2>/dev/null
    # alles beenden, was am Bus dieser Testsitzung hängt (vom Bus gestartete Dienste
    # überleben sonst dbus-run-session und halten z. B. die Aktivitäten-Datenbank offen)
    for p in $(pgrep -u "$(id -u)"); do
        [ "$p" = "$$" ] && continue
        tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -qxF "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" && kill "$p" 2>/dev/null
    done
    sleep 1
    rm -rf ${CFG:+"$CFG"} ${DATA:+"$DATA"} ${HOMEDATA:+"$HOMEDATA"}
}
trap cleanup EXIT
trap 'exit 130' INT TERM
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
# Schemaname passend zur Datei (Leser der Gruppe [Schiefer], z. B. das Dock, öffnen color-schemes/<Name>.colors)
import os.path
if not d.has_section("General"): d.add_section("General")
d.set("General","ColorScheme",os.path.splitext(os.path.basename(sys.argv[1]))[0])
if not d.has_section("KDE"): d.add_section("KDE")
d.set("KDE","widgetStyle","Schiefer")
if not d.has_section("Icons"): d.add_section("Icons")
import os
if os.path.isdir(os.path.expanduser("~/.local/share/icons/schiefer")) or os.path.isdir("/usr/share/icons/schiefer"): d.set("Icons","Theme","schiefer")
if os.environ.get("BR_ICON_DIR"): d.set("Icons","Theme","schiefer-test")
with open(sys.argv[2],"w") as f: d.write(f,space_around_delimiters=False)
PY
printf '[org.kde.kdecoration2]\nlibrary=schiefer\ntheme=\nButtonsOnLeft=M\nButtonsOnRight=IAX\n' > "$CFG/kwinrc"
# BR_DESKTOPS=4: Anzahl virtueller Arbeitsflächen (zwei Reihen)
[ -n "${BR_DESKTOPS:-}" ] && printf '[Desktops]\nNumber=%s\nRows=2\n' "$BR_DESKTOPS" >> "$CFG/kwinrc"
printf '[Theme]\nname=%s\n' "${BR_PLASMA_THEME:-schiefer}" > "$CFG/plasmarc"   # BR_PLASMA_THEME=default: Breeze zum Vergleich
DATA=$(mktemp -d); mkdir -p "$DATA/plasma/desktoptheme"
mkdir -p "$DATA/color-schemes"; ln -s "$(realpath "${BR_COLORS:-$ROOT/colors/Schiefer.colors}")" "$DATA/color-schemes/"
ln -s "$ROOT/plasma/schiefer" "$DATA/plasma/desktoptheme/schiefer"
# BR_ICON_DIR=<Ordner>: dieses Icon-Theme verwenden (z. B. frisch erzeugt von make_theme.py); eigener Name,
# weil KDE gleichnamige Themes aus allen Datenverzeichnissen zusammenführt (das installierte gewänne)
if [ -n "${BR_ICON_DIR:-}" ]; then mkdir -p "$DATA/icons"; ln -s "$(realpath "$BR_ICON_DIR")" "$DATA/icons/schiefer-test"; fi
# eigene Daten-/Zustandsverzeichnisse: Dienste der Testsitzung (kactivitymanagerd, ksecretd …)
# sollen nicht die Datenbanken der echten Sitzung öffnen; ~/.local/share bleibt lesbar
HOMEDATA=$(mktemp -d)
export XDG_DATA_DIRS="$DATA:${BR_DATA_DIRS:+$BR_DATA_DIRS:}$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_DATA_HOME="$HOMEDATA/data" XDG_STATE_HOME="$HOMEDATA/state" XDG_CACHE_HOME="$HOMEDATA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
export XDG_CONFIG_HOME="$CFG"
# GTK: colors.css wie kde-gtk-config, Theme aus gtk/Schiefer (Vergleich: BR_GTK_THEME=Breeze)
mkdir -p "$DATA/themes" "$CFG/gtk-3.0" "$CFG/gtk-4.0"
ln -s "$ROOT/gtk/Schiefer" "$DATA/themes/Schiefer"
ICONS=breeze; { [ -d ~/.local/share/icons/schiefer ] || [ -d /usr/share/icons/schiefer ]; } && ICONS=schiefer; [ -n "${BR_ICON_DIR:-}" ] && ICONS=schiefer-test
for v in gtk-3.0 gtk-4.0; do
    QT_QPA_PLATFORM=offscreen "$ROOT/gtk/tools/build/gtkcolors" > "$CFG/$v/colors.css" 2>/dev/null
    printf "@import 'colors.css';\n" > "$CFG/$v/gtk.css"
    printf '[Settings]\ngtk-font-name=Noto Sans, 10\ngtk-icon-theme-name=%s\n' "$ICONS" > "$CFG/$v/settings.ini"
done
export GTK_THEME="${BR_GTK_THEME:-Schiefer}"
# Dienste, die der Test-D-Bus selbst startet (z. B. das Portal), sollen die Testkonfiguration lesen.
# Ohne --systemd: betrifft nur den privaten Bus dieser Sitzung, nicht die echte Sitzung.
dbus-update-activation-environment XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_DIRS QT_PLUGIN_PATH QT_STYLE_OVERRIDE GTK_THEME
export QT_PLUGIN_PATH="$ROOT/kdecoration/build/plugins:$ROOT/kstyle/build/plugins:$ROOT/dock/build/bin${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_STYLE_OVERRIDE=Schiefer
# eigener Socket je Lauf: parallele Testläufe kommen sich nicht in die Quere
SOCK="brshot-$$"
kwin_wayland --virtual --width ${BR_WIDTH:-1280} --height ${BR_HEIGHT:-800} --scale "${BR_SCALE:-1}" --socket "$SOCK" --no-lockscreen >/dev/null 2>&1 &
K=$!
sleep 3
# --scale vergrößert nur den virtuellen Bildschirm; die Skalierung selbst setzt erst die Ausgabekonfiguration
[ -n "${BR_SCALE:-}" ] && { WAYLAND_DISPLAY=$SOCK kscreen-doctor "output.Virtual-0.scale.$BR_SCALE" >/dev/null 2>&1; sleep 1; }
LOG="${BR_LOG:-/dev/null}"
for a in "${APPS[@]}"; do WAYLAND_DISPLAY=$SOCK QT_QPA_PLATFORM=wayland $a >>"$LOG" 2>&1 & PIDS+=($!); sleep 3; done
sleep 3
[[ " ${APPS[*]} " == *" plasmashell "* ]] && sleep 6
[ -n "${BR_SHELL_CMD:-}" ] && { WAYLAND_DISPLAY=$SOCK QT_QPA_PLATFORM=wayland bash -c "$BR_SHELL_CMD" >/dev/null 2>&1; sleep 3; }
WAYLAND_DISPLAY=$SOCK QT_QPA_PLATFORM=wayland spectacle -b -n -f -o "$OUT" >/dev/null 2>&1
sleep 1
# Aufräumen übernimmt cleanup (trap EXIT)
