/*
 * Content of the open drawer: title, drop field, launcher list
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.draganddrop as DragAndDrop
import QtQuick.Controls as QQC2
import QtQuick.Window

Item {
    id: content

    required property var drawer
    required property var helper

    readonly property int rowHeight: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.smallSpacing + 4
    readonly property int listWidth: Math.max(Kirigami.Units.gridUnit * (drawer.isSystem ? 15 : 11), maxLabel + Kirigami.Units.iconSizes.medium + 4 * Kirigami.Units.largeSpacing)
    property int maxLabel: 0

    implicitWidth: listWidth
    implicitHeight: column.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Keys.onEscapePressed: content.Window.window.visible = false
    // popup in the front panel color like CDE drawers (option frontpanel-color)
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 2

        // title like the header of a CDE subpanel
        Item {
            Layout.fillWidth: true
            implicitHeight: titleLabel.implicitHeight + 2 * Kirigami.Units.smallSpacing + 4
            Bevel { anchors.fill: parent; base: Kirigami.Theme.highlightColor }
            PlasmaComponents3.Label {
                id: titleLabel
                anchors.centerIn: parent
                width: parent.width - 2 * Kirigami.Units.largeSpacing
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: content.drawer.drawerTitle
                color: Kirigami.Theme.highlightedTextColor
            }
        }

        // system drawer: system tray entries
        Repeater {
            model: content.drawer.isSystem ? content.drawer.trayAllModel : null
            delegate: Item {
                id: trayRow
                required property var model
                required property int index
                Layout.fillWidth: true
                implicitHeight: content.rowHeight

                Bevel {
                    anchors.fill: parent
                    sunken: (trayMouse.pressed && trayMouse.containsMouse) || trayIcon.expanded
                    base: trayMouse.containsMouse ? Scheme.hoverColor(Kirigami.Theme.backgroundColor) : Kirigami.Theme.backgroundColor
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing + 2
                    spacing: Kirigami.Units.largeSpacing
                    TrayItemIcon {
                        id: trayIcon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        model: trayRow.model
                        index: trayRow.index
                        tray: content.drawer.tray
                        interactive: false
                        onAboutToActivate: content.drawer.closeDrawer()
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: trayRow.model.displayText ?? ""
                            elide: Text.ElideRight
                            Component.onCompleted: content.maxLabel = Math.max(content.maxLabel, implicitWidth)
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            // short info (for example volume, battery level) if it differs from the name
                            readonly property string info: trayIcon.title !== trayRow.model.displayText ? trayIcon.title : trayIcon.subTitle
                            visible: text.length > 0
                            text: info.split("\n")[0]
                            textFormat: Text.PlainText
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                }
                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => event.button === Qt.RightButton ? trayIcon.contextMenu() : trayIcon.activate()
                }
            }
        }

        // system drawer: configure the system tray
        Item {
            Layout.fillWidth: true
            visible: content.drawer.isSystem
            implicitHeight: content.rowHeight
            Bevel {
                anchors.fill: parent
                sunken: cfgMouse.pressed && cfgMouse.containsMouse
                base: cfgMouse.containsMouse ? Scheme.hoverColor(Kirigami.Theme.backgroundColor) : Kirigami.Theme.backgroundColor
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing + 2
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    source: "configure"
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Configure System Tray…")
                    elide: Text.ElideRight
                    Component.onCompleted: content.maxLabel = Math.max(content.maxLabel, implicitWidth)
                }
            }
            MouseArea {
                id: cfgMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    content.drawer.closeDrawer();
                    content.drawer.tray.configureTray();
                }
            }
        }

        // folder drawer: folder contents, scrollable with many entries
        ListView {
            id: folderList
            visible: content.drawer.isFolder
            Layout.fillWidth: true
            readonly property int maxRows: Math.max(4, Math.floor((Screen.height * 0.6) / (content.rowHeight + spacing)))
            Layout.preferredHeight: visible ? Math.min(count, maxRows) * (content.rowHeight + spacing) - (count ? spacing : 0) : 0
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: content.drawer.isFolder ? content.drawer.folder : null
            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: folderList.count > folderList.maxRows ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff }
            delegate: Item {
                id: fileEntry
                required property string name
                required property string iconName
                required property string url
                required property bool isDir
                required property string detail
                width: folderList.width - (folderList.count > folderList.maxRows ? Kirigami.Units.gridUnit : 0)
                height: content.rowHeight

                Bevel {
                    anchors.fill: parent
                    sunken: fileMouse.pressed && fileMouse.containsMouse
                    base: fileMouse.containsMouse ? Scheme.hoverColor(Kirigami.Theme.backgroundColor) : Kirigami.Theme.backgroundColor
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing + 2
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        source: fileEntry.iconName
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: fileEntry.name
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            Component.onCompleted: content.maxLabel = Math.max(content.maxLabel, Math.min(implicitWidth, Kirigami.Units.gridUnit * 20))
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: fileEntry.detail
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                }
                MouseArea {
                    id: fileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: content.drawer.openEntry(fileEntry.url)
                }
            }
        }
        PlasmaComponents3.Label {
            visible: content.drawer.isFolder && content.drawer.folder.count === 0
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignHCenter
            text: content.drawer.folderUrl ? i18n("The folder is empty") : i18n("No folder chosen")
            opacity: 0.7
        }

        // drop field ("Install Icon")
        Item {
            visible: !content.drawer.isSystem && !content.drawer.isFolder
            Layout.fillWidth: true
            implicitHeight: content.rowHeight
            Bevel { anchors.fill: parent; sunken: true; filled: dropZone.containsDrag; fill: Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.25)) }
            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing + 2
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    source: "list-add"
                    opacity: 0.6
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Drop an icon here")
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: content.helper.chooseLauncher("drawer")
            }
            DragAndDrop.DropArea {
                id: dropZone
                property bool containsDrag: false
                anchors.fill: parent
                onDragEnter: event => { if (event.mimeData.hasUrls) containsDrag = true; else event.ignore(); }
                onDragLeave: containsDrag = false
                onDrop: event => {
                    containsDrag = false;
                    event.mimeData.urls.forEach(u => content.drawer.addToDrawer(u.toString(), -1));
                }
            }
        }

        Repeater {
            model: content.drawer.drawerUrls
            delegate: Item {
                id: entry
                required property string modelData
                required property int index
                readonly property var info: content.helper.launcherData(modelData)
                readonly property int running: content.drawer.runningCount(modelData)
                // open windows for the context menu, read when it opens
                property var menuWindows: []

                Layout.fillWidth: true
                implicitHeight: content.rowHeight

                Bevel {
                    anchors.fill: parent
                    sunken: mouse.pressed && mouse.containsMouse
                    base: mouse.containsMouse ? Scheme.hoverColor(Kirigami.Theme.backgroundColor) : Kirigami.Theme.backgroundColor
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing + 2
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        source: entry.info.icon
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: entry.info.name
                        elide: Text.ElideRight
                        Component.onCompleted: content.maxLabel = Math.max(content.maxLabel, implicitWidth)
                    }
                    RunningMark {
                        Layout.alignment: Qt.AlignVCenter
                        visible: entry.running > 0
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouseEvent => {
                        if (mouseEvent.button === Qt.RightButton) {
                            entry.menuWindows = content.drawer.windowsOf(entry.modelData).windows;
                            menu.visualParent = entry;
                            menu.openRelative();
                        } else {
                            content.drawer.launch(entry.modelData, mouseEvent.button === Qt.MiddleButton
                                                                   || (mouseEvent.modifiers & Qt.ShiftModifier));
                        }
                    }
                }
                DragAndDrop.DropArea {
                    anchors.fill: parent
                    onDragEnter: event => { if (!event.mimeData.hasUrls) event.ignore(); }
                    onDrop: event => event.mimeData.urls.forEach(u => content.drawer.addToDrawer(u.toString(), entry.index))
                }
                // open windows of the program at the top of the menu, before "New Window".
                // PlasmaExtras.Menu only takes MenuItems as children, so this sits beside it.
                Instantiator {
                    model: entry.menuWindows
                    delegate: PlasmaExtras.MenuItem {
                        required property var modelData
                        text: modelData.title
                        icon: modelData.icon
                        checkable: true
                        checked: modelData.active
                        onClicked: content.drawer.activateWindow(modelData.index)
                    }
                    onObjectAdded: (i, item) => menu.addMenuItem(item, newWindowItem)
                    onObjectRemoved: (i, item) => menu.removeMenuItem(item)
                }
                PlasmaExtras.Menu {
                    id: menu
                    placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
                    PlasmaExtras.MenuItem {
                        id: newWindowItem
                        visible: entry.running > 0
                        text: i18n("New Window")
                        icon: "window-new"
                        onClicked: content.drawer.launch(entry.modelData, true)
                    }
                    PlasmaExtras.MenuItem { separator: true; visible: entry.running > 0 }
                    PlasmaExtras.MenuItem {
                        text: i18n("Use as Main Icon in the Panel")
                        icon: "go-down"
                        onClicked: content.drawer.promote(entry.index)
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Move Up")
                        icon: "arrow-up"
                        enabled: entry.index > 0
                        onClicked: content.drawer.moveInDrawer(entry.index, entry.index - 1)
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Move Down")
                        icon: "arrow-down"
                        enabled: entry.index < content.drawer.drawerUrls.length - 1
                        onClicked: content.drawer.moveInDrawer(entry.index, entry.index + 1)
                    }
                    PlasmaExtras.MenuItem { separator: true }
                    PlasmaExtras.MenuItem {
                        text: i18n("Remove from Drawer")
                        icon: "list-remove"
                        onClicked: content.drawer.removeFromDrawer(entry.index)
                    }
                }
            }
        }
    }
}
