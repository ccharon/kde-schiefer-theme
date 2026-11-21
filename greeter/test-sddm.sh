#!/bin/bash
# Offscreen-Bild des SDDM-Themas (ohne Fenster): greeter/test-sddm.sh out.png [BREITE HÖHE] [qml-Zusatz]
#   SCHIEFER_TEST_STAGE=user|pass|busy  SCHIEFER_TEST_MENU=1  SCHIEFER_TEST_MSG=1
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(realpath -m "$1")"; W="${2:-1600}"; H="${3:-1000}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp -rL "$HERE/sddm/schiefer/." "$T/"
cat > "$T/t.qml" <<QML
import QtQuick
Item { id: r; width: $W; height: $H
  Loader { id: l; width: $W; height: $H; source: "Main.qml" }
  Timer { interval: 1500; running: true; onTriggered: {
      const m = l.item; const st = "${SCHIEFER_TEST_STAGE:-}";
      if (st) { m.stage = st; m.userName = "christian"; }
      if ("${SCHIEFER_TEST_MSG:-}") m.message = "Anmeldung fehlgeschlagen. Bitte erneut versuchen.";
      if ("${SCHIEFER_TEST_MENU:-}") m.openOptions();
  } }
  Timer { interval: 2500; running: true; onTriggered: l.grabToImage(res => { res.saveToFile("$OUT"); Qt.quit(); }) } }
QML
sed -i 's/MainScript=Main.qml/MainScript=t.qml/' "$T/metadata.desktop"
QT_QPA_PLATFORM=offscreen timeout 15 sddm-greeter-qt6 --test-mode --theme "$T" 2>&1 | grep -vE "Socket error|^Reading|portal|High-DPI|Loading|Adding view" || true
