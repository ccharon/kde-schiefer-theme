/*
 * Schiefer-Schublade: großes Symbol im Frontpanel, darüber eine Lasche, die eine Liste
 * weiterer Starter nach oben ausklappt (CDE-Subpanel).
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
        || (face === "clock" ? i18n("Uhr") : face === "date" ? i18n("Kalender") : face === "system" ? i18n("System") : i18n("Schublade"))
    readonly property bool isSystem: face === "system"
    readonly property bool isFolder: face === "folder"
    readonly property string folderUrl: Plasmoid.configuration.folderUrl

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int tabSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.7))
    readonly property int pad: Kirigami.Units.smallSpacing
    // Seitenlänge des Symbolfelds: aus der Leistendicke abgeleitet
    readonly property int faceSize: vertical ? width - 2 * pad : height - tabSize - 2 * pad
    readonly property bool drawerOpen: popup.visible

    // gemeinsame Zeit für Uhr, Kalenderblatt und Tooltip; springt genau zur vollen Minute
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
    // Schalter frontpanel-farbe: Flächen in der CDE-Frontpanel-Farbe statt der Fensterfarbe;
    // Kinder erben sie über Kirigami.Theme, FrameTint färbt den Leistenhintergrund mit
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
    // Indizes kommen aus Delegaten, die beim Umbau des Modells schon veraltet sein können;
    // splice(-1, 1) würde sonst still den letzten Eintrag löschen
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
    // Eintrag aus der Schublade wird Hauptsymbol, das alte Hauptsymbol rutscht an seine Stelle
    function promote(index) {
        if (!validIndex(index)) return;
        const list = drawerUrls.slice();
        const u = list[index];
        if (mainUrl) list[index] = mainUrl; else list.splice(index, 1);
        Plasmoid.configuration.drawerUrls = list;
        Plasmoid.configuration.mainUrl = u;
    }
    function closeDrawer() { popup.visible = false; }
    function launch(url) {
        popup.visible = false;
        helper.openUrl(url);
        launchFeedback.restart();
    }
    // Eintrag der Ordner-Schublade: öffnen, aber keine Programme/Skripte ausführen
    function openEntry(url) {
        popup.visible = false;
        helper.openFile(url);
        launchFeedback.restart();
    }

    // ---------- Ordner (nur Gesicht „folder“) ----------
    FolderModel {
        id: folder
        url: root.isFolder ? root.folderUrl : ""
    }
    readonly property alias folder: folder
    Dialogs.FolderDialog {
        id: folderDialog
        title: i18n("Ordner für die Schublade wählen")
        currentFolder: root.folderUrl || "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation)
        onAccepted: Plasmoid.configuration.folderUrl = selectedFolder.toString()
    }

    // ---------- Systemabschnitt (nur Gesicht „system“) ----------
    TrayBridge {
        id: tray
        applet: root.isSystem ? Plasmoid : null
        popupAnchor: root
        hideTray: root.isSystem && Plasmoid.configuration.hideTray
    }
    readonly property alias tray: tray
    // im Gesicht: was der Systray im Panel zeigen würde
    KItemModels.KSortFilterProxyModel {
        id: trayActive
        sourceModel: tray.model
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) =>
            sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole) === PlasmaCore.Types.ActiveStatus
    }
    // in der Schublade: alle sichtbaren Einträge
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

    // nur für tools/screenshot.sh: SCHIEFER_DOCK_OPEN=<Titel> öffnet diese Schublade beim Start
    Timer {
        interval: 1500; running: helper.testOpen(root.drawerTitle)
        onTriggered: popup.visible = true
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Ordner wählen …")
            icon.name: "folder-open"
            visible: root.isFolder
            onTriggered: folderDialog.open()
        },
        PlasmaCore.Action {
            text: i18n("Hauptprogramm wählen …")
            visible: !root.isFolder
            icon.name: "document-edit"
            onTriggered: helper.chooseLauncher("main")
        },
        PlasmaCore.Action {
            text: i18n("Programm in die Schublade legen …")
            visible: !root.isFolder
            icon.name: "list-add"
            onTriggered: helper.chooseLauncher("drawer")
        }
    ]

    // ---------- Lasche ----------
    Item {
        id: tab
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.tabSize

        Bevel {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            // wie in CDE versenkt; beim Drücken dunkelt die Mulde nach
            sunken: true
            fill: tabMouse.pressed ? Qt.tint(base, Qt.rgba(0, 0, 0, 0.12)) : base
        }
        MotifArrow {
            anchors.centerIn: parent
            // klein und fein (1-px-Kanten), halb so hoch wie breit, mit Luft im Balken
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
                // kleiner Hüpfer beim Start, wie die blinkende Lampe im Original
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
            // die Systemsymbole nehmen ihre Klicks selbst
            enabled: !root.isSystem
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (root.isFolder) {
                    // folder.url: schon aufgelöst („~/…“, relative Pfade)
                    if (root.folderUrl) root.launch(folder.url); else folderDialog.open();
                } else if (root.mainUrl) root.launch(root.mainUrl);
                else if (root.face === "launcher") helper.chooseLauncher("main");
                else popup.visible = !popup.visible;
            }
        }
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            active: !root.isSystem
            // nach Ruhezustand o. Ä. kann der Minutentakt hinterherhinken
            onContainsMouseChanged: if (containsMouse && (root.face === "clock" || root.face === "date")) root.refreshNow()
            mainText: root.isFolder ? (root.folderUrl ? folder.folderName : i18n("Kein Ordner gewählt"))
                    : (root.face === "date" || root.face === "clock") ? Qt.formatDate(root.now, Qt.locale().dateFormat(Locale.LongFormat))
                    : (root.mainData.name ?? i18n("Kein Programm"))
            subText: root.isFolder ? (root.folderUrl ? i18np("%1 Eintrag – Klick öffnet den Ordner", "%1 Einträge – Klick öffnet den Ordner", folder.count) : i18n("Klicken, um einen Ordner zu wählen"))
                   : root.mainUrl ? (root.mainData.genericName ?? "") : i18n("Klicken oder Programm hierher ziehen")
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
