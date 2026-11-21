/*
 * Face of the system drawer: the active system tray entries as an icon grid
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: face

    required property var tray      // TrayBridge
    required property var model     // filtered system tray model (active entries only)
    signal openDrawer()

    readonly property int count: Math.min(model ? model.count : 0, 4)
    readonly property int columns: count <= 1 ? 1 : 2
    readonly property int rows: count <= 2 ? 1 : 2
    readonly property int cell: Math.floor(Math.min(width / columns, height / Math.max(rows, columns)))

    // clicks next to the icons open the drawer
    MouseArea { anchors.fill: parent; onClicked: face.openDrawer() }

    // without active entries: generic system icon
    Kirigami.Icon {
        anchors.fill: parent
        visible: face.count === 0
        source: "preferences-system"
    }

    Grid {
        anchors.centerIn: parent
        columns: face.columns
        Repeater {
            model: face.model
            delegate: TrayItemIcon {
                width: face.cell
                height: face.cell
                visible: index < 4
                tray: face.tray
                iconMargin: Math.round(face.cell * 0.08)
            }
        }
    }
}
