/*
 * Schiefer-Statuskacheln: die Einträge des Plasma-Systemabschnitts als quadratische
 * Motif-Kacheln wie die Dockapps von Window Maker. Aktive Einträge bekommen eine Kachel,
 * die übrigen liegen in einer Liste hinter der Pfeilkachel.
 * Der Plasma-Systray muss im selben Panel stecken; die Brücke blendet ihn aus.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import plasma.applet.org.kde.schiefer.tiles

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
    readonly property int sp: 2
    readonly property int tile: Math.max(Kirigami.Units.iconSizes.small + 8, (vertical ? width : height))
    readonly property int iconMargin: Math.round(tile * (1 - Plasmoid.configuration.iconScale / 100) / 2)
    // höchstens maxTiles Kacheln (0 = alle aktiven), der Rest kommt in die Liste hinter dem Pfeil
    readonly property int maxTiles: Plasmoid.configuration.maxTiles
    readonly property int shownTiles: maxTiles > 0 ? Math.min(maxTiles, trayActive.count) : trayActive.count
    readonly property int overflowCount: trayActive.count - shownTiles + trayPassive.count
    readonly property int tileCount: shownTiles + (moreTile.visible ? 1 : 0)
    readonly property int length: Math.max(1, tileCount) * (tile + sp) - sp

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.icon: "preferences-system"

    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    Layout.preferredHeight: vertical ? length : -1
    Layout.minimumHeight: vertical ? length : -1
    Layout.maximumHeight: vertical ? length : -1
    Layout.preferredWidth: vertical ? -1 : length
    Layout.minimumWidth: vertical ? -1 : length
    Layout.maximumWidth: vertical ? -1 : length

    TrayBridge {
        id: tray
        applet: Plasmoid
        popupAnchor: root
        hideTray: Plasmoid.configuration.hideTray
    }
    KItemModels.KSortFilterProxyModel {
        id: trayActive
        sourceModel: tray.model
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) =>
            sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole) === PlasmaCore.Types.ActiveStatus
    }
    KItemModels.KSortFilterProxyModel {
        id: trayPassive
        sourceModel: tray.model
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) =>
            sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole) === PlasmaCore.Types.PassiveStatus
    }

    // nur für tools/screenshot.sh: SCHIEFER_DOCK_TRAY=more öffnet die Liste
    Timer {
        interval: 2500
        running: tray.testItem === "more"
        onTriggered: listPopup.visible = true
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Systemabschnitt einrichten …")
            icon.name: "configure"
            onTriggered: tray.configureTray()
        }
    ]

    Flow {
        id: flow
        anchors.fill: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: root.sp

        Repeater {
            model: trayActive
            delegate: Item {
                id: tileItem
                required property var model
                required property int index
                visible: index < root.shownTiles
                width: root.tile
                height: root.tile
                Bevel {
                    anchors.fill: parent
                    sunken: icon.expanded
                    fill: icon.expanded ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.18)) : Kirigami.Theme.backgroundColor
                }
                TrayItemIcon {
                    id: icon
                    anchors.fill: parent
                    model: tileItem.model
                    index: tileItem.index
                    tray: tray
                    anchorSelf: true
                    iconMargin: root.iconMargin
                }
            }
        }

        // Pfeilkachel: weitere Einträge
        Item {
            id: moreTile
            visible: root.overflowCount > 0 || !tray.available
            width: root.tile
            height: root.tile
            Bevel {
                anchors.fill: parent
                sunken: listPopup.visible || (moreMouse.pressed && moreMouse.containsMouse)
            }
            MotifArrow {
                anchors.centerIn: parent
                width: Math.round(root.tile * 0.36) | 1
                height: Math.round(root.tile * 0.2)
                sunken: listPopup.visible
                // zeigt vom Rand weg ins Bild
                up: Plasmoid.location !== PlasmaCore.Types.TopEdge
                rotation: Plasmoid.location === PlasmaCore.Types.LeftEdge ? 90
                        : Plasmoid.location === PlasmaCore.Types.RightEdge ? -90 : 0
            }
            MouseArea {
                id: moreMouse
                anchors.fill: parent
                onClicked: listPopup.visible = !listPopup.visible
            }
            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                mainText: tray.available ? i18np("%1 weiterer Eintrag", "%1 weitere Einträge", root.overflowCount)
                                         : i18n("Kein Systemabschnitt im selben Panel")
                location: Plasmoid.location
                active: !listPopup.visible
            }
        }
    }

    // ---------- Liste der übrigen Einträge ----------
    PlasmaCore.Dialog {
        id: listPopup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: moreTile
        backgroundHints: PlasmaCore.Dialog.SolidBackground
        mainItem: ColumnLayout {
            id: list
            property int maxLabel: 0
            width: Math.max(Kirigami.Units.gridUnit * 15, maxLabel + Kirigami.Units.iconSizes.medium + 4 * Kirigami.Units.largeSpacing)
            height: implicitHeight
            spacing: 2
            Keys.onEscapePressed: listPopup.visible = false

            component ListRow: Item {
                id: row
                property alias iconSource: rowIcon.source
                property alias text: rowLabel.text
                property string info
                property bool sunken: false
                signal clicked(var mouse)
                signal labelWidth(int w)
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.smallSpacing + 4
                Bevel {
                    anchors.fill: parent
                    sunken: row.sunken || (rowMouse.pressed && rowMouse.containsMouse)
                    base: rowMouse.containsMouse ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(1, 1, 1, 0.15)) : Kirigami.Theme.backgroundColor
                }
                // Symbolfach links; Einträge legen dort ihr TrayItemIcon ab (iconSlot)
                readonly property alias iconSlot: slot
                Item {
                    id: slot
                    x: Kirigami.Units.smallSpacing + 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Kirigami.Units.iconSizes.medium
                    height: width
                    Kirigami.Icon { id: rowIcon; anchors.fill: parent; visible: source !== "" }
                }
                ColumnLayout {
                    x: slot.x + slot.width + Kirigami.Units.largeSpacing
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - Kirigami.Units.smallSpacing - 2
                    spacing: 0
                    PlasmaComponents3.Label {
                        id: rowLabel
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        Component.onCompleted: row.labelWidth(implicitWidth)
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: row.info.split("\n")[0]
                        textFormat: Text.PlainText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => row.clicked(mouse)
                }
            }

            // aktive Einträge, die keine Kachel mehr bekommen haben, dann die übrigen
            Component {
                id: listEntry
                ListRow {
                        id: entry
                        // vom umgebenden Loader (Delegat des Repeaters)
                        readonly property var model: parent?.model ?? null
                        readonly property int index: parent?.index ?? -1
                        text: model?.displayText ?? ""
                        info: entryIcon.title !== text ? entryIcon.title : entryIcon.subTitle
                        sunken: entryIcon.expanded
                        onLabelWidth: w => list.maxLabel = Math.max(list.maxLabel, w)
                        onClicked: mouse => mouse.button === Qt.RightButton ? entryIcon.contextMenu() : entryIcon.activate()
                        TrayItemIcon {
                            id: entryIcon
                            parent: entry.iconSlot
                            anchors.fill: parent
                            model: entry.model
                            index: entry.index
                            tray: tray
                            interactive: false
                            anchorSelf: false
                            onAboutToActivate: {
                                listPopup.visible = false;
                                tray.popupAnchor = moreTile;
                            }
                        }
                    }
            }
            Repeater {
                model: listPopup.visible ? trayActive : null
                delegate: Loader {
                    required property var model
                    required property int index
                    active: index >= root.shownTiles
                    visible: active
                    Layout.fillWidth: true
                    sourceComponent: listEntry
                }
            }
            Repeater {
                model: listPopup.visible ? trayPassive : null
                delegate: Loader {
                    required property var model
                    required property int index
                    Layout.fillWidth: true
                    sourceComponent: listEntry
                }
            }
            ListRow {
                iconSource: "configure"
                text: i18n("Systemabschnitt einrichten …")
                onLabelWidth: w => list.maxLabel = Math.max(list.maxLabel, w)
                onClicked: {
                    listPopup.visible = false;
                    tray.configureTray();
                }
            }
        }
    }
}
