/*
 * Window button of the Schiefer console: raised = background, sunken = active,
 * italic/faded = minimized (like a Motif icon).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: task

    required property var tasksModel
    required property int index
    required property var model          // roles of the TasksModel
    property bool showTooltip: true
    signal activated()

    readonly property var modelIndex: tasksModel.makeModelIndex(index)
    readonly property bool active: model.IsActive === true
    readonly property bool minimized: model.IsMinimized === true
    readonly property bool starting: model.IsStartup === true
    readonly property bool attention: model.IsDemandingAttention === true

    Bevel {
        anchors.fill: parent
        sunken: task.active || (mouse.pressed && mouse.containsMouse)
        base: task.attention ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(0.85, 0.6, 0.2, 0.45))
                             : Kirigami.Theme.backgroundColor
        fill: task.active ? Qt.tint(base, Qt.rgba(1, 1, 1, 0.22)) : base
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 4 + Kirigami.Units.smallSpacing
        anchors.rightMargin: 4 + Kirigami.Units.smallSpacing
        // sunken buttons: content 1 px down and right, as in the Qt style
        anchors.topMargin: task.active ? 1 : 0
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Kirigami.Units.iconSizes.small, task.height - 6)
            height: width
            source: task.model.decoration
            opacity: task.minimized ? 0.55 : 1
            RotationAnimator on rotation {
                running: task.starting
                from: 0; to: 360; duration: 1600; loops: Animation.Infinite
                onRunningChanged: if (!running) icon.rotation = 0
            }
        }
        PlasmaComponents3.Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - icon.width - parent.spacing
            text: task.model.display ?? ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.italic: task.minimized
            opacity: task.minimized ? 0.7 : 1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                menu.openRelative();
            } else if (event.button === Qt.MiddleButton) {
                task.tasksModel.requestNewInstance(task.modelIndex);
            } else if (task.active && !task.minimized) {
                task.tasksModel.requestToggleMinimized(task.modelIndex);
            } else {
                task.tasksModel.requestActivate(task.modelIndex);
                task.activated();
            }
        }
    }

    // dragging onto a desktop button moves the window there
    DragHandler {
        id: dragHandler
        target: null
        enabled: !task.starting
    }
    Drag.active: dragHandler.active
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction
    Drag.keys: ["application/x-schiefer-task"]
    Drag.mimeData: { "application/x-schiefer-task": String(task.index) }
    Drag.imageSource: task.model.decoration ? "image://icon/" + task.model.decoration : ""

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: task.showTooltip && !dragHandler.active
        mainText: task.model.display ?? ""
        subText: task.model.AppName && task.model.AppName !== task.model.display ? task.model.AppName : ""
        icon: task.model.decoration
        location: Plasmoid.location
    }

    PlasmaExtras.Menu {
        id: menu
        visualParent: task
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        PlasmaExtras.MenuItem {
            text: task.minimized ? i18n("Restore") : i18n("Minimize")
            icon: task.minimized ? "window-restore" : "window-minimize"
            onClicked: task.tasksModel.requestToggleMinimized(task.modelIndex)
        }
        PlasmaExtras.MenuItem {
            text: task.model.IsMaximized ? i18n("Unmaximize") : i18n("Maximize")
            icon: task.model.IsMaximized ? "window-restore" : "window-maximize"
            enabled: task.model.IsMaximizable === true
            onClicked: task.tasksModel.requestToggleMaximized(task.modelIndex)
        }
        PlasmaExtras.MenuItem {
            text: i18n("New Window")
            icon: "window-new"
            onClicked: task.tasksModel.requestNewInstance(task.modelIndex)
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Close")
            icon: "window-close"
            onClicked: task.tasksModel.requestClose(task.modelIndex)
        }
    }
}
