/*
 * Schiefer icon box: all windows in a separate panel at the screen edge
 * ("Dodge Windows" mode). Two views:
 *   list:  icon manager as in twm/FvwmIconMan, icon on the left, title to its right
 *   icons: icon box as in mwm, image in a frame, label below
 * Windows of one application can be grouped; a click on the group opens a drawer
 * with the single windows to the side.
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
    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    function desktopColor(i) {
        const fromScheme = cfg.desktopColorsFromScheme ? Scheme.desktopColors : [];
        const list = fromScheme.length ? fromScheme : cfg.desktopColors;
        return list.length ? list[i % list.length] : Kirigami.Theme.backgroundColor;
    }

    // ---------- Group drawer ----------
    property var groupModel: null          // TasksModel of the open group
    property var groupIndex: null          // QModelIndex of the group
    property Item groupAnchor: null
    readonly property bool groupVisible: groupPopup.visible

    function toggleGroup(model, index, anchor) {
        if (groupPopup.visible && groupAnchor === anchor) {
            closeGroup();
            return;
        }
        groupModel = model;
        groupIndex = index;
        groupAnchor = anchor;
        groupPopup.visible = true;
    }
    function closeGroup() {
        groupPopup.visible = false;
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
            Repeater {
                model: DelegateModel {
                    model: groupPopup.visible ? root.groupModel : null
                    rootIndex: root.groupIndex ?? root.groupModel?.makeModelIndex(-1)
                    delegate: WindowRow {
                        id: child
                        required property int index
                        Layout.fillWidth: true
                        tasksModel: root.groupModel
                        modelIndex: root.groupModel.makeModelIndex(root.groupIndex.row, index)
                        box: root
                        inGroupPopup: true
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
