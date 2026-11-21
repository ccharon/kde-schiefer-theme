/*
 * Färbt die Plasma-Rahmen im eigenen Fenster in der Frontpanel-Farbe (Schalter
 * frontpanel-farbe): in der Leiste deren Hintergrund (widgets/panel-background aus
 * Panel.qml der Shell), in einem Popup dessen Hintergrund (dialogs/background). So
 * bleiben zwischen und neben den Dock-Widgets keine Flächen in der Fensterfarbe stehen.
 * Ist der Schalter aus, setzt es die Rahmen zurück. Unsichtbar, nimmt keinen Platz ein
 * (Layouts und Positionierer überspringen unsichtbare Items).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Window

Item {
    id: tint
    visible: false
    width: 0
    height: 0

    readonly property var win: tint.Window.window

    function apply() {
        Scheme.tintFrames(tint);
    }

    // Leiste und Popup legen ihre Rahmen erst nach und nach an (imagePath setzt das Popup
    // beim Zeigen); deshalb sofort und nach kurzer Ruhe noch einmal
    Timer {
        id: later
        interval: 200
        running: true
        onTriggered: tint.apply()
    }
    onWinChanged: { apply(); later.restart(); }
    Connections {
        target: Scheme
        function onChanged() { tint.apply(); }
    }
    Connections {
        target: tint.win
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (tint.win && tint.win.visible) {
                tint.apply();
                later.restart();
            }
        }
    }
}
