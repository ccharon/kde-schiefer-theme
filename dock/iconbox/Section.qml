/*
 * One section of the icon box: the windows of one desktop (own TasksModel),
 * optionally with a heading in the desktop color.
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
    // number of windows, groups counted with all their windows
    readonly property int windowCount: {
        let n = 0;
        for (let i = 0; i < entries.count; ++i) n += entries.itemAt(i)?.weight ?? 0;
        return n;
    }
    // length of this section if no window were grouped (decides whether the box groups)
    readonly property int ungroupedLength: {
        if (windowCount === 0) return 0;
        const rows = Math.ceil(windowCount / box.lanes);
        const entry = box.listMode ? box.rowHeight : box.cellLength;
        return (showHeader ? header.height + spacing : 0) + rows * entry + (rows - 1) * grid.spacing;
    }

    spacing: 2
    visible: count > 0 || !showHeader

    TaskManager.TasksModel {
        id: tasksModel
        // groups only when the windows would not fit otherwise (box.tight)
        groupMode: section.box.tight ? TaskManager.TasksModel.GroupApplications : TaskManager.TasksModel.GroupDisabled
        groupInline: false
        groupingWindowTasksThreshold: -1
        // order comes from TaskOrder; unsorted, the rows stay in the order of opening
        sortMode: TaskManager.TasksModel.SortDisabled
        separateLaunchers: false
        launcherList: []
        filterByVirtualDesktop: true
        virtualDesktop: section.desktopId
        filterByActivity: true
        activity: section.box.currentActivity
        filterByScreen: false
        filterNotMinimized: !section.box.cfg.showNormalWindows
    }

    // heading like a desktop button of the console
    Item {
        id: header
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

    // display order: rank per model row (TaskOrder); recomputed when the model changes
    TaskOrder { id: order }
    property var ranks: []
    // "lastActivated": programs do not move while the mouse is over the box (the clicked one
    // would jump away); the times are taken when the mouse enters, the new order shows after it leaves
    property var frozenTimes: null
    readonly property bool freeze: (box.hovered || box.groupVisible) && box.cfg.sortMode === "lastActivated"
    onFreezeChanged: {
        frozenTimes = freeze ? order.clusterTimes(tasksModel) : null;
        rankTimer.restart();
    }
    function updateRanks() { ranks = order.ranks(tasksModel, null, box.cfg.sortMode, null, frozenTimes); }
    Timer { id: rankTimer; interval: 0; onTriggered: section.updateRanks() }
    Connections {
        target: tasksModel
        function onRowsInserted() { rankTimer.restart(); }
        function onRowsRemoved() { rankTimer.restart(); }
        function onRowsMoved() { rankTimer.restart(); }
        function onModelReset() { rankTimer.restart(); }
        function onLayoutChanged() { rankTimer.restart(); }
        function onDataChanged() { rankTimer.restart(); }
    }
    Connections {
        target: section.box.cfg
        function onSortModeChanged() { rankTimer.restart(); }
    }
    Component.onCompleted: rankTimer.restart()

    // entries placed by rank in a grid of box.lanes columns; the Repeater runs over the
    // unsorted model, so index is always the model row of the entry
    Item {
        id: grid
        readonly property int spacing: section.box.listMode ? 2 : 0
        readonly property int cellWidth: Math.floor((section.width - (section.box.lanes - 1) * spacing) / section.box.lanes)
        readonly property int cellHeight: section.box.listMode ? section.box.rowHeight : section.box.cellLength
        readonly property int rows: Math.ceil(entries.count / section.box.lanes)
        width: section.width
        height: rows > 0 ? rows * cellHeight + (rows - 1) * spacing : 0
        Repeater {
            id: entries
            model: tasksModel
            delegate: Loader {
                id: entry
                required property var model
                required property int index
                readonly property var modelIndex: tasksModel.makeModelIndex(index)
                readonly property int weight: model.IsGroupParent === true ? (model.ChildCount ?? 1) : 1
                readonly property int rank: section.ranks[index] ?? index
                x: (rank % section.box.lanes) * (grid.cellWidth + grid.spacing)
                y: Math.floor(rank / section.box.lanes) * (grid.cellHeight + grid.spacing)
                width: grid.cellWidth
                height: grid.cellHeight
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
