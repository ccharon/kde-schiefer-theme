/*
 * Ein Eintrag der Icon Box in der Symbolansicht (mwm): Bild im Rahmen, Beschriftung darunter.
 * Zustand über das Relief wie in der Listenansicht: offen = erhaben, aktiv = eingedrückt
 * + hervorgehobene Beschriftung, minimiert = flach + kursiv, Aufmerksamkeit = orange.
 * Gruppen tragen ein Zählschild und klappen per Klick seitlich ihre Fenster auf.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: win

    required property var tasksModel
    required property var modelIndex
    required property var model
    required property var box
    required property int iconSize
    property bool groupOpen: false

    readonly property bool isGroup: model?.IsGroupParent === true
    readonly property bool active: model?.IsActive === true
    readonly property bool minimized: model?.IsMinimized === true
    readonly property bool starting: model?.IsStartup === true
    readonly property bool attention: model?.IsDemandingAttention === true
    readonly property bool sunken: active || groupOpen || (mouse.pressed && mouse.containsMouse)
    readonly property color base: attention ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(0.85, 0.6, 0.2, 0.45))
                                            : Kirigami.Theme.backgroundColor
    readonly property string title: isGroup ? (model?.AppName || model?.display || "") : (model?.display ?? "")

    // ---------- Rahmen mit Bild ----------
    Item {
        id: iconFrame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Kirigami.Units.smallSpacing
        width: win.iconSize + 10
        height: width

        Bevel {
            anchors.fill: parent
            visible: !win.minimized || win.sunken || mouse.containsMouse
            depth: win.minimized && !win.sunken ? 1 : 2
            sunken: win.sunken
            base: win.base
            fill: mouse.containsMouse ? Scheme.hoverColor(base) : base
        }
        Kirigami.Icon {
            id: icon
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: win.sunken ? 1 : 0
            anchors.verticalCenterOffset: anchors.horizontalCenterOffset
            width: win.iconSize
            height: width
            source: win.model?.decoration
            active: mouse.containsMouse
            opacity: win.minimized ? 0.55 : 1
            RotationAnimator on rotation {
                running: win.starting
                from: 0; to: 360; duration: 1600; loops: Animation.Infinite
                onRunningChanged: if (!running) icon.rotation = 0
            }
        }
        // Zählschild für Gruppen
        Rectangle {
            visible: win.isGroup
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -2
            width: Math.max(height, countLabel.implicitWidth + 6)
            height: countLabel.implicitHeight + 2
            color: Kirigami.Theme.backgroundColor
            border.color: Scheme.motifColors(Kirigami.Theme.backgroundColor).bottom
            PlasmaComponents3.Label {
                id: countLabel
                anchors.centerIn: parent
                text: win.model?.ChildCount ?? ""
                font: Kirigami.Theme.smallFont
            }
        }
    }

    // ---------- Beschriftung ----------
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: iconFrame.bottom
        anchors.topMargin: 2
        width: Math.min(parent.width - 4, label.implicitWidth + 6)
        height: label.height + 2
        color: win.active ? Kirigami.Theme.highlightColor : "transparent"
        PlasmaComponents3.Label {
            id: label
            anchors.centerIn: parent
            width: win.width - 10
            horizontalAlignment: Text.AlignHCenter
            text: win.title
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.italic: win.minimized
            color: win.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                win.box.showMenu(win.tasksModel, win.modelIndex, win);
            } else if (win.isGroup) {
                if (event.button === Qt.MiddleButton) win.tasksModel.requestNewInstance(win.modelIndex);
                else win.box.toggleGroup(win.tasksModel, win.modelIndex, win);
            } else if (event.button === Qt.MiddleButton) {
                win.tasksModel.requestToggleMinimized(win.modelIndex);
            } else if (win.active && !win.minimized) {
                win.tasksModel.requestToggleMinimized(win.modelIndex);
            } else {
                win.tasksModel.requestActivate(win.modelIndex);
            }
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: !win.groupOpen
        mainText: win.title
        subText: win.isGroup ? i18np("%1 Fenster", "%1 Fenster", win.model?.ChildCount ?? 0)
               : [win.model?.AppName !== win.model?.display ? win.model?.AppName : "", win.minimized ? i18n("minimiert") : ""].filter(s => s).join(" – ")
        icon: win.model?.decoration
        location: Plasmoid.location
    }
}
