/*
 * Inhalt der ausgeklappten Schublade: Titel, Ablagefeld, Starterliste
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

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

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 2

        // Titel wie die Kopfzeile eines CDE-Subpanels
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

        // System-Schublade: Einträge des Systemabschnitts
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
                    base: trayMouse.containsMouse ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.15)) : Kirigami.Theme.backgroundColor
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
                            // Kurzinfo (z. B. Lautstärke, Akkustand), sofern sie sich vom Namen unterscheidet
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

        // System-Schublade: Systemabschnitt einrichten
        Item {
            Layout.fillWidth: true
            visible: content.drawer.isSystem
            implicitHeight: content.rowHeight
            Bevel {
                anchors.fill: parent
                sunken: cfgMouse.pressed && cfgMouse.containsMouse
                base: cfgMouse.containsMouse ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.15)) : Kirigami.Theme.backgroundColor
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
                    text: i18n("Systemabschnitt einrichten …")
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

        // Ordner-Schublade: Inhalt des Ordners, bei vielen Einträgen rollbar
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
                    base: fileMouse.containsMouse ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.15)) : Kirigami.Theme.backgroundColor
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
            text: content.drawer.folderUrl ? i18n("Der Ordner ist leer") : i18n("Kein Ordner gewählt")
            opacity: 0.7
        }

        // Ablagefeld („Install Icon“)
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
                    text: i18n("Symbol hier ablegen")
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

                Layout.fillWidth: true
                implicitHeight: content.rowHeight

                Bevel {
                    anchors.fill: parent
                    sunken: mouse.pressed && mouse.containsMouse
                    base: mouse.containsMouse ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.15)) : Kirigami.Theme.backgroundColor
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
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouseEvent => {
                        if (mouseEvent.button === Qt.RightButton) {
                            menu.visualParent = entry;
                            menu.openRelative();
                        } else {
                            content.drawer.launch(entry.modelData);
                        }
                    }
                }
                DragAndDrop.DropArea {
                    anchors.fill: parent
                    onDragEnter: event => { if (!event.mimeData.hasUrls) event.ignore(); }
                    onDrop: event => event.mimeData.urls.forEach(u => content.drawer.addToDrawer(u.toString(), entry.index))
                }
                PlasmaExtras.Menu {
                    id: menu
                    placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
                    PlasmaExtras.MenuItem {
                        text: i18n("Als Hauptsymbol ins Panel")
                        icon: "go-down"
                        onClicked: content.drawer.promote(entry.index)
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Nach oben")
                        icon: "arrow-up"
                        enabled: entry.index > 0
                        onClicked: content.drawer.moveInDrawer(entry.index, entry.index - 1)
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Nach unten")
                        icon: "arrow-down"
                        enabled: entry.index < content.drawer.drawerUrls.length - 1
                        onClicked: content.drawer.moveInDrawer(entry.index, entry.index + 1)
                    }
                    PlasmaExtras.MenuItem { separator: true }
                    PlasmaExtras.MenuItem {
                        text: i18n("Aus der Schublade entfernen")
                        icon: "list-remove"
                        onClicked: content.drawer.removeFromDrawer(entry.index)
                    }
                }
            }
        }
    }
}
