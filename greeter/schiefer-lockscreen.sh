# Schiefer: refresh the Plasma shell copy with the Schiefer lock screen after updates.
# Sourced by startplasma; acts only if "schiefer-config lockscreen on" created the copy.
d="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells/org.kde.plasma.desktop"
if { [ -e "$d/.schiefer-lockscreen" ] || [ -e "$d/.schiefer-sperrbildschirm" ]; } \
   && command -v schiefer-config >/dev/null 2>&1; then
    schiefer-config lockscreen-refresh >/dev/null 2>&1
fi
unset d
