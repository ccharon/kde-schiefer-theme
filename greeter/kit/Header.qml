/*
 * Header of all Schiefer screens: emblem, greeting, large host name, operating system;
 * optionally the seven-segment clock with the date on the right.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: head
    required property Pal pal
    property string greeting
    property string host
    property string subtitle
    property bool showClock: true
    property date now: new Date()
    spacing: pal.u

    Emblem { pal: head.pal; Layout.alignment: Qt.AlignTop }
    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Text { renderType: head.pal.renderType; text: head.greeting; visible: text !== ""; font: head.pal.font; color: head.pal.fg }
        Text {
            renderType: head.pal.renderType
            text: head.host
            color: head.pal.fg
            font.family: head.pal.font.family
            font.pixelSize: Math.round(head.pal.u * 1.7)
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text { renderType: head.pal.renderType; text: head.subtitle; visible: text !== ""; font: head.pal.font; color: head.pal.fg; opacity: 0.8; elide: Text.ElideRight; Layout.fillWidth: true }
    }
    ColumnLayout {
        visible: head.showClock
        spacing: Math.round(head.pal.u * 0.25)
        Layout.alignment: Qt.AlignTop
        SevenSeg { pal: head.pal; now: head.now; Layout.alignment: Qt.AlignHCenter }
        Text {
            renderType: head.pal.renderType
            Layout.alignment: Qt.AlignHCenter
            text: head.now.toLocaleDateString(Qt.locale(), "ddd, d. MMM yyyy")
            font: head.pal.font
            color: head.pal.fg
        }
    }
}
