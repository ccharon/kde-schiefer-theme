#!/bin/bash
# Creates an *unmodified*, only renamed fork of the widget style from a Breeze source
# tarball (namespace Schiefer, plugin key Schiefer, config schieferrc).
#   tools/import-upstream.sh /var/cache/distfiles/breeze-6.7.6.tar.xz /target/directory
# Schiefer's own files (CMakeLists.txt, test/, render.sh) are not created; they belong to the fork.
set -euo pipefail
TARBALL="$1"; DEST="$2"
[ -e "$DEST" ] && { echo "$DEST already exists" >&2; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
tar -xJf "$TARBALL" -C "$TMP"
SRC=$(echo "$TMP"/breeze-*)
mkdir -p "$DEST"
cp -r "$SRC"/kstyle/* "$DEST"/
rm -rf "$DEST"/config "$DEST"/CMakeLists.txt
mkdir -p "$DEST"/common "$DEST"/kdeco
cp "$SRC"/libbreezecommon/breezeboxshadowrenderer.* "$DEST"/common/
cp "$SRC"/kdecoration/breezesettings.kcfgc "$SRC"/kdecoration/breezesettingsdata.kcfg "$DEST"/kdeco/
cd "$DEST"
grep -rl --include=*.cpp --include=*.h --include=*.kcfgc -e Breeze . | xargs sed -i -E \
  -e 's/\bnamespace Breeze\b/namespace Schiefer/g' -e 's/\bBreeze::/Schiefer::/g' \
  -e 's/\bBreezePrivate\b/SchieferPrivate/g' -e 's/^NameSpace=Breeze$/NameSpace=Schiefer/' \
  -e 's#QStringLiteral\("/BreezeStyle"\)#QStringLiteral("/SchieferStyle")#' \
  -e 's#QStringLiteral\("/BreezeDecoration"\)#QStringLiteral("/SchieferDecoration")#' \
  -e 's/org\.kde\.Breeze\.Style/org.kde.Schiefer.Style/g'
sed -i 's/<kcfgfile name="breezerc"\/>/<kcfgfile name="schieferrc"\/>/' breeze.kcfg kdeco/breezesettingsdata.kcfg
sed -i 's/QLatin1String("breeze")/QLatin1String("schiefer")/; s/QStringLiteral("Breeze"))/QStringLiteral("Schiefer"))/' breezestyleplugin.cpp
echo '{ "Keys": [ "Schiefer" ] }' > breeze.json
printf '[Misc]\nName=Schiefer\nComment=Motif/CDE-like widget style based on Breeze\n[KDE]\nWidgetStyle=Schiefer\n' > schiefer.themerc
rm -f breeze.themerc
basename "$SRC" > UPSTREAM_VERSION
echo "Fork erzeugt: $DEST ($(cat UPSTREAM_VERSION))"
