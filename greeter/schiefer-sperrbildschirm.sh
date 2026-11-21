# Schiefer: Kopie der Plasma-Shell mit Schiefer-Sperrbildschirm nach Updates auffrischen
# (nur wenn „schiefer-config sperrbildschirm an“ sie angelegt hat). Wird von startplasma gesourct.
if [ -e "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells/org.kde.plasma.desktop/.schiefer-sperrbildschirm" ] \
   && command -v schiefer-config >/dev/null 2>&1; then
    schiefer-config sperrbildschirm-auffrischen >/dev/null 2>&1
fi
