/*
 * Motif-Druckknopf: erhaben, beim Drücken versenkt; Default-Knopf mit versenktem Ring
 * (XmNshowAsDefault), Tastaturfokus als 1-px-Rahmen (XmNhighlightThickness).
 * Mnemonik wie in Motif immer unterstrichen: text "&Neu starten" -> N unterstrichen, Alt+N löst aus.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: b
    required property Pal pal
    property string text
    property bool isDefault: false
    property bool keyDown: false
    readonly property bool down: (ma.pressed && ma.containsMouse) || keyDown
    readonly property string mnemonic: { const i = text.indexOf("&"); return i >= 0 && i + 1 < text.length ? text.charAt(i + 1).toLowerCase() : ""; }
    readonly property string plainText: text.replace("&", "")
    signal clicked()

    readonly property int ring: 4
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.5
    implicitWidth: Math.max(label.implicitWidth + 2 * pal.u, 5 * pal.u) + 2 * ring
    implicitHeight: label.implicitHeight + Math.round(pal.u * 0.7) + 4 + 2 * ring

    Keys.onPressed: e => { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { keyDown = true; e.accepted = true; } }
    Keys.onReleased: e => { if (keyDown && (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { keyDown = false; e.accepted = true; b.clicked(); } }

    // Default-Ring: versenkte Mulde um den Knopf
    Bevel {
        anchors.fill: parent
        visible: b.isDefault
        sunken: true
        depth: 1
        base: b.pal.bg
        filled: false
    }
    // Fokus: dunkler 1-px-Rahmen innerhalb des Rings
    Rectangle {
        anchors.fill: parent
        anchors.margins: b.ring - 2
        visible: b.activeFocus
        color: "transparent"
        border.width: 1
        border.color: b.pal.fg
    }
    Bevel {
        id: face
        anchors.fill: parent
        anchors.margins: b.ring
        base: b.pal.bg
        sunken: b.down
        fill: b.down ? b.pal.edges(b.pal.bg).select : (ma.containsMouse ? b.pal.hover(b.pal.bg) : b.pal.bg)

        Text {
            renderType: b.pal.renderType
            id: label
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: b.down ? 1 : 0
            anchors.verticalCenterOffset: b.down ? 1 : 0
            font: b.pal.font
            color: b.pal.fg
            textFormat: Text.StyledText
            text: {
                const i = b.text.indexOf("&");
                const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                return i < 0 ? esc(b.text) : esc(b.text.slice(0, i)) + "<u>" + esc(b.text.charAt(i + 1)) + "</u>" + esc(b.text.slice(i + 2));
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: b.clicked()
    }
}
