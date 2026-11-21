/*
 * Motif-Optionsmenü (XmOptionMenu): erhabener Knopf mit der aktuellen Wahl, rechts der kleine
 * erhabene Balken als Kaskadenzeichen. Klick, Leertaste, Eingabe oder Pfeil ab öffnen das Menü
 * (Signal activated, der Aufrufer öffnet sein MMenu an diesem Knopf).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: o
    required property Pal pal
    property string text
    signal activated()

    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.5
    implicitWidth: label.implicitWidth + 3 * pal.u
    implicitHeight: label.implicitHeight + Math.round(pal.u * 0.5) + 4

    Keys.onPressed: e => {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Down].includes(e.key)) { e.accepted = true; o.activated(); }
    }

    // Fokus: dunkler 1-px-Rahmen
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        visible: o.activeFocus
        color: "transparent"
        border.width: 1
        border.color: o.pal.fg
    }
    Bevel {
        anchors.fill: parent
        base: o.pal.bg
        fill: ma.containsMouse ? o.pal.hover(o.pal.bg) : o.pal.bg

        Text {
            id: label
            renderType: o.pal.renderType
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(o.pal.u * 0.5)
            width: parent.width - x - 2 * o.pal.u
            elide: Text.ElideRight
            font: o.pal.font
            color: o.pal.fg
            text: o.text
        }
        // Kaskadenzeichen: flacher erhabener Balken
        Bevel {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Math.round(o.pal.u * 0.5)
            width: Math.round(o.pal.u * 0.8)
            height: Math.max(5, Math.round(o.pal.u * 0.3))
            base: o.pal.bg
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { o.forceActiveFocus(); o.activated(); }
    }
}
