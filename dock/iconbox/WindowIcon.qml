/*
 * An icon box entry in the icon view, drawn like a dtwm icon (WmIDecor.c): the image on its
 * own raised tile, below it a raised label strip as wide as the tile in the inactive frame
 * color, the name cut to the strip. The active window's label and the one under the mouse
 * widen to the full name in the active frame color, as dtwm does for the active icon.
 * State through the relief: open = raised, active = pressed in, minimized = flat tile + italic
 * name, attention = orange.
 * Groups carry a count badge; a click brings the most recently used window forward, or opens
 * the windows to the side when the application is already active.
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
    // label strip open to the full name (dtwm active icon label)
    readonly property bool labelOpen: active || mouse.containsMouse
    z: labelOpen ? 1 : 0

    // ---------- Frame with image ----------
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
            depth: 1
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
        // count badge for groups
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

    // ---------- Label strip ----------
    Item {
        id: strip
        readonly property color stripColor: win.labelOpen ? (Scheme.activeTitle.valid ? Scheme.activeTitle : Kirigami.Theme.highlightColor)
                                                          : win.box.boxColor
        readonly property color stripText: win.labelOpen ? (Scheme.activeTitleText.valid ? Scheme.activeTitleText : Kirigami.Theme.highlightedTextColor)
                                                         : win.box.boxTextColor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: iconFrame.bottom
        anchors.topMargin: 1
        // tile width; open: as wide as the name needs, at most the whole cell
        width: win.labelOpen ? Math.min(win.width, Math.max(iconFrame.width, label.implicitWidth + 6)) : iconFrame.width
        height: label.implicitHeight + 4
        Bevel {
            anchors.fill: parent
            depth: 1
            base: strip.stripColor
        }
        PlasmaComponents3.Label {
            id: label
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            verticalAlignment: Text.AlignVCenter
            // dtwm cuts the name at the strip edge; open, it is centered and elided only if the
            // cell is too narrow
            horizontalAlignment: win.labelOpen ? Text.AlignHCenter : Text.AlignLeft
            clip: true
            text: win.title
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: win.labelOpen ? Text.ElideRight : Text.ElideNone
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.italic: win.minimized
            color: strip.stripText
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        // wheel on a group: through its windows; elsewhere the box scrolls
        onWheel: wheel => {
            if (!win.isGroup) { wheel.accepted = false; return; }
            const d = wheel.angleDelta.y || wheel.angleDelta.x;
            if (d !== 0) win.box.cycleGroup(win.tasksModel, win.modelIndex, d < 0 ? 1 : -1);
        }
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                win.box.showMenu(win.tasksModel, win.modelIndex, win);
            } else if (win.isGroup) {
                if (event.button === Qt.MiddleButton) win.tasksModel.requestNewInstance(win.modelIndex);
                else win.box.clickGroup(win.tasksModel, win.modelIndex, win);
            } else if (event.button === Qt.MiddleButton) {
                // middle click closes the window
                win.tasksModel.requestClose(win.modelIndex);
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
        subText: win.isGroup ? i18np("%1 window", "%1 windows", win.model?.ChildCount ?? 0)
               : [win.model?.AppName !== win.model?.display ? win.model?.AppName : "", win.minimized ? i18n("minimized") : ""].filter(s => s).join(" – ")
        icon: win.model?.decoration
        location: Plasmoid.location
    }
}
