/*
 * Dialog panel like a Motif window: raised frame with a joint; with title also a
 * title bar in the active frame color (like the Schiefer decoration). Content as children.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: p
    required property Pal pal
    property string title
    property int padding: pal.u
    default property alias content: inner.data
    readonly property int frame: 6                     // frame: 2 raised + 2 surface + 2 sunken
    readonly property int titleH: title !== "" ? Math.round(pal.u * 1.6) : 0
    implicitWidth: inner.childrenRect.width + 2 * (frame + padding)
    implicitHeight: inner.childrenRect.height + 2 * (frame + padding) + titleH

    readonly property color frameColor: title !== "" ? pal.active : pal.bg
    Bevel { anchors.fill: parent; base: p.frameColor }
    Bevel {
        anchors.fill: parent; anchors.margins: 4
        base: p.frameColor
        sunken: true; filled: false
    }
    // Titelleiste
    Bevel {
        visible: p.title !== ""
        x: p.frame; y: p.frame
        width: p.width - 2 * p.frame; height: p.titleH
        base: p.pal.active
        Text {
            renderType: p.pal.renderType
            anchors.centerIn: parent
            text: p.title
            font: p.pal.font
            color: p.pal.activeText
        }
    }
    // work area
    Bevel {
        x: p.frame; y: p.frame + p.titleH
        width: p.width - 2 * p.frame; height: p.height - 2 * p.frame - p.titleH
        base: p.pal.bg
        Item {
            id: inner
            x: p.padding; y: p.padding
            width: parent.width - 2 * p.padding
            height: parent.height - 2 * p.padding
        }
    }
}
