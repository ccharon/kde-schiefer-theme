/*
 * Schiefer: frame of a flat subpanel entry (CDE): no bevel of its own; under the mouse the
 * 1 px focus frame in the active title color, while pressed sunken 1 px.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    property bool hovered: false
    property bool pressed: false
    Rectangle {
        anchors.fill: parent
        visible: parent.hovered
        color: "transparent"
        border.width: 1
        border.color: Scheme.activeTitle.valid ? Scheme.activeTitle : Kirigami.Theme.highlightColor
    }
    Bevel {
        anchors.fill: parent
        anchors.margins: 1
        visible: parent.pressed
        sunken: true
        depth: 1
        filled: false
    }
}
