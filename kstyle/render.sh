#!/bin/bash
# Renders the test gallery offscreen with the Schiefer style and color scheme.
#   ./render.sh out.png [style] [gallery arguments ...]   (style: Schiefer (default) or Breeze for comparison)
#   SCHIEFERRC=file ./render.sh ...  -> use this schieferrc (to test options); defaults apply otherwise
#   gallery arguments: --menu view (radio items in the menu), --busy out2.png (see test/gallery.cpp)
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/gallery.png}"; STYLE="${2:-Schiefer}"
CFG=$(mktemp -d)
cp ~/.config/kdeglobals "$CFG/kdeglobals" 2>/dev/null
[ -n "${SCHIEFERRC:-}" ] && cp "$SCHIEFERRC" "$CFG/schieferrc"
python3 -I - "${COLORS:-$HERE/../colors/Schiefer.colors}" "$CFG/kdeglobals" <<'PY'
import configparser, sys
s=configparser.ConfigParser(interpolation=None,strict=False); s.optionxform=str; s.read(sys.argv[1])
d=configparser.ConfigParser(interpolation=None,strict=False); d.optionxform=str; d.read(sys.argv[2])
for sec in s.sections():
    if sec=="General": continue
    if not d.has_section(sec): d.add_section(sec)
    for k,v in s.items(sec): d.set(sec,k,v)
if not d.has_section("KDE"): d.add_section("KDE")
d.set("KDE","widgetStyle","Schiefer")
with open(sys.argv[2],"w") as f: d.write(f,space_around_delimiters=False)
PY
XDG_CONFIG_HOME="$CFG" QT_PLUGIN_PATH="$HERE/build/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" \
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde \
"$HERE/build/bin/retrogallery" -style "$STYLE" --grab "$OUT" "${@:3}" 2>&1 | grep -v "^qt.qpa\|propagateSizeHints" | head -5
rm -rf "$CFG"
echo "$OUT"
