/*
 * Tints the Plasma frames in the item's own window with the front panel color (option
 * frontpanel-color): in a panel its background (widgets/panel-background from the
 * shell's Panel.qml), in a popup its background (dialogs/background). This way no
 * areas in the window color remain between and next to the dock widgets.
 * With the option off it resets the frames. Invisible and takes no space
 * (layouts and positioners skip invisible items).
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

    // Panel and popup create their frames gradually (the popup sets imagePath when shown),
    // so tint right away and once more after a short pause
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
