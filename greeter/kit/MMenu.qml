/*
 * Motif-Popup-Menü: erhabene Tafel, Einträge mit erhabener Hervorhebung (wie XmMenuShell),
 * Optionsfelder als Raute. Liegt als Ebene über dem ganzen Bildschirm; Klick daneben schließt.
 *   entries: [{type: "title"|"radio"|"item"|"sep", text, checked, enabled, action}]
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: menu
    required property Pal pal
    property var entries: []
    property int current: -1
    visible: false
    z: 100

    property Item anchorItem: null
    function open(anchor) {
        anchorItem = anchor;
        current = next(-1, 1);
        visible = true;
        forceActiveFocus();
    }
    function close() { visible = false; closed(); }
    signal closed()
    function selectable(i) { const e = entries[i]; return e && (e.type === "radio" || e.type === "item") && e.enabled !== false; }
    function next(i, d) {
        for (let k = 0; k < entries.length; ++k) {
            i = (i + d + entries.length) % entries.length;
            if (selectable(i)) return i;
        }
        return -1;
    }
    function trigger(i) { if (!selectable(i)) return; const a = entries[i].action; close(); if (a) a(); }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape) { close(); e.accepted = true; }
        else if (e.key === Qt.Key_Down) { current = next(current, 1); e.accepted = true; }
        else if (e.key === Qt.Key_Up) { current = next(current, -1); e.accepted = true; }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { trigger(current); e.accepted = true; }
    }

    MouseArea { anchors.fill: parent; onPressed: menu.close() }

    Bevel {
        id: panel
        base: menu.pal.bg
        // bevorzugt über dem Knopf (Knöpfe stehen unten), sonst darunter; folgt der Tafelgröße
        readonly property point at: menu.visible && menu.anchorItem ? menu.anchorItem.mapToItem(menu, 0, 0) : Qt.point(0, 0)
        x: Math.max(0, Math.min(menu.width - width, at.x))
        y: at.y - height - 2 >= 0 ? at.y - height - 2 : at.y + (menu.anchorItem ? menu.anchorItem.height : 0) + 2
        width: col.width + 4
        height: col.height + 4
        MouseArea { anchors.fill: parent }       // Klicks auf die Tafel schließen nicht
        Column {
            id: col
            x: 2; y: 2
            width: Math.max(10 * menu.pal.u, implicitW)
            property real implicitW: 0
            Repeater {
                model: menu.entries
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: menu.current === index
                    width: col.width
                    height: modelData.type === "sep" ? 6 : Math.round(menu.pal.u * 1.5)
                    Component.onCompleted: col.implicitW = Math.max(col.implicitW, txt.implicitWidth + 3 * menu.pal.u)
                    Etch { visible: row.modelData.type === "sep"; base: menu.pal.bg; width: parent.width - 4; x: 2; anchors.verticalCenter: parent.verticalCenter }
                    Bevel {
                        anchors.fill: parent
                        visible: row.sel
                        base: menu.pal.bg
                    }
                    // Raute (XmONE_OF_MANY_DIAMOND)
                    Item {
                        visible: row.modelData.type === "radio"
                        width: Math.round(menu.pal.u * 0.7); height: width
                        x: Math.round(menu.pal.u * 0.5); anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.round(parent.width / Math.SQRT2); height: width; rotation: 45
                            color: row.modelData.checked ? menu.pal.edges(menu.pal.bg).select : menu.pal.bg
                            border.width: 2
                            border.color: row.modelData.checked ? menu.pal.edges(menu.pal.bg).bottom : menu.pal.edges(menu.pal.bg).top
                        }
                    }
                    Text {
                        renderType: menu.pal.renderType
                        id: txt
                        x: row.modelData.type === "title" ? Math.round(menu.pal.u * 0.5) : 2 * menu.pal.u
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.type !== "sep"
                        text: row.modelData.text || ""
                        font.family: menu.pal.font.family
                        font.pointSize: menu.pal.font.pointSize
                        font.bold: row.modelData.type === "title"
                        color: menu.pal.fg
                        opacity: row.modelData.enabled === false ? 0.5 : 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (menu.selectable(row.index)) menu.current = row.index
                        onClicked: menu.trigger(row.index)
                    }
                }
            }
        }
    }
}
