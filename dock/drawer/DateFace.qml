/*
 * Kalenderblatt: Monat klein oben, Tag groß darunter
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: sheet

    property date today: new Date()

    Item {
        id: paper
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.78)
        height: Math.round(parent.height * 0.86)

        Bevel {
            anchors.fill: parent
            base: Kirigami.Theme.backgroundColor
            fill: Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.7))
        }
        // Spiralbindung
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 1
            spacing: Math.max(2, Math.round(paper.width / 9))
            Repeater {
                model: 4
                Rectangle {
                    width: Math.max(2, Math.round(paper.width / 18))
                    height: Math.max(3, Math.round(paper.height / 9))
                    radius: width / 2
                    color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(0, 0, 0, 0.5))
                }
            }
        }
        Text {
            id: month
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(paper.height * 0.12)
            text: Qt.locale().monthName(sheet.today.getMonth(), Locale.ShortFormat).replace(".", "")
            font.pixelSize: Math.max(8, Math.round(paper.height * 0.26))
            font.family: Kirigami.Theme.defaultFont.family
            color: Kirigami.Theme.textColor
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: month.bottom
            anchors.topMargin: -Math.round(paper.height * 0.04)
            text: sheet.today.getDate()
            font.pixelSize: Math.max(10, Math.round(paper.height * 0.44))
            font.family: Kirigami.Theme.defaultFont.family
            color: Kirigami.Theme.textColor
        }
    }
}
