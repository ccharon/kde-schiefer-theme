/*
 * Gesicht der System-Schublade: die aktiven Einträge des Systemabschnitts als Symbolraster
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
    required property var model     // gefiltertes Systray-Modell (nur aktive Einträge)
    signal openDrawer()

    readonly property int count: Math.min(model ? model.count : 0, 4)
    readonly property int columns: count <= 1 ? 1 : 2
    readonly property int rows: count <= 2 ? 1 : 2
    readonly property int cell: Math.floor(Math.min(width / columns, height / Math.max(rows, columns)))

    // Klicks neben die Symbole öffnen die Schublade
    MouseArea { anchors.fill: parent; onClicked: face.openDrawer() }

    // ohne aktive Einträge: allgemeines Systemsymbol
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
