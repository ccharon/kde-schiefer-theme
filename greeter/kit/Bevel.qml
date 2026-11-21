/*
 * Motif-Kante: Licht oben links, Schatten unten rechts, Gehrung an den Ecken (Motif-Formel).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import "Motif.js" as Motif

Item {
    id: bevel
    property bool sunken: false
    property int depth: 2
    property color base: "#bec2d3"
    property color fill: base
    property bool filled: true

    readonly property var motif: Motif.colors(base)
    readonly property color topLeft: sunken ? motif.bottom : motif.top
    readonly property color bottomRight: sunken ? motif.top : motif.bottom

    Rectangle {
        visible: bevel.filled
        x: bevel.depth; y: bevel.depth
        width: bevel.width - 2 * bevel.depth; height: bevel.height - 2 * bevel.depth
        color: bevel.fill
    }
    Repeater {
        model: bevel.depth
        delegate: Item {
            required property int index
            readonly property int o: index
            Rectangle { x: o; y: o; width: bevel.width - 2 * o; height: 1; color: bevel.topLeft }
            Rectangle { x: o; y: o; width: 1; height: bevel.height - 2 * o; color: bevel.topLeft }
            Rectangle { x: o + 1; y: bevel.height - 1 - o; width: bevel.width - 2 * o - 1; height: 1; color: bevel.bottomRight }
            Rectangle { x: bevel.width - 1 - o; y: o + 1; width: 1; height: bevel.height - 2 * o - 1; color: bevel.bottomRight }
        }
    }
}
