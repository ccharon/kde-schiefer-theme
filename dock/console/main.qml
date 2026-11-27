/*
 * Schiefer console: center part of the front panel.
 *   [lock]  [desktops 2xn]  |  ([window buttons 2xm])  [lamp / EXIT]
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import plasma.applet.org.kde.schiefer.console

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property int rows: Math.max(1, cfg.rows)
    readonly property int sp: 2                                   // gap between buttons
    readonly property int margin: Kirigami.Units.smallSpacing
    readonly property int rowHeight: Math.floor((height - 2 * margin - (rows - 1) * sp) / rows)

    readonly property int desktopCount: desktopInfo.numberOfDesktops
    readonly property int desktopColumns: Math.max(1, Math.ceil(desktopCount / rows))
    readonly property int desktopWidth: Math.round(cfg.desktopButtonWidth * Kirigami.Units.gridUnit)

    readonly property int taskCount: tasksModel.count
    // The window area grows by one column per window while the panel has room;
    // then the buttons get narrower, and below the minimum width "+N more" appears.
    readonly property int taskWidth: Math.round(cfg.taskButtonWidth * Kirigami.Units.gridUnit)
    readonly property int minTaskWidth: Math.min(taskWidth, Math.round(cfg.minTaskButtonWidth * Kirigami.Units.gridUnit))
    readonly property int minColumns: Math.max(1, cfg.minTaskColumns)
    readonly property int wantedColumns: {
        const c = Math.max(minColumns, Math.ceil(taskCount / rows));
        return cfg.maxTaskColumns > 0 ? Math.min(c, cfg.maxTaskColumns) : c;
    }
    readonly property int fitColumns: Math.max(1, Math.floor((taskArea.width + sp) / (minTaskWidth + sp)))
    readonly property int taskColumns: Math.max(1, Math.min(wantedColumns, fitColumns))
    readonly property int columnWidth: Math.min(taskWidth, Math.floor((taskArea.width - (taskColumns - 1) * sp) / taskColumns))
    readonly property int maxSlots: rows * taskColumns
    readonly property bool overflow: taskCount > maxSlots
    readonly property int shownTasks: overflow ? maxSlots - 1 : taskCount
    readonly property int taskPreferred: wantedColumns * taskWidth + (wantedColumns - 1) * sp
    readonly property int taskMinimum: minColumns * minTaskWidth + (minColumns - 1) * sp

    readonly property int sideWidth: Math.round(rowHeight * 1.5)
    property int startupCount: 0

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // option frontpanel-color: surfaces in the CDE front panel color instead of the window color;
    // children inherit it through Kirigami.Theme, FrameTint also tints the panel background
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}

    Layout.preferredWidth: layout.implicitWidth + 2 * margin
    Layout.minimumWidth: Layout.preferredWidth - (cfg.showTasks ? taskPreferred - taskMinimum : 0)
    Layout.maximumWidth: Layout.preferredWidth
    Layout.fillWidth: true
    Layout.fillHeight: true

    Helper { id: helper }

    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        separateLaunchers: false
        launcherList: []
        filterByVirtualDesktop: root.cfg.onlyCurrentDesktop
        virtualDesktop: desktopInfo.currentDesktop
        filterByActivity: true
        activity: activityInfo.currentActivity
        filterByScreen: false
    }

    function recountStartups() {
        let n = 0;
        for (let i = 0; i < taskRepeater.count; ++i) {
            const it = taskRepeater.itemAt(i);
            if (it && it.starting) ++n;
        }
        startupCount = n;
    }
    function desktopColor(i) {
        const fromScheme = cfg.desktopColorsFromScheme ? Scheme.desktopColors : [];
        const list = fromScheme.length ? fromScheme : cfg.desktopColors;
        return list.length ? list[i % list.length] : Kirigami.Theme.backgroundColor;
    }

    // etched vertical line (Motif separator)
    component Etch: Item {
        implicitWidth: 2
        Layout.fillHeight: true
        Rectangle { x: 0; width: 1; height: parent.height; color: Scheme.motifColors(Kirigami.Theme.backgroundColor).bottom }
        Rectangle { x: 1; width: 1; height: parent.height; color: Scheme.motifColors(Kirigami.Theme.backgroundColor).top }
    }

    component PanelButton: Item {
        id: pb
        property alias pressed: pbMouse.pressed
        property bool flat: false
        property string tip
        property string subTip
        signal clicked()
        Bevel {
            anchors.fill: parent
            visible: !pb.flat || (pbMouse.pressed && pbMouse.containsMouse)
            sunken: pbMouse.pressed && pbMouse.containsMouse
        }
        MouseArea { id: pbMouse; anchors.fill: parent; onClicked: pb.clicked() }
        PlasmaCore.ToolTipArea { anchors.fill: parent; mainText: pb.tip; subText: pb.subTip; location: Plasmoid.location }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: Kirigami.Units.smallSpacing + 2

        Etch {}

        // ---------- left: lock ----------
        ColumnLayout {
            visible: root.cfg.showLockButton
            Layout.fillHeight: true
            Layout.preferredWidth: root.sideWidth
            spacing: root.sp
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowHeight
                flat: true
                tip: i18n("Lock Screen")
                onClicked: helper.lockScreen()
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.min(parent.height - 4, Kirigami.Units.iconSizes.smallMedium)
                    height: width
                    source: "system-lock-screen"
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---------- Desktops ----------
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: root.desktopColumns * root.desktopWidth + (root.desktopColumns - 1) * root.sp
            Repeater {
                model: root.desktopCount
                delegate: Item {
                    id: desk
                    required property int index
                    readonly property string desktopId: desktopInfo.desktopIds[index] ?? ""
                    readonly property bool current: desktopId === desktopInfo.currentDesktop
                    readonly property color color: root.desktopColor(index)
                    // row by row like KWin: 1 2 / 3 4
                    x: (index % root.desktopColumns) * (root.desktopWidth + root.sp)
                    y: Math.floor(index / root.desktopColumns) * (root.rowHeight + root.sp)
                    width: root.desktopWidth
                    height: root.rowHeight

                    Bevel {
                        anchors.fill: parent
                        base: desk.color
                        sunken: desk.current || (deskMouse.pressed && deskMouse.containsMouse)
                        outline: dropArea.containsDrag
                        fill: desk.current ? Scheme.motifColors(desk.color).select : desk.color
                    }
                    PlasmaComponents3.Label {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        anchors.topMargin: desk.current ? 1 : 0
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: desktopInfo.desktopNames[desk.index] ?? ""
                        color: "#000000"
                    }
                    MouseArea {
                        id: deskMouse
                        anchors.fill: parent
                        onClicked: helper.setCurrentDesktop(desk.desktopId)
                    }
                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        keys: ["application/x-schiefer-task"]
                        onDropped: drop => {
                            const i = parseInt(drop.getDataAsString("application/x-schiefer-task"));
                            if (!isNaN(i)) tasksModel.requestVirtualDesktops(tasksModel.makeModelIndex(i), [desk.desktopId]);
                            drop.accept(Qt.MoveAction);
                        }
                    }
                }
            }
            // the mouse wheel switches desktops
            WheelHandler {
                onWheel: event => {
                    const ids = desktopInfo.desktopIds;
                    const cur = ids.indexOf(desktopInfo.currentDesktop);
                    const next = (cur + (event.angleDelta.y < 0 ? 1 : -1) + ids.length) % ids.length;
                    helper.setCurrentDesktop(ids[next]);
                }
            }
        }

        Etch { visible: root.cfg.showTasks }

        // ---------- Window buttons (optional; the icon box takes over otherwise) ----------
        // Hidden buttons still exist so the launch lamp keeps counting.
        Item {
            id: taskArea
            visible: root.cfg.showTasks
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: root.taskPreferred
            Layout.minimumWidth: root.taskMinimum
            Layout.maximumWidth: root.taskPreferred

            // empty, flat sunken wells for free slots
            Repeater {
                model: root.taskColumns * root.rows
                delegate: Bevel {
                    required property int index
                    x: Math.floor(index / root.rows) * (root.columnWidth + root.sp)
                    y: (index % root.rows) * (root.rowHeight + root.sp)
                    width: root.columnWidth
                    height: root.rowHeight
                    depth: 1
                    sunken: true
                    filled: false
                    visible: index >= root.shownTasks && !(root.overflow && index === root.maxSlots - 1)
                }
            }

            Repeater {
                id: taskRepeater
                model: tasksModel
                delegate: TaskButton {
                    tasksModel: tasksModel
                    visible: index < root.shownTasks
                    x: Math.floor(index / root.rows) * (root.columnWidth + root.sp)
                    y: (index % root.rows) * (root.rowHeight + root.sp)
                    width: root.columnWidth
                    height: root.rowHeight
                    onStartingChanged: Qt.callLater(root.recountStartups)
                    Component.onCompleted: Qt.callLater(root.recountStartups)
                    Component.onDestruction: Qt.callLater(root.recountStartups)
                }
            }

            // "+N": more windows in a list
            Item {
                id: moreButton
                visible: root.overflow
                x: (root.maxSlots - 1 - (root.maxSlots - 1) % root.rows) / root.rows * (root.columnWidth + root.sp)
                y: ((root.maxSlots - 1) % root.rows) * (root.rowHeight + root.sp)
                width: root.columnWidth
                height: root.rowHeight
                Bevel { anchors.fill: parent; sunken: overflowPopup.visible || moreMouse.pressed }
                Row {
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    MotifArrow {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11; height: 6
                        up: !overflowPopup.visible
                    }
                    PlasmaComponents3.Label {
                        text: root.columnWidth < Kirigami.Units.gridUnit * 8 ? "+" + (root.taskCount - root.shownTasks)
                            : i18np("%1 more window", "%1 more windows", root.taskCount - root.shownTasks)
                    }
                }
                MouseArea { id: moreMouse; anchors.fill: parent; onClicked: overflowPopup.visible = !overflowPopup.visible }
            }
        }

        // ---------- right: lamp and EXIT ----------
        ColumnLayout {
            visible: root.cfg.showExitButton
            Layout.fillHeight: true
            Layout.preferredWidth: root.sideWidth
            spacing: root.sp

            // launch lamp: lit while an application is starting
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowHeight
                Bevel {
                    id: lamp
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.7)
                    height: Math.max(6, Math.round(root.rowHeight * 0.3))
                    sunken: true
                    depth: 1
                    property bool lit: root.startupCount > 0 && blink.on
                    fill: lit ? "#e8d050" : Scheme.motifColors(Kirigami.Theme.backgroundColor).select
                }
                Timer {
                    id: blink
                    property bool on: true
                    interval: 300; repeat: true
                    running: root.startupCount > 0
                    onRunningChanged: on = true
                    onTriggered: on = !on
                }
            }
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowHeight
                // as in CDE: end the session; today that usually means power off or sleep,
                // so this opens the KDE dialog with all choices
                tip: i18n("Leave…")
                subTip: i18n("Sleep, hibernate, restart, shut down or log out")
                onClicked: helper.powerPrompt()
                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: parent.pressed ? 1 : 0
                    text: i18nc("@action:button label of the logout button in the front panel", "EXIT")
                    font.pixelSize: Math.max(9, Math.round(root.rowHeight * 0.38))
                    font.letterSpacing: 1
                }
            }
        }

        Etch {}
    }

    PlasmaCore.Dialog {
        id: overflowPopup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: moreButton
        backgroundHints: PlasmaCore.Dialog.SolidBackground
        mainItem: Column {
            spacing: root.sp
            width: root.taskWidth + Kirigami.Units.gridUnit * 4
            // popup in the front panel color like CDE drawers (option frontpanel-color)
            Kirigami.Theme.inherit: !Scheme.usePanelColor
            Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
            FrameTint {}
            Repeater {
                model: overflowPopup.visible ? tasksModel : null
                delegate: TaskButton {
                    tasksModel: tasksModel
                    width: parent.width
                    height: Math.max(root.rowHeight, Kirigami.Units.iconSizes.small + 12)
                    showTooltip: false
                    onActivated: overflowPopup.visible = false
                }
            }
        }
    }
}
