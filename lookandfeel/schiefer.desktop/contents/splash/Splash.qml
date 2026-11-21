/*
 * Schiefer – Startbild: Muster-Hintergrund, Tafel mit Rechnername und Benutzer,
 * Fortschritt als versenkte Rinne mit Blöcken (eine je Startstufe) und blinkende Startlampe.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import "../kit"
import "../kit/T.js" as T

Rectangle {
    id: root
    color: "#8fa3bf"
    property int stage
    readonly property int stages: 6

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    Item { id: viewSet; Kirigami.Theme.colorSet: Kirigami.Theme.View; Kirigami.Theme.inherit: false }
    Pal {
        id: pal
        bg: Kirigami.Theme.backgroundColor
        fg: Kirigami.Theme.textColor
        field: viewSet.Kirigami.Theme.backgroundColor
        active: Kirigami.Theme.highlightColor
        activeText: Kirigami.Theme.highlightedTextColor
        font: Kirigami.Theme.defaultFont
    }
    KCoreAddons.KUser { id: kuser }

    Image {
        anchors.fill: parent
        source: "images/backdrop.png"
        fillMode: Image.Tile
        smooth: false
    }

    Panel {
        id: panel
        pal: pal
        anchors.centerIn: parent
        ColumnLayout {
            width: Math.max(implicitWidth, 28 * pal.u)
            spacing: pal.u
            Header {
                pal: pal
                greeting: T.t("Willkommen, %1", "Welcome, %1").arg(kuser.fullName || kuser.loginName)
                host: kuser.host
                subtitle: T.t("Arbeitsumgebung wird gestartet …", "Starting the desktop …")
                showClock: false
                Layout.fillWidth: true
            }
            Etch { base: pal.bg; Layout.fillWidth: true }
            RowLayout {
                spacing: pal.u
                Layout.fillWidth: true
                // Rinne mit Blöcken
                Bevel {
                    id: trough
                    base: pal.bg
                    sunken: true
                    fill: Qt.darker(pal.bg, 1.08)
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(pal.u * 1.2)
                    Row {
                        id: blocks
                        x: 4; y: 4
                        spacing: 3
                        readonly property real w: (trough.width - 8 - (root.stages - 1) * spacing) / root.stages
                        Repeater {
                            model: root.stages
                            delegate: Bevel {
                                required property int index
                                width: Math.floor(blocks.w); height: trough.height - 8
                                base: pal.active
                                depth: 1
                                visible: index < root.stage
                            }
                        }
                    }
                }
                Lamp { pal: pal; busy: true }
            }
        }
    }
}
