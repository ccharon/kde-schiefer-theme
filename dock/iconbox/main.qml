/*
 * Schiefer icon box: all windows in a separate panel at the screen edge
 * ("Dodge Windows" mode). Two views:
 *   list:  icon manager as in twm/FvwmIconMan, icon on the left, title to its right
 *   icons: icon box as in mwm, image in a frame, label below
 * Windows of one application stay together in the order they were opened. Only when
 * they no longer fit are they grouped; a click on a group brings its last used window forward,
 * a click on the group of the active application opens a drawer with the single windows.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import plasma.applet.org.kde.schiefer.iconbox

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
    readonly property bool listMode: cfg.display !== "icons"
    readonly property int lanes: Math.max(1, cfg.columns)
    readonly property int pad: Kirigami.Units.smallSpacing

    readonly property string currentDesktop: desktopInfo.currentDesktop
    readonly property string currentActivity: activityInfo.currentActivity

    readonly property bool showTitle: cfg.showTitle
    readonly property int titleHeight: showTitle ? titleLabel.implicitHeight + pad + 4 : 0

    // icon view: image size from the column width, cell = image + two text lines
    readonly property int laneWidth: Math.floor((sections.width) / lanes)
    readonly property int iconSize: Math.max(Kirigami.Units.iconSizes.small, Math.min(Kirigami.Units.iconSizes.large, Math.floor(laneWidth * 0.5)))
    readonly property int cellLength: iconSize + 10 + 2 * pad + 2 * Math.ceil(fontMetrics.height) + 8
    // height of an entry in the list view (WindowRow)
    readonly property int rowHeight: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.smallSpacing + 4

    // ---------- Grouping only when space runs out ----------
    // Length all windows would need without groups, against the room the well has
    // (plus what a vertical panel could still grow). Both stay the same when grouping
    // changes, so the decision does not swing back and forth.
    readonly property int ungroupedLength: {
        let n = 0, visible = 0;
        for (let i = 0; i < sectionRepeater.count; ++i) {
            const l = sectionRepeater.itemAt(i)?.ungroupedLength ?? 0;
            if (l > 0) { n += l; ++visible; }
        }
        return n + Math.max(0, visible - 1) * sections.spacing;
    }
    readonly property int availableLength: flick.height + fit.growRoom
    readonly property bool wantTight: cfg.groupWindows && flick.height > 0 && ungroupedLength > availableLength
    property bool tight: false
    onWantTightChanged: tightTimer.restart()
    // panel resizes come in several steps; decide once they settle
    Timer { id: tightTimer; interval: 300; onTriggered: root.tight = root.wantTight }

    readonly property int contentLength: sections.implicitHeight
    // length of title and well including edges, without the outer margin
    readonly property int naturalLength: (showTitle ? titleHeight + 2 : 0) + 4 + Math.max(contentLength, emptyLabel.implicitHeight + 2 * pad)
    readonly property int minimumLength: (showTitle ? titleHeight + 2 : 0) + 4 + Kirigami.Units.gridUnit * 2

    // position in the panel window (PanelFit): like the status tiles, title and well keep
    // a 3 px gap to the visible panel edges on all sides
    PanelFit {
        id: fit
        target: root
        vertical: root.vertical
    }
    readonly property int totalCount: {
        let n = 0;
        for (let i = 0; i < sectionRepeater.count; ++i) n += sectionRepeater.itemAt(i)?.count ?? 0;
        return n;
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // option frontpanel-color: surfaces in the CDE front panel color instead of the window color;
    // children inherit it through Kirigami.Theme, FrameTint also tints the panel background
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}
    Plasmoid.icon: "view-list-icons"

    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    Layout.preferredHeight: vertical ? (fit.alone ? fit.lengthFor(naturalLength) : naturalLength + 2 * pad) : -1
    Layout.minimumHeight: vertical ? (fit.alone ? fit.lengthFor(minimumLength) : minimumLength + 2 * pad) : -1
    Layout.preferredWidth: vertical ? -1 : Kirigami.Units.gridUnit * 14
    Layout.minimumWidth: vertical ? -1 : Kirigami.Units.gridUnit * 8

    FontMetrics { id: fontMetrics; font: Kirigami.Theme.smallFont }
    // mouse over the box (Section freezes the "most recently used" order meanwhile)
    readonly property bool hovered: boxHover.hovered
    HoverHandler { id: boxHover }
    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    function desktopColor(i) {
        const fromScheme = cfg.desktopColorsFromScheme ? Scheme.desktopColors : [];
        const list = fromScheme.length ? fromScheme : cfg.desktopColors;
        return list.length ? list[i % list.length] : Kirigami.Theme.backgroundColor;
    }

    // ---------- Group drawer ----------
    property var groupModel: null          // TasksModel of the open group
    property var groupPersistent: null     // QPersistentModelIndex of the group (rows move as windows come and go)
    property int groupRow: -1              // current row of the group
    readonly property var groupIndex: groupModel && groupRow >= 0 ? groupModel.makeModelIndex(groupRow) : null
    property Item groupAnchor: null
    readonly property bool groupVisible: groupPopup.visible

    function toggleGroup(model, index, anchor) {
        if (groupPopup.visible && groupAnchor === anchor) {
            closeGroup();
            return;
        }
        groupModel = model;
        groupPersistent = model.makePersistentModelIndex(index.row);
        groupRow = index.row;
        groupAnchor = anchor;
        // order by use, frozen while the list is open
        groupSnapshot = groupOrder.usageKeys(model, model.makeModelIndex(index.row));
        groupRanks = groupOrder.ranks(model, model.makeModelIndex(index.row), "", groupSnapshot);
        groupPopup.visible = true;
    }
    function closeGroup() {
        groupPopup.visible = false;
    }
    // follow the group's row; close when it is gone or no longer a group (one window left)
    function checkGroup() {
        if (!groupPopup.visible || !groupModel) return;
        if (!groupPersistent || !groupPersistent.valid) { closeGroup(); return; }
        groupRow = groupPersistent.row;
        if (groupModel.data(groupModel.makeModelIndex(groupRow), TaskManager.AbstractTasksModel.IsGroupParent) !== true) {
            closeGroup();
            return;
        }
        groupRanks = groupOrder.ranks(groupModel, groupModel.makeModelIndex(groupRow), "", groupSnapshot);
    }
    // order of the windows in the open group (TaskOrder ranks by child row)
    TaskOrder { id: groupOrder }
    property var groupRanks: []
    property var groupSnapshot: []
    Connections {
        target: root.groupModel
        function onRowsInserted() { root.checkGroup(); }
        function onRowsRemoved() { root.checkGroup(); }
        function onRowsMoved() { root.checkGroup(); }
        function onLayoutChanged() { root.checkGroup(); }
        function onDataChanged() { root.checkGroup(); }
        function onModelReset() { root.closeGroup(); }
    }

    // children of a group in opening order: [{ index, active, time }]
    function groupChildren(model, index) {
        const list = [];
        const n = model.rowCount(index);
        for (let c = 0; c < n; ++c) {
            const ci = model.makeModelIndex(index.row, c);
            const t = model.data(ci, TaskManager.AbstractTasksModel.LastActivated);
            list.push({ index: ci, active: model.data(ci, TaskManager.AbstractTasksModel.IsActive) === true,
                        time: t ? (new Date(t).getTime() || 0) : 0 });
        }
        return list;
    }
    // Click on a group: if none of its windows is active, bring the most recently used one
    // forward; if one is active (or the list is open), open or close the list.
    function clickGroup(model, index, anchor) {
        const list = groupChildren(model, index);
        if (list.some(w => w.active) || (groupPopup.visible && groupAnchor === anchor) || list.length === 0) {
            toggleGroup(model, index, anchor);
            return;
        }
        let pick = 0;
        for (let i = 1; i < list.length; ++i) if (list[i].time > list[pick].time) pick = i;
        model.requestActivate(list[pick].index);
    }
    // mouse wheel on a group: next or previous window in opening order
    function cycleGroup(model, index, step) {
        const list = groupChildren(model, index);
        if (list.length === 0) return;
        const a = list.findIndex(w => w.active);
        let pick;
        if (a < 0) {
            pick = 0;
            for (let i = 1; i < list.length; ++i) if (list[i].time > list[pick].time) pick = i;
        } else {
            pick = (a + step + list.length) % list.length;
        }
        model.requestActivate(list[pick].index);
    }

    // ---------- Shared window menu ----------
    property var menuModel: null
    property var menuIndex: null
    function role(r) {
        return menuModel && menuIndex ? menuModel.data(menuIndex, r) : undefined;
    }
    function showMenu(model, index, anchor) {
        menuModel = model;
        menuIndex = index;
        windowMenu.visualParent = anchor;
        windowMenu.openRelative();
    }

    // area for title and well: alone in the panel, the inner area of the window
    // (beyond the applet); otherwise the applet minus the margin
    Item {
        id: area
        x: fit.alone ? fit.innerX : root.pad
        y: fit.alone ? fit.innerY : root.pad
        width: fit.alone ? fit.innerWidth : root.width - 2 * root.pad
        height: fit.alone ? fit.innerHeight : root.height - 2 * root.pad
    }

    // ---------- Title bar like the header of the mwm icon box window ----------
    Item {
        id: title
        visible: root.showTitle
        anchors { left: area.left; right: area.right; top: area.top }
        height: root.titleHeight
        Bevel { anchors.fill: parent; base: Kirigami.Theme.highlightColor }
        PlasmaComponents3.Label {
            id: titleLabel
            anchors.centerIn: parent
            width: parent.width - 2 * root.pad
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: i18n("Windows")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.highlightedTextColor
        }
    }

    // ---------- Content in a sunken well ----------
    Bevel {
        id: well
        anchors {
            left: area.left; right: area.right; bottom: area.bottom
            top: root.showTitle ? title.bottom : area.top
            topMargin: root.showTitle ? 2 : 0
        }
        sunken: true
        depth: 1
        filled: false
    }

    Flickable {
        id: flick
        anchors.fill: well
        anchors.margins: 2
        clip: true
        contentWidth: width
        contentHeight: sections.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: sections
            width: flick.width
            spacing: root.pad
            Repeater {
                id: sectionRepeater
                // current desktop only: one section without a heading
                model: root.cfg.onlyCurrentDesktop ? [root.currentDesktop] : desktopInfo.desktopIds
                delegate: Section {
                    required property string modelData
                    required property int index
                    width: sections.width
                    box: root
                    desktopId: modelData
                    showHeader: !root.cfg.onlyCurrentDesktop
                    headerText: desktopInfo.desktopNames[index] ?? ""
                    headerColor: root.desktopColor(index)
                }
            }
        }
        WheelHandler {
            enabled: flick.interactive
            onWheel: event => flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - event.angleDelta.y))
        }
    }

    PlasmaComponents3.Label {
        id: emptyLabel
        anchors.centerIn: well
        width: well.width - 2 * root.pad
        visible: root.totalCount === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: i18n("No windows")
        font: Kirigami.Theme.smallFont
        opacity: 0.6
    }

    PlasmaCore.Dialog {
        id: groupPopup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: root.groupAnchor
        backgroundHints: PlasmaCore.Dialog.SolidBackground
        onVisibleChanged: if (!visible) root.groupAnchor = null
        mainItem: ColumnLayout {
            id: groupList
            width: Kirigami.Units.gridUnit * 16
            height: implicitHeight
            spacing: 2
            Keys.onEscapePressed: root.closeGroup()
            // popup in the front panel color like CDE drawers (option frontpanel-color)
            Kirigami.Theme.inherit: !Scheme.usePanelColor
            Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
            FrameTint {}

            // header like a drawer
            Item {
                Layout.fillWidth: true
                implicitHeight: groupTitle.implicitHeight + 2 * Kirigami.Units.smallSpacing + 4
                Bevel { anchors.fill: parent; base: Kirigami.Theme.highlightColor }
                PlasmaComponents3.Label {
                    id: groupTitle
                    anchors.centerIn: parent
                    width: parent.width - 2 * Kirigami.Units.largeSpacing
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.groupModel && root.groupIndex ? (root.groupModel.data(root.groupIndex, TaskManager.AbstractTasksModel.AppName) || "") : ""
                    color: Kirigami.Theme.highlightedTextColor
                }
            }
            // windows of the group, most recently used first; placed by rank, the Repeater
            // runs over the unsorted children so index is the child row
            Item {
                id: groupRows
                Layout.fillWidth: true
                implicitHeight: childRepeater.count > 0 ? childRepeater.count * (root.rowHeight + 2) - 2 : 0
                Repeater {
                    id: childRepeater
                    model: DelegateModel {
                        model: groupPopup.visible ? root.groupModel : null
                        rootIndex: root.groupIndex ?? root.groupModel?.makeModelIndex(-1)
                        delegate: WindowRow {
                            id: child
                            required property int index
                            readonly property int rank: root.groupRanks[index] ?? index
                            y: rank * (root.rowHeight + 2)
                            width: groupRows.width
                            height: root.rowHeight
                            tasksModel: root.groupModel
                            modelIndex: root.groupModel.makeModelIndex(root.groupRow, index)
                            box: root
                            inGroupPopup: true
                        }
                    }
                }
            }
        }
    }

    PlasmaExtras.Menu {
        id: windowMenu
        placement: Plasmoid.location === PlasmaCore.Types.RightEdge ? PlasmaExtras.Menu.LeftPosedTopAlignedPopup
                 : Plasmoid.location === PlasmaCore.Types.LeftEdge ? PlasmaExtras.Menu.RightPosedTopAlignedPopup
                 : PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        readonly property bool isGroup: root.role(TaskManager.AbstractTasksModel.IsGroupParent) === true
        readonly property bool minimized: root.role(TaskManager.AbstractTasksModel.IsMinimized) === true
        readonly property bool maximized: root.role(TaskManager.AbstractTasksModel.IsMaximized) === true
        readonly property bool allDesktops: root.role(TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true
        PlasmaExtras.MenuItem {
            text: windowMenu.isGroup ? (windowMenu.minimized ? i18n("Restore All") : i18n("Minimize All"))
                                     : (windowMenu.minimized ? i18n("Restore") : i18n("Minimize"))
            icon: windowMenu.minimized ? "window-restore" : "window-minimize"
            onClicked: root.menuModel.requestToggleMinimized(root.menuIndex)
        }
        PlasmaExtras.MenuItem {
            visible: !windowMenu.isGroup
            text: windowMenu.maximized ? i18n("Unmaximize") : i18n("Maximize")
            icon: windowMenu.maximized ? "window-restore" : "window-maximize"
            enabled: root.role(TaskManager.AbstractTasksModel.IsMaximizable) === true
            onClicked: root.menuModel.requestToggleMaximized(root.menuIndex)
        }
        PlasmaExtras.MenuItem {
            visible: !windowMenu.isGroup
            text: windowMenu.allDesktops ? i18n("Only on This Desktop") : i18n("On All Desktops")
            icon: "virtual-desktops"
            onClicked: root.menuModel.requestVirtualDesktops(root.menuIndex, windowMenu.allDesktops ? [root.currentDesktop] : [])
        }
        PlasmaExtras.MenuItem {
            text: i18n("New Window")
            icon: "window-new"
            onClicked: root.menuModel.requestNewInstance(root.menuIndex)
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: windowMenu.isGroup ? i18n("Close All") : i18n("Close")
            icon: "window-close"
            onClicked: root.menuModel.requestClose(root.menuIndex)
        }
    }

    // only for tools/screenshot.sh: SCHIEFER_DOCK_OPEN=<application name> opens this group
    Helper { id: helper }
    readonly property string testGroup: helper.testValue()
}
