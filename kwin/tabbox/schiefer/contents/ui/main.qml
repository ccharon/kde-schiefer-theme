/*
 Schiefer: window switcher in Motif style (modeled on KWin "compact").
 Plain raised panel with 2 px edges, active item as a sunken field,
 no animations, no blur, no transparency.
 SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin
import "motif.js" as Motif

KWin.TabBoxSwitcher {
    id: tabBox
    currentIndex: listView.currentIndex

    // ---- Colors -----------------------------------------------------------
    // Edges and sunken surface from the Motif formula (motif.js = common/schiefercolors.py),
    // so the same tones as the window decoration, Qt style and dock
    readonly property color base: panel.Kirigami.Theme.backgroundColor
    readonly property var motif: Motif.colors(base)
    readonly property color light: motif.top          // edge top/left
    readonly property color dark: motif.bottom        // edge bottom/right
    readonly property color sunkenFill: motif.select  // surface of the sunken field (Motif: select color)
    readonly property int edge: 2

    function itemCaption(caption, minimized) {
        return minimized ? "(" + caption + ")" : caption;
    }

    // raised (raised=true) or sunken edge around a rectangle
    component Bevel: Item {
        property bool raised: true
        property color fill: tabBox.base
        readonly property color tl: raised ? tabBox.light : tabBox.dark
        readonly property color br: raised ? tabBox.dark : tabBox.light
        Rectangle { anchors.fill: parent; color: parent.fill }
        Rectangle { x: 0; y: 0; width: parent.width; height: tabBox.edge; color: parent.tl }
        Rectangle { x: 0; y: 0; width: tabBox.edge; height: parent.height; color: parent.tl }
        Rectangle { x: 0; y: parent.height - tabBox.edge; width: parent.width; height: tabBox.edge; color: parent.br }
        Rectangle { x: parent.width - tabBox.edge; y: 0; width: tabBox.edge; height: parent.height; color: parent.br }
    }

    TextMetrics {
        id: textMetrics
        property string longestCaption: tabBox.model?.longestCaption() || placeholderLabel.text
        text: tabBox.itemCaption(longestCaption, true)
        font.bold: true
    }
    onVisibleChanged: {
        if (visible) textMetrics.longestCaption = tabBox.model?.longestCaption() || placeholderLabel.text;
    }
    onModelChanged: {
        textMetrics.longestCaption = tabBox.model?.longestCaption() || placeholderLabel.text;
    }

    Timer {
        id: activationTimer
        interval: 50
        onTriggered: tabBox.model.activate(listView.currentIndex)
    }

    PlasmaCore.Dialog {
        id: dialog
        location: PlasmaCore.Types.Floating
        visible: tabBox.visible
        flags: Qt.Popup | Qt.X11BypassWindowManagerHint
        backgroundHints: PlasmaCore.Types.NoBackground
        x: tabBox.screenGeometry.x + tabBox.screenGeometry.width * 0.5 - mainItem.width * 0.5
        y: tabBox.screenGeometry.y + tabBox.screenGeometry.height * 0.5 - mainItem.height * 0.5

        mainItem: Item {
            id: panel
            Kirigami.Theme.colorSet: Kirigami.Theme.Window   // View otherwise (lighter)
            Kirigami.Theme.inherit: false
            readonly property int pad: tabBox.edge + Kirigami.Units.smallSpacing
            readonly property int rowHeight: Math.max(Kirigami.Units.iconSizes.smallMedium,
                                                      textMetrics.height) + 2 * (tabBox.edge + 2)
            width: Math.min(Math.max(tabBox.screenGeometry.width * 0.2,
                                     textMetrics.width + Kirigami.Units.iconSizes.smallMedium
                                     + 4 * Kirigami.Units.smallSpacing + 2 * (pad + tabBox.edge + 2)),
                            tabBox.screenGeometry.width * 0.8)
            height: Math.min(rowHeight * (listView.count || 1) + 2 * pad,
                             tabBox.screenGeometry.height * 0.8)

            Bevel { anchors.fill: parent; raised: true }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: panel.pad
                clip: true
                focus: true
                model: tabBox.model
                highlightMoveDuration: 0
                highlightResizeDuration: 0
                boundsBehavior: Flickable.StopAtBounds

                // active item: sunken field
                highlight: Bevel {
                    width: listView.width
                    raised: false
                    fill: tabBox.sunkenFill
                }

                delegate: RowLayout {
                    width: listView.width
                    height: panel.rowHeight
                    spacing: 2 * Kirigami.Units.smallSpacing
                    opacity: minimized ? 0.75 : 1.0
                    Accessible.name: captionItem.text

                    Kirigami.Icon {
                        source: model.icon
                        animated: false
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.leftMargin: tabBox.edge + 2 + Kirigami.Units.smallSpacing
                    }
                    Text {
                        id: captionItem
                        text: tabBox.itemCaption(caption, minimized)
                        textFormat: Text.PlainText
                        color: Kirigami.Theme.textColor
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        font.bold: index === listView.currentIndex
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.rightMargin: tabBox.edge + 2 + Kirigami.Units.smallSpacing
                    }
                    TapHandler {
                        onTapped: {
                            listView.currentIndex = index;
                            activationTimer.start();
                        }
                    }
                }

                Connections {
                    target: tabBox
                    function onCurrentIndexChanged() { listView.currentIndex = tabBox.currentIndex; }
                }

                Text {
                    id: placeholderLabel
                    visible: listView.count === 0
                    anchors.centerIn: parent
                    color: Kirigami.Theme.textColor
                    font: Kirigami.Theme.defaultFont
                    text: i18ndc("kwin", "@info:placeholder no entries in the task switcher", "No open windows")
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                    if (listView.currentIndex === 0) listView.currentIndex = listView.count - 1;
                    else listView.decrementCurrentIndex();
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                    if (listView.currentIndex === listView.count - 1) listView.currentIndex = 0;
                    else listView.incrementCurrentIndex();
                }
            }
        }

        onSceneGraphError: () => {}
    }
}
