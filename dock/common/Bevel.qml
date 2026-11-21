/*
 * Schiefer: Motif bevel; light top left, shadow bottom right, mitered corners.
 * Colors as in the Qt style: light and shadow from the Motif formula (Scheme.motifColors).
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
    property bool outline: false            // dark 1 px outline as on default buttons

    // edge colors from the Motif formula (common/schiefercolors.h), depending on the base color
    readonly property var motif: Scheme.motifColors(base)
    readonly property color lightColor: motif.top
    readonly property color darkColor: motif.bottom
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
            // top, left (light edge; the diagonal pixels belong to it)
            Rectangle { x: o; y: o; width: w - 2 * index; height: 1; color: bevel.topLeft }
            Rectangle { x: o; y: o; width: 1; height: h - 2 * index; color: bevel.topLeft }
            // bottom, right (shadow edge)
            Rectangle { x: o + 1; y: bevel.height - 1 - o; width: w - 2 * index - 1; height: 1; color: bevel.bottomRight }
            Rectangle { x: bevel.width - 1 - o; y: o + 1; width: 1; height: h - 2 * index - 1; color: bevel.bottomRight }
        }
    }
}
