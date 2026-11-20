/*
 * Ein Abschnitt der Icon Box: die Fenster einer Arbeitsfläche (eigenes TasksModel),
 * auf Wunsch mit Überschrift in der Farbe der Arbeitsfläche.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Column {
    id: section

    required property var box            // PlasmoidItem der Icon Box
    required property string desktopId
    property string headerText
    property color headerColor: Kirigami.Theme.backgroundColor
    property bool showHeader: false

    readonly property int count: tasksModel.count
    readonly property alias tasksModel: tasksModel

    spacing: 2
    visible: count > 0 || !showHeader

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: section.box.cfg.groupWindows ? TaskManager.TasksModel.GroupApplications : TaskManager.TasksModel.GroupDisabled
        groupInline: false
        groupingWindowTasksThreshold: -1
        sortMode: section.box.cfg.sortMode === "app" ? TaskManager.TasksModel.SortAlpha
                : section.box.cfg.sortMode === "lastActivated" ? TaskManager.TasksModel.SortLastActivated
                : TaskManager.TasksModel.SortDisabled
        separateLaunchers: false
        launcherList: []
        filterByVirtualDesktop: true
        virtualDesktop: section.desktopId
        filterByActivity: true
        activity: section.box.currentActivity
        filterByScreen: false
        filterNotMinimized: !section.box.cfg.showNormalWindows
    }

    // Überschrift wie ein Arbeitsflächen-Knopf der Konsole
    Item {
        visible: section.showHeader
        width: section.width
        height: headerLabel.implicitHeight + 6
        Bevel {
            anchors.fill: parent
            depth: 1
            base: section.headerColor
            sunken: section.desktopId === section.box.currentDesktop
        }
        PlasmaComponents3.Label {
            id: headerLabel
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: section.headerText
            font: Kirigami.Theme.smallFont
            color: "#000000"
        }
    }

    Grid {
        id: grid
        width: section.width
        columns: section.box.lanes
        spacing: section.box.listMode ? 2 : 0
        Repeater {
            model: tasksModel
            delegate: Loader {
                id: entry
                required property var model
                required property int index
                readonly property var modelIndex: tasksModel.makeModelIndex(index)
                width: Math.floor((section.width - (section.box.lanes - 1) * grid.spacing) / section.box.lanes)
                height: section.box.listMode ? item?.implicitHeight ?? 0 : section.box.cellLength
                sourceComponent: section.box.listMode ? rowComponent : iconComponent

                Component {
                    id: rowComponent
                    WindowRow {
                        id: wr
                        tasksModel: tasksModel
                        modelIndex: entry.modelIndex
                        model: entry.model
                        box: section.box
                        groupOpen: section.box.groupAnchor === wr && section.box.groupVisible
                    }
                }
                Component {
                    id: iconComponent
                    WindowIcon {
                        id: wi
                        tasksModel: tasksModel
                        modelIndex: entry.modelIndex
                        model: entry.model
                        box: section.box
                        iconSize: section.box.iconSize
                        groupOpen: section.box.groupAnchor === wi && section.box.groupVisible
                    }
                }
            }
        }
    }
}
