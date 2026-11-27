/*
 * Schiefer status tiles: the Plasma system tray entries as square
 * Motif tiles like the Window Maker dockapps. Active entries get a tile,
 * the others sit in a list behind the arrow tile.
 * The Plasma system tray must be in the same panel; the bridge hides it.
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
    // margin between the tile group and the visible panel edge, equal on all sides
    readonly property int gap: fit.gap

    // position in the panel window (PanelFit): the tiles sit centered between the visible
    // edges, and the reported length is reduced by the extra Plasma padding
    PanelFit {
        id: fit
        target: root
        vertical: root.vertical
    }
    readonly property bool alone: fit.alone
    readonly property int thickness: fit.thickness
    readonly property int tile: Math.max(Kirigami.Units.iconSizes.small + 8, thickness - 2 * gap)
    // offset of the tile group from the top left corner of the applet
    // along: from the panel start, or centered in its own space when other applets share the panel
    readonly property int offsetAlong: alone ? (vertical ? fit.innerY : fit.innerX)
                                             : Math.floor(((vertical ? height : width) - contentLength) / 2)
    readonly property int offsetX: vertical ? fit.edgeL + Math.floor((thickness - tile) / 2) - fit.winPos.x : offsetAlong
    readonly property int offsetY: vertical ? offsetAlong : fit.edgeT + Math.floor((thickness - tile) / 2) - fit.winPos.y

    readonly property int iconMargin: Math.round(tile * (1 - Plasmoid.configuration.iconScale / 100) / 2)
    // at most maxTiles tiles (0 = all active); the rest goes into the list behind the arrow
    readonly property int maxTiles: Plasmoid.configuration.maxTiles
    readonly property int shownTiles: maxTiles > 0 ? Math.min(maxTiles, trayActive.count) : trayActive.count
    readonly property int overflowCount: trayActive.count - shownTiles + trayPassive.count
    readonly property int tileCount: shownTiles + (moreTile.visible ? 1 : 0)
    readonly property int contentLength: Math.max(1, tileCount) * (tile + sp) - sp
    // wanted window length: edge, margin, tiles, margin, edge, minus the Plasma padding
    readonly property int length: alone ? fit.lengthFor(contentLength)
                                        : contentLength

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // option frontpanel-color: surfaces in the CDE front panel color instead of the window color;
    // children inherit it through Kirigami.Theme, FrameTint also tints the panel background
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}
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

    // only for tools/screenshot.sh: SCHIEFER_DOCK_TRAY=more opens the list
    Timer {
        interval: 2500
        running: tray.testItem === "more"
        onTriggered: listPopup.visible = true
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Configure System Tray…")
            icon.name: "configure"
            onTriggered: tray.configureTray()
        }
    ]

    Flow {
        id: flow
        x: root.offsetX
        y: root.offsetY
        width: root.vertical ? root.tile : root.contentLength
        height: root.vertical ? root.contentLength : root.tile
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
                    fill: icon.expanded ? Scheme.hoverColor(Kirigami.Theme.backgroundColor) : Kirigami.Theme.backgroundColor
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

        // arrow tile: more entries
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
                // points away from the edge into the screen
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
                mainText: tray.available ? i18np("%1 more entry", "%1 more entries", root.overflowCount)
                                         : i18n("No system tray in the same panel")
                location: Plasmoid.location
                active: !listPopup.visible
            }
        }
    }

    // ---------- List of the remaining entries ----------
    PlasmaCore.Dialog {
        id: listPopup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: moreTile
        // laid out like a drawer (CDE subpanel, common/Subpanel.qml), which draws its own frame
        backgroundHints: PlasmaCore.Dialog.NoBackground
        mainItem: Subpanel {
            id: listPanel
            title: i18n("Status")
            contentWidth: list.width
            contentHeight: list.implicitHeight
            onCloseRequested: listPopup.visible = false
            Keys.onEscapePressed: listPopup.visible = false
            // popup in the front panel color like CDE drawers (option frontpanel-color)
            Kirigami.Theme.inherit: !Scheme.usePanelColor
            Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
            FrameTint {}

            ColumnLayout {
                id: list
                property int maxLabel: 0
                width: Math.max(Kirigami.Units.gridUnit * 15, maxLabel + Kirigami.Units.iconSizes.medium + 4 * Kirigami.Units.largeSpacing)
                height: implicitHeight
                spacing: 3

                component ListRow: Item {
                    id: row
                    property alias iconSource: rowIcon.source
                    property alias text: rowLabel.text
                    property string info
                    property bool sunken: false
                    property bool attention: false
                    signal clicked(var mouse)
                    signal labelWidth(int w)
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.smallSpacing + 4
                    // flat entry as in a CDE subpanel: focus frame on hover, sunken while pressed
                    EntryFrame {
                        anchors.fill: parent
                        hovered: rowMouse.containsMouse
                        pressed: row.sunken || (rowMouse.pressed && rowMouse.containsMouse)
                    }
                    // CDE indicator lamp: lit while the entry wants attention
                    Lamp {
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.round(parent.height * 0.5)
                        on: row.attention
                    }
                    // icon slot on the left; entries put their TrayItemIcon there (iconSlot)
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

                // active entries that got no tile, then the others
                Component {
                    id: listEntry
                    ListRow {
                            id: entry
                            // from the enclosing Loader (repeater delegate)
                            readonly property var model: parent?.model ?? null
                            readonly property int index: parent?.index ?? -1
                            text: model?.displayText ?? ""
                            info: entryIcon.title !== text ? entryIcon.title : entryIcon.subTitle
                            sunken: entryIcon.expanded
                            attention: model?.effectiveStatus === PlasmaCore.Types.NeedsAttentionStatus
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
                    text: i18n("Configure System Tray…")
                    onLabelWidth: w => list.maxLabel = Math.max(list.maxLabel, w)
                    onClicked: {
                        listPopup.visible = false;
                        tray.configureTray();
                    }
                }
            }
        }
    }
}
