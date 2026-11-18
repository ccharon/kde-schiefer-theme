#!/bin/bash
# Startet ein verschachteltes KWin-Fenster mit der Schiefer-Dekoration.
# Nichts wird installiert; deine Konfiguration bleibt unberührt (eigenes Test-Konfigverzeichnis).
#   ./test-nested.sh            -> öffnet KWrite und Konsole im Testfenster
#   ./test-nested.sh dolphin    -> eigene Programme
HERE="$(cd "$(dirname "$0")" && pwd)"
CFG="${XDG_RUNTIME_DIR:-/tmp}/schiefer-test-config"
rm -rf "$CFG"; mkdir -p "$CFG"
cp ~/.config/kdeglobals "$CFG/kdeglobals" 2>/dev/null
# Farbschema Schiefer einmischen (alle Gruppen aus der .colors-Datei)
python3 - "$HERE/../colors/Schiefer.colors" "$CFG/kdeglobals" <<'PY'
import configparser, sys
src = configparser.ConfigParser(interpolation=None, strict=False); src.optionxform = str
src.read(sys.argv[1])
dst = configparser.ConfigParser(interpolation=None, strict=False); dst.optionxform = str
dst.read(sys.argv[2])
for sec in src.sections():
    if sec == "General": continue
    if not dst.has_section(sec): dst.add_section(sec)
    for k, v in src.items(sec): dst.set(sec, k, v)
if not dst.has_section("General"): dst.add_section("General")
dst.set("General", "ColorScheme", "Schiefer")
with open(sys.argv[2], "w") as f: dst.write(f, space_around_delimiters=False)
PY
cat > "$CFG/kwinrc" <<CFG
[org.kde.kdecoration2]
library=schiefer
theme=
ButtonsOnLeft=M
ButtonsOnRight=IAX
CFG
export QT_PLUGIN_PATH="$HERE/build/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export XDG_CONFIG_HOME="$CFG"
APPS=("$@"); [ ${#APPS[@]} -eq 0 ] && APPS=(kwrite konsole)
exec kwin_wayland --width 1200 --height 800 --no-lockscreen --exit-with-session "${APPS[0]}" "${APPS[@]:1}"
