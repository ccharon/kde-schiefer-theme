/*
 * One system tray entry (plasmoid or StatusNotifierItem) as a clickable icon
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: item

    required property var model
    required property int index
    required property var tray
    property int iconMargin: 0
    property bool interactive: true
    // open system tray popups at this icon instead of the bridge's popupAnchor
    property bool anchorSelf: false
    // called before activating (for example to close the drawer)
    signal aboutToActivate()

    readonly property bool isPlasmoid: model?.itemType === "Plasmoid"
    readonly property var appletItem: isPlasmoid ? (model?.applet ?? null) : null
    // plasmoids keep changing their icon (volume, battery ...) and the model does not report it
    readonly property var iconSource: isPlasmoid
        ? (appletItem?.plasmoid?.icon || model?.decoration)
        : (model?.status === PlasmaCore.Types.NeedsAttentionStatus ? (model.AttentionIcon || model.AttentionIconName || model.decoration) : model?.decoration)
    readonly property string title: isPlasmoid
        ? (appletItem?.toolTipMainText || appletItem?.plasmoid?.title || model?.displayText || "")
        : (model?.ToolTipTitle || model?.displayText || "")
    readonly property string subTitle: (isPlasmoid ? appletItem?.toolTipSubText : model?.ToolTipSubTitle) ?? ""
    readonly property bool expanded: appletItem?.expanded ?? false

    // only for tools/screenshot.sh: SCHIEFER_DOCK_TRAY=<itemId> activates this entry on start
    Timer {
        interval: 2500
        running: item.interactive && !!item.model && item.model.itemId === item.tray.testItem
        onTriggered: item.activate()
    }

    function activate() {
        aboutToActivate();
        if (anchorSelf) tray.popupAnchor = item;
        if (isPlasmoid) tray.togglePlasmoid(appletItem);
        else if (model?.itemType === "StatusNotifier") tray.activateSni(model.DataEngineSource, item);
        else tray.toggleTrayPopup();
    }
    function contextMenu() {
        aboutToActivate();
        if (anchorSelf) tray.popupAnchor = item;
        if (model?.itemType === "StatusNotifier") tray.sniContextMenu(model.DataEngineSource, item);
        else tray.toggleTrayPopup();
    }

    Kirigami.Icon {
        anchors.fill: parent
        anchors.margins: item.iconMargin
        source: item.iconSource || "application-x-executable"
        active: mouse.containsMouse || item.expanded
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: item.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? item.contextMenu() : item.activate()
        onWheel: wheel => {
            if (item.model?.itemType === "StatusNotifier") {
                const horizontal = wheel.angleDelta.x !== 0 && wheel.angleDelta.y === 0;
                item.tray.sniScroll(item.model.DataEngineSource, horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
            }
        }
    }
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: item.title
        subText: item.subTitle
        location: Plasmoid.location
        active: item.interactive && !item.expanded
    }
}
