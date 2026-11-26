/*
 * An icon box entry in the list view (icon manager as in twm/FvwmIconMan):
 * icon on the left, title and application to its right. State through the Motif relief:
 *   open = raised, active = pressed in + highlight, minimized = flat + italic,
 *   demands attention = tinted orange.
 * Groups (several windows of one application) show the application, count and an arrow;
 * a click brings the most recently used window forward, or opens a drawer with the single
 * windows to the side when the application is already active. Middle click on a window closes it.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: row

    required property var tasksModel
    required property var modelIndex     // QModelIndex of this entry
    required property var model          // roles of the TasksModel
    required property var box            // PlasmoidItem (openGroup, closeGroup, desktopInfo)
    property bool inGroupPopup: false
    property bool groupOpen: false

    readonly property bool isGroup: model?.IsGroupParent === true
    readonly property bool active: model?.IsActive === true
    readonly property bool minimized: model?.IsMinimized === true
    readonly property bool starting: model?.IsStartup === true
    readonly property bool attention: model?.IsDemandingAttention === true
    readonly property int childCount: model?.ChildCount ?? 0
    readonly property string appName: model?.AppName || ""
    readonly property string title: isGroup ? (appName || (model?.display ?? "")) : (model?.display ?? "")
    // second line: application; for groups the count; nothing in the group drawer
    readonly property string subtitle: isGroup ? i18np("%1 window", "%1 windows", childCount)
                                     : inGroupPopup ? "" : (appName !== title ? appName : "")
    readonly property bool pressed: mouse.pressed && mouse.containsMouse
    readonly property bool sunken: active || pressed || groupOpen
    readonly property color base: attention ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(0.85, 0.6, 0.2, 0.45))
                                            : Kirigami.Theme.backgroundColor

    implicitHeight: box.rowHeight

    Bevel {
        anchors.fill: parent
        // minimized: flat, a fine edge only on hover
        visible: !row.minimized || row.sunken || mouse.containsMouse
        depth: row.minimized && !row.sunken ? 1 : 2
        sunken: row.sunken
        base: row.base
        fill: row.active ? Kirigami.Theme.highlightColor
            : mouse.containsMouse ? Scheme.hoverColor(row.base) : row.base
        filled: !row.minimized || row.sunken || mouse.containsMouse || row.attention
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: Kirigami.Units.smallSpacing + 2
        // pressed in: content 1 px down and right, as in the Qt style
        anchors.topMargin: row.sunken ? 1 : 0
        anchors.leftMargin: row.sunken ? Kirigami.Units.smallSpacing + 3 : Kirigami.Units.smallSpacing + 2
        spacing: Kirigami.Units.smallSpacing + 2

        Kirigami.Icon {
            id: icon
            Layout.preferredWidth: row.inGroupPopup ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Layout.preferredWidth
            source: row.model?.decoration
            active: mouse.containsMouse
            opacity: row.minimized ? 0.55 : 1
            RotationAnimator on rotation {
                running: row.starting
                from: 0; to: 360; duration: 1600; loops: Animation.Infinite
                onRunningChanged: if (!running) icon.rotation = 0
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.italic: row.minimized
                color: row.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.subtitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                color: row.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                opacity: 0.7
            }
        }
        // groups: arrow pointing away from the edge (the drawer opens to the side)
        MotifArrow {
            visible: row.isGroup
            Layout.preferredWidth: 11
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            up: Plasmoid.location !== PlasmaCore.Types.TopEdge
            rotation: Plasmoid.location === PlasmaCore.Types.LeftEdge ? 90
                    : Plasmoid.location === PlasmaCore.Types.RightEdge ? -90 : 0
            sunken: row.groupOpen
            base: row.active ? Kirigami.Theme.highlightColor : row.base
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        // wheel on a group: through its windows; elsewhere the box scrolls
        onWheel: wheel => {
            if (!row.isGroup) { wheel.accepted = false; return; }
            const d = wheel.angleDelta.y || wheel.angleDelta.x;
            if (d !== 0) row.box.cycleGroup(row.tasksModel, row.modelIndex, d < 0 ? 1 : -1);
        }
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                row.box.showMenu(row.tasksModel, row.modelIndex, row);
            } else if (row.isGroup) {
                if (event.button === Qt.MiddleButton) row.tasksModel.requestNewInstance(row.modelIndex);
                else row.box.clickGroup(row.tasksModel, row.modelIndex, row);
            } else if (event.button === Qt.MiddleButton) {
                // middle click closes the window
                row.tasksModel.requestClose(row.modelIndex);
            } else if (row.active && !row.minimized) {
                row.tasksModel.requestToggleMinimized(row.modelIndex);
            } else {
                row.tasksModel.requestActivate(row.modelIndex);
                if (row.inGroupPopup) row.box.closeGroup();
            }
        }
    }

    Timer {
        interval: 2500
        running: row.isGroup && !row.inGroupPopup && row.box.testGroup.length > 0 && row.box.testGroup === row.appName
        onTriggered: row.box.toggleGroup(row.tasksModel, row.modelIndex, row)
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: !row.isGroup && !row.groupOpen
        mainText: row.model?.display ?? ""
        subText: {
            const parts = [];
            if (row.appName && row.appName !== row.model?.display) parts.push(row.appName);
            if (row.minimized) parts.push(i18n("minimized"));
            return parts.join(" – ");
        }
        icon: row.model?.decoration
        location: Plasmoid.location
    }
}
