/*
 * Schiefer drawer: large icon in the front panel with a tab above it that slides up a list
 * of more launchers (CDE subpanel).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.draganddrop as DragAndDrop
import org.kde.kitemmodels as KItemModels
import org.kde.taskmanager as TaskManager
import QtQuick.Dialogs as Dialogs
import QtCore
import plasma.applet.org.kde.schiefer.drawer

PlasmoidItem {
    id: root

    readonly property string face: Plasmoid.configuration.face
    readonly property string mainUrl: Plasmoid.configuration.mainUrl
    readonly property var drawerUrls: Plasmoid.configuration.drawerUrls
    readonly property var mainData: mainUrl ? helper.launcherData(mainUrl) : ({})
    readonly property string drawerTitle: Plasmoid.configuration.title
        || (mainData.name ?? "")
        || (isFolder ? folder.folderName : "")
        || (face === "clock" ? i18n("Clock") : face === "date" ? i18n("Calendar") : face === "system" ? i18n("System") : i18n("Drawer"))
    readonly property bool isSystem: face === "system"
    readonly property bool isFolder: face === "folder"
    readonly property string folderUrl: Plasmoid.configuration.folderUrl

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int tabSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.7))
    readonly property int pad: Kirigami.Units.smallSpacing
    // side length of the icon field, derived from the panel thickness
    readonly property int faceSize: vertical ? width - 2 * pad : height - tabSize - 2 * pad
    readonly property bool drawerOpen: popup.visible

    // shared time for clock, calendar page and tooltip; ticks exactly on the full minute
    property date now: new Date()
    function refreshNow() {
        const d = new Date();
        root.now = d;
        minuteTimer.interval = (60 - d.getSeconds()) * 1000 - d.getMilliseconds() + 50;
        minuteTimer.restart();
    }
    Timer {
        id: minuteTimer
        running: root.face === "clock" || root.face === "date"
        interval: 1000
        onTriggered: root.refreshNow()
        Component.onCompleted: if (running) root.refreshNow()
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // option frontpanel-color: surfaces in the CDE front panel color instead of the window color;
    // children inherit it through Kirigami.Theme, FrameTint also tints the panel background
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}
    Plasmoid.icon: isSystem ? "preferences-system" : isFolder ? folder.folderIcon : (mainData.icon ?? "go-up")
    toolTipMainText: ""

    Layout.minimumWidth: vertical ? -1 : Math.max(faceSize, Kirigami.Units.iconSizes.medium) + 4 * pad
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: vertical ? width - 2 * pad + tabSize + 2 * pad : -1
    Layout.maximumHeight: Layout.minimumHeight

    Helper {
        id: helper
        onLauncherChosen: (url, tag) => {
            if (tag === "main") {
                Plasmoid.configuration.mainUrl = url;
            } else {
                root.addToDrawer(url, -1);
            }
        }
    }

    function addToDrawer(url, at) {
        const list = drawerUrls.slice();
        const old = list.indexOf(url);
        if (old >= 0) list.splice(old, 1);
        if (at < 0 || at > list.length) list.push(url); else list.splice(at, 0, url);
        Plasmoid.configuration.drawerUrls = list;
    }
    // Indices come from delegates that may already be stale while the model is rebuilt;
    // splice(-1, 1) would otherwise silently delete the last entry
    function validIndex(index) {
        return Number.isInteger(index) && index >= 0 && index < drawerUrls.length;
    }
    function removeFromDrawer(index) {
        if (!validIndex(index)) return;
        const list = drawerUrls.slice();
        list.splice(index, 1);
        Plasmoid.configuration.drawerUrls = list;
    }
    function moveInDrawer(from, to) {
        if (!validIndex(from) || !validIndex(to) || from === to) return;
        const list = drawerUrls.slice();
        const [u] = list.splice(from, 1);
        list.splice(to, 0, u);
        Plasmoid.configuration.drawerUrls = list;
    }
    // a drawer entry becomes the main icon, and the old main icon takes its place
    function promote(index) {
        if (!validIndex(index)) return;
        const list = drawerUrls.slice();
        const u = list[index];
        if (mainUrl) list[index] = mainUrl; else list.splice(index, 1);
        Plasmoid.configuration.drawerUrls = list;
        Plasmoid.configuration.mainUrl = u;
    }
    function closeDrawer() { popup.visible = false; }

    // ---------- Running applications ----------
    // A click on a launcher brings the program forward if it already runs; middle click
    // (or Shift+click) always starts a new instance.
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortDisabled   // source order = order of opening
        separateLaunchers: false
        launcherList: []
        filterByActivity: true
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: false
        filterByScreen: false
    }
    // bindings that ask about windows read this so they follow the task list
    property int taskRevision: 0
    Connections {
        target: tasks
        function onRowsInserted() { root.taskRevision++; }
        function onRowsRemoved() { root.taskRevision++; }
        function onModelReset() { root.taskRevision++; }
        function onDataChanged() { root.taskRevision++; }
    }
    // launcher URL of a task -> desktop entry id; KService lookups only once per URL
    property var appIdCache: ({})
    function taskAppId(idx) {
        const u = tasks.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
        const key = u ? u.toString() : "";
        let id = key ? root.appIdCache[key] : undefined;
        if (id === undefined) {
            id = key ? helper.appId(u) : "";
            if (key) root.appIdCache[key] = id;
        }
        // AppId carries ".desktop" on Wayland ("org.kde.kwrite.desktop")
        return (id || tasks.data(idx, TaskManager.AbstractTasksModel.AppId) || "").replace(/\.desktop$/, "").toLowerCase();
    }
    // windows of a launcher in the order they were opened: [{ index, title, icon, active, time }],
    // plus whether the program is just starting
    function windowsOf(url) {
        root.taskRevision;
        const id = url ? helper.appId(url).toLowerCase() : "";
        const result = { windows: [], starting: false };
        if (!id) return result;
        for (let i = 0; i < tasks.count; ++i) {
            const idx = tasks.makeModelIndex(i);
            if (root.taskAppId(idx) !== id) continue;
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsStartup) === true) {
                result.starting = true;
            } else if (tasks.data(idx, TaskManager.AbstractTasksModel.IsWindow) === true) {
                const t = tasks.data(idx, TaskManager.AbstractTasksModel.LastActivated);
                result.windows.push({
                    index: idx,
                    title: tasks.data(idx, Qt.DisplayRole) || "",
                    icon: tasks.data(idx, Qt.DecorationRole),
                    active: tasks.data(idx, TaskManager.AbstractTasksModel.IsActive) === true,
                    time: t ? (new Date(t).getTime() || 0) : 0
                });
            }
        }
        return result;
    }
    function runningCount(url) { return url ? root.windowsOf(url).windows.length : 0; }
    // none of its windows active: the most recently used one; otherwise the next one in opening order
    function activateNext(windows) {
        const a = windows.findIndex(w => w.active);
        let pick = 0;
        if (a >= 0) {
            pick = (a + 1) % windows.length;
        } else {
            for (let i = 1; i < windows.length; ++i) if (windows[i].time > windows[pick].time) pick = i;
        }
        if (pick !== a) tasks.requestActivate(windows[pick].index);
    }
    function activateWindow(index) {
        popup.visible = false;
        tasks.requestActivate(index);
    }
    // a second click within the double-click time does nothing (CDE habit: double click)
    Timer { id: clickGuard; interval: Qt.styleHints.mouseDoubleClickInterval }

    function launch(url, newInstance) {
        if (clickGuard.running) return;
        clickGuard.restart();
        popup.visible = false;
        if (!newInstance || helper.singleMainWindow(url)) {
            const running = root.windowsOf(url);
            if (running.windows.length > 0) {
                root.activateNext(running.windows);
                return;
            }
            // already on its way (startup notification): a second instance is not wanted
            if (running.starting && !newInstance) return;
        }
        helper.openUrl(url);
        launchFeedback.restart();
    }
    // folder drawer entry: open it, but never run programs or scripts
    function openEntry(url) {
        popup.visible = false;
        helper.openFile(url);
        launchFeedback.restart();
    }

    // ---------- Folder (face "folder" only) ----------
    FolderModel {
        id: folder
        url: root.isFolder ? root.folderUrl : ""
    }
    readonly property alias folder: folder
    Dialogs.FolderDialog {
        id: folderDialog
        title: i18n("Choose a folder for the drawer")
        currentFolder: root.folderUrl || "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation)
        onAccepted: Plasmoid.configuration.folderUrl = selectedFolder.toString()
    }

    // ---------- System tray (face "system" only) ----------
    TrayBridge {
        id: tray
        applet: root.isSystem ? Plasmoid : null
        popupAnchor: root
        hideTray: root.isSystem && Plasmoid.configuration.hideTray
    }
    readonly property alias tray: tray
    // in the face: what the system tray would show in the panel
    KItemModels.KSortFilterProxyModel {
        id: trayActive
        sourceModel: tray.model
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) =>
            sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole) === PlasmaCore.Types.ActiveStatus
    }
    // in the drawer: all visible entries
    KItemModels.KSortFilterProxyModel {
        id: trayAll
        sourceModel: tray.model
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => {
            const st = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole);
            return st === PlasmaCore.Types.ActiveStatus || st === PlasmaCore.Types.PassiveStatus;
        }
    }
    readonly property alias trayAllModel: trayAll

    // only for tools/screenshot.sh: SCHIEFER_DOCK_OPEN=<title> opens this drawer on start
    Timer {
        interval: 1500; running: helper.testOpen(root.drawerTitle)
        onTriggered: popup.visible = true
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Choose Folder…")
            icon.name: "folder-open"
            visible: root.isFolder
            onTriggered: folderDialog.open()
        },
        PlasmaCore.Action {
            text: i18n("Choose Main Application…")
            visible: !root.isFolder
            icon.name: "document-edit"
            onTriggered: helper.chooseLauncher("main")
        },
        PlasmaCore.Action {
            text: i18n("New Window")
            icon.name: "window-new"
            visible: !root.isFolder && root.mainUrl.length > 0 && root.runningCount(root.mainUrl) > 0
            onTriggered: root.launch(root.mainUrl, true)
        },
        PlasmaCore.Action {
            text: i18n("Add Application to Drawer…")
            visible: !root.isFolder
            icon.name: "list-add"
            onTriggered: helper.chooseLauncher("drawer")
        }
    ]

    // ---------- Tab ----------
    Item {
        id: tab
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.tabSize

        Bevel {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            // sunken as in CDE; the well darkens when pressed
            sunken: true
            fill: tabMouse.pressed ? Qt.tint(base, Qt.rgba(0, 0, 0, 0.12)) : base
        }
        MotifArrow {
            anchors.centerIn: parent
            // small and fine (1 px edges), half as high as wide, with room inside the bar
            width: (root.tabSize - 2) | 1
            height: (width + 1) / 2
            visible: root.drawerUrls.length > 0 || root.drawerOpen || root.isSystem || root.isFolder
            up: !root.drawerOpen
            sunken: true
        }
        MouseArea {
            id: tabMouse
            anchors.fill: parent
            onClicked: popup.visible = !popup.visible
        }
        DragAndDrop.DropArea {
            anchors.fill: parent
            onDragEnter: event => { if (!event.mimeData.hasUrls || root.isFolder) event.ignore(); else popup.visible = true; }
            onDrop: event => event.mimeData.urls.forEach(u => root.addToDrawer(u.toString(), -1))
        }
    }

    // ---------- Symbolfeld ----------
    Item {
        id: faceArea
        anchors { left: parent.left; right: parent.right; top: tab.bottom; bottom: parent.bottom }

        Bevel {
            anchors.fill: parent
            anchors.margins: 1
            visible: faceMouse.pressed && faceMouse.containsMouse
            sunken: true
            filled: false
        }

        Loader {
            id: faceLoader
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 2 * root.pad
            height: width
            sourceComponent: root.face === "clock" ? clockFace : root.face === "date" ? dateFace : root.isSystem ? systemFace : iconFace
        }
        Component {
            id: iconFace
            Kirigami.Icon {
                source: root.isFolder ? folder.folderIcon : (root.mainData.icon ?? "list-add")
                active: faceMouse.containsMouse
                opacity: (root.isFolder ? root.folderUrl : root.mainUrl) ? 1 : 0.4
                // small hop on launch, like the blinking lamp in the original
                transform: Translate { id: hop; y: 0 }
                SequentialAnimation {
                    id: hopAnim
                    NumberAnimation { target: hop; property: "y"; to: -3; duration: 90 }
                    NumberAnimation { target: hop; property: "y"; to: 0; duration: 150; easing.type: Easing.OutBounce }
                }
                Connections {
                    target: root
                    function onLaunchFeedbackRequested() { hopAnim.restart(); }
                }
            }
        }
        RunningMark {
            anchors { left: parent.left; bottom: parent.bottom; margins: 3 }
            visible: !root.isFolder && root.runningCount(root.mainUrl) > 0
        }
        Component { id: clockFace; ClockFace { now: root.now } }
        Component { id: dateFace; DateFace { today: root.now } }
        Component {
            id: systemFace
            SystemFace {
                tray: tray
                model: trayActive
                onOpenDrawer: popup.visible = !popup.visible
            }
        }

        MouseArea {
            id: faceMouse
            anchors.fill: parent
            // the system icons take their own clicks
            enabled: !root.isSystem
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: event => {
                const newInstance = event.button === Qt.MiddleButton || (event.modifiers & Qt.ShiftModifier);
                if (root.isFolder) {
                    // folder.url: already resolved ("~/...", relative paths)
                    if (root.folderUrl) root.launch(folder.url, true); else folderDialog.open();
                } else if (root.mainUrl) root.launch(root.mainUrl, newInstance);
                else if (root.face === "launcher") helper.chooseLauncher("main");
                else popup.visible = !popup.visible;
            }
        }
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            active: !root.isSystem
            // after hibernation or similar the minute tick can lag behind
            onContainsMouseChanged: if (containsMouse && (root.face === "clock" || root.face === "date")) root.refreshNow()
            mainText: root.isFolder ? (root.folderUrl ? folder.folderName : i18n("No folder chosen"))
                    : (root.face === "date" || root.face === "clock") ? Qt.formatDate(root.now, Qt.locale().dateFormat(Locale.LongFormat))
                    : (root.mainData.name ?? i18n("No application"))
            subText: root.isFolder ? (root.folderUrl ? i18np("%1 entry. Click to open the folder.", "%1 entries. Click to open the folder.", folder.count) : i18n("Click to choose a folder"))
                   : root.mainUrl ? [root.mainData.genericName ?? "",
                                     root.runningCount(root.mainUrl) > 0 ? i18n("Running. Click brings it forward, middle click opens a new window.") : ""].filter(t => t).join("\n")
                   : i18n("Click or drag an application here")
            location: Plasmoid.location
        }
        DragAndDrop.DropArea {
            anchors.fill: parent
            onDragEnter: event => { if (!event.mimeData.hasUrls || root.isFolder) event.ignore(); }
            onDrop: event => {
                const urls = event.mimeData.urls.map(u => u.toString());
                if (!root.mainUrl) Plasmoid.configuration.mainUrl = urls.shift();
                urls.forEach(u => root.addToDrawer(u, -1));
            }
        }
    }

    signal launchFeedbackRequested()
    Timer { id: launchFeedback; interval: 1; onTriggered: root.launchFeedbackRequested() }

    PlasmaCore.Dialog {
        id: popup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: root
        backgroundHints: PlasmaCore.Dialog.SolidBackground
        mainItem: DrawerPopup {
            drawer: root
            helper: helper
        }
    }
}
