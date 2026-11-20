/*
 * Schiefer – Motif-Kante: Licht oben links, Schatten unten rechts, Gehrung an den Ecken.
 * Farben wie im Qt-Stil: Licht = Grund + 55 % Weiß, Schatten = Grund + 50 % Schwarz.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: bevel

    property bool sunken: false
    property int depth: 2
    property color base: Kirigami.Theme.backgroundColor
    property color fill: base
    property bool filled: true
    property bool outline: false            // dunkle 1-px-Außenlinie wie bei Default-Knöpfen

    readonly property color lightColor: Qt.tint(base, Qt.rgba(1, 1, 1, 0.55))
    readonly property color darkColor: Qt.tint(base, Qt.rgba(0, 0, 0, 0.5))
    readonly property color topLeft: sunken ? darkColor : lightColor
    readonly property color bottomRight: sunken ? lightColor : darkColor
    readonly property int off: outline ? 1 : 0

    Rectangle {
        anchors.fill: parent
        visible: bevel.outline
        color: "transparent"
        border.width: 1
        border.color: Qt.tint(bevel.base, Qt.rgba(0, 0, 0, 0.62))
    }

    Rectangle {
        visible: bevel.filled
        x: bevel.off + bevel.depth
        y: bevel.off + bevel.depth
        width: bevel.width - 2 * (bevel.off + bevel.depth)
        height: bevel.height - 2 * (bevel.off + bevel.depth)
        color: bevel.fill
    }

    Repeater {
        model: bevel.depth
        delegate: Item {
            required property int index
            readonly property int o: bevel.off + index
            readonly property int w: bevel.width - 2 * bevel.off
            readonly property int h: bevel.height - 2 * bevel.off
            // oben, links (Lichtkante; Diagonalpixel gehören ihr)
            Rectangle { x: o; y: o; width: w - 2 * index; height: 1; color: bevel.topLeft }
            Rectangle { x: o; y: o; width: 1; height: h - 2 * index; color: bevel.topLeft }
            // unten, rechts (Schattenkante)
            Rectangle { x: o + 1; y: bevel.height - 1 - o; width: w - 2 * index - 1; height: 1; color: bevel.bottomRight }
            Rectangle { x: bevel.width - 1 - o; y: o + 1; width: 1; height: h - 2 * index - 1; color: bevel.bottomRight }
        }
    }
}
