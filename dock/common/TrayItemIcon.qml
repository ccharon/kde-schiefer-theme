/*
 * Ein Eintrag des Systemabschnitts (Plasmoid oder StatusNotifierItem) als klickbares Symbol
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
    // Popups des Systrays an diesem Symbol statt am popupAnchor der Brücke aufgehen lassen
    property bool anchorSelf: false
    // vor dem Aktivieren aufgerufen (z. B. um die Schublade zu schließen)
    signal aboutToActivate()

    readonly property bool isPlasmoid: model?.itemType === "Plasmoid"
    readonly property var appletItem: isPlasmoid ? (model?.applet ?? null) : null
    // Plasmoids setzen ihr Symbol laufend (Lautstärke, Akku …), das Modell meldet das nicht
    readonly property var iconSource: isPlasmoid
        ? (appletItem?.plasmoid?.icon || model?.decoration)
        : (model?.status === PlasmaCore.Types.NeedsAttentionStatus ? (model.AttentionIcon || model.AttentionIconName || model.decoration) : model?.decoration)
    readonly property string title: isPlasmoid
        ? (appletItem?.toolTipMainText || appletItem?.plasmoid?.title || model?.displayText || "")
        : (model?.ToolTipTitle || model?.displayText || "")
    readonly property string subTitle: (isPlasmoid ? appletItem?.toolTipSubText : model?.ToolTipSubTitle) ?? ""
    readonly property bool expanded: appletItem?.expanded ?? false

    // nur für tools/screenshot.sh: SCHIEFER_DOCK_TRAY=<itemId> aktiviert diesen Eintrag beim Start
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
