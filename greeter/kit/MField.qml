/*
 * Motif-Textfeld: versenkt, Textflächenfarbe, I-Balken-Schreibmarke mit Serifen (wie XmText).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Bevel {
    id: f
    required property Pal pal
    property alias text: input.text
    property alias input: input
    property bool password: false
    signal accepted()

    base: pal.bg
    sunken: true
    fill: pal.field
    implicitWidth: 18 * pal.u
    implicitHeight: pal.u + 12

    function clear() { input.clear(); }
    function grab() { input.forceActiveFocus(); }

    // Fokus wie bei Motif: dunkler Rahmen außen
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        z: -1
        visible: input.activeFocus
        color: "transparent"
        border.width: 1
        border.color: f.pal.fg
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 6; anchors.rightMargin: 6
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        font: f.pal.font
        color: f.pal.fieldText
        selectionColor: f.pal.active
        selectedTextColor: f.pal.activeText
        echoMode: f.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "*"
        passwordMaskDelay: 0
        inputMethodHints: f.password ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText : Qt.ImhNoAutoUppercase
        selectByMouse: true
        onAccepted: f.accepted()
        cursorDelegate: Item {
            id: cur
            width: 5
            visible: input.activeFocus
            property bool on: true
            Timer { interval: 530; running: input.activeFocus; repeat: true; onTriggered: cur.on = !cur.on }
            Connections { target: input; function onCursorPositionChanged() { cur.on = true; } function onTextChanged() { cur.on = true; } }
            readonly property int h: Math.round(f.pal.metrics.height)
            Item {
                visible: cur.on
                y: Math.round((input.height - cur.h) / 2)
                Rectangle { x: 2; width: 1; height: cur.h; color: f.pal.fieldText }
                Rectangle { x: 0; width: 5; height: 1; color: f.pal.fieldText }
                Rectangle { x: 0; y: cur.h - 1; width: 5; height: 1; color: f.pal.fieldText }
            }
        }
    }
}
