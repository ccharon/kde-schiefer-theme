/*
 * Schiefer-Icon-Box: alle Fenster in einer eigenen Leiste am Bildschirmrand
 * (Modus „Fenstern ausweichen“). Zwei Darstellungen:
 *   Liste   – Icon-Manager wie bei twm/FvwmIconMan: Symbol links, Titel rechts daneben
 *   Symbole – Icon Box wie bei mwm: Bild im Rahmen, Beschriftung darunter
 * Fenster einer Anwendung lassen sich gruppieren; ein Klick auf die Gruppe klappt
 * seitlich eine Schublade mit den einzelnen Fenstern auf.
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
    readonly property int titleHeight: showTitle ? titleLabel.implicitHeight + 2 * pad + 4 : 0

    // Symbolansicht: Bildgröße aus der Spaltenbreite, Zelle = Bild + zwei Textzeilen
    readonly property int laneWidth: Math.floor((sections.width) / lanes)
    readonly property int iconSize: Math.max(Kirigami.Units.iconSizes.small, Math.min(Kirigami.Units.iconSizes.large, Math.floor(laneWidth * 0.5)))
    readonly property int cellLength: iconSize + 10 + 2 * pad + 2 * Math.ceil(fontMetrics.height) + 8

    readonly property int contentLength: sections.implicitHeight
    readonly property int totalCount: {
        let n = 0;
        for (let i = 0; i < sectionRepeater.count; ++i) n += sectionRepeater.itemAt(i)?.count ?? 0;
        return n;
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.icon: "view-list-icons"

    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    Layout.preferredHeight: vertical ? titleHeight + Math.max(contentLength, emptyLabel.implicitHeight + 2 * pad) + 4 * pad : -1
    Layout.minimumHeight: vertical ? titleHeight + Kirigami.Units.gridUnit * 3 : -1
    Layout.preferredWidth: vertical ? -1 : Kirigami.Units.gridUnit * 14
    Layout.minimumWidth: vertical ? -1 : Kirigami.Units.gridUnit * 8

    FontMetrics { id: fontMetrics; font: Kirigami.Theme.smallFont }
    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    function desktopColor(i) {
        const list = cfg.desktopColors;
        return list.length ? list[i % list.length] : Kirigami.Theme.backgroundColor;
    }

    // ---------- Gruppen-Schublade ----------
    property var groupModel: null          // TasksModel der geöffneten Gruppe
    property var groupIndex: null          // QModelIndex der Gruppe
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

    // ---------- gemeinsames Fenstermenü ----------
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

    // ---------- Titelleiste wie die Kopfzeile von mwms Icon-Box-Fenster ----------
    Item {
        id: title
        visible: root.showTitle
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
        height: root.titleHeight - root.pad
        Bevel { anchors.fill: parent; base: Kirigami.Theme.highlightColor }
        PlasmaComponents3.Label {
            id: titleLabel
            anchors.centerIn: parent
            width: parent.width - 2 * root.pad
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: i18n("Fenster")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.highlightedTextColor
        }
    }

    // ---------- Inhalt in einer versenkten Mulde ----------
    Bevel {
        id: well
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            top: root.showTitle ? title.bottom : parent.top
            margins: root.pad
            topMargin: root.showTitle ? 2 : root.pad
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
                // nur aktuelle Arbeitsfläche: ein Abschnitt ohne Überschrift
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
        text: i18n("Keine Fenster")
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

            // Kopfzeile wie bei einer Schublade
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
            text: windowMenu.isGroup ? (windowMenu.minimized ? i18n("Alle wiederherstellen") : i18n("Alle minimieren"))
                                     : (windowMenu.minimized ? i18n("Wiederherstellen") : i18n("Minimieren"))
            icon: windowMenu.minimized ? "window-restore" : "window-minimize"
            onClicked: root.menuModel.requestToggleMinimized(root.menuIndex)
        }
        PlasmaExtras.MenuItem {
            visible: !windowMenu.isGroup
            text: windowMenu.maximized ? i18n("Maximieren aufheben") : i18n("Maximieren")
            icon: windowMenu.maximized ? "window-restore" : "window-maximize"
            enabled: root.role(TaskManager.AbstractTasksModel.IsMaximizable) === true
            onClicked: root.menuModel.requestToggleMaximized(root.menuIndex)
        }
        PlasmaExtras.MenuItem {
            visible: !windowMenu.isGroup
            text: windowMenu.allDesktops ? i18n("Nur auf dieser Arbeitsfläche") : i18n("Auf allen Arbeitsflächen")
            icon: "virtual-desktops"
            onClicked: root.menuModel.requestVirtualDesktops(root.menuIndex, windowMenu.allDesktops ? [root.currentDesktop] : [])
        }
        PlasmaExtras.MenuItem {
            text: i18n("Neues Fenster")
            icon: "window-new"
            onClicked: root.menuModel.requestNewInstance(root.menuIndex)
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: windowMenu.isGroup ? i18n("Alle schließen") : i18n("Schließen")
            icon: "window-close"
            onClicked: root.menuModel.requestClose(root.menuIndex)
        }
    }

    // nur für tools/screenshot.sh: SCHIEFER_DOCK_OPEN=<Programmname> klappt diese Gruppe auf
    Helper { id: helper }
    readonly property string testGroup: helper.testValue()
}
